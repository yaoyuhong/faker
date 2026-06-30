import Foundation

@MainActor
final class SessionUploadService {
    private let api = AnalysisAPIClient(baseURL: AppConfig.apiBaseURL)

    func submit(session: Session, videoURL: URL) async throws -> AnalysisResult {
        let create = try await api.createSession(session: session)

        try await uploadVideo(to: create.uploadUrl, from: videoURL)

        let job = try await api.startAnalysis(sessionId: create.sessionId)
        return try await pollUntilDone(jobId: job.jobId)
    }

    private func uploadVideo(to uploadURL: URL, from localURL: URL) async throws {
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.setValue("video/mp4", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.upload(for: request, fromFile: localURL)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw UploadError.failed(body)
        }
    }

    private func pollUntilDone(jobId: UUID) async throws -> AnalysisResult {
        for _ in 0..<120 {
            let status = try await api.pollJob(jobId: jobId)
            switch status.status {
            case "done":
                guard let result = status.result else {
                    throw UploadError.noResult
                }
                return result
            case "failed":
                throw UploadError.analysisFailed(status.error ?? "unknown")
            default:
                try await Task.sleep(for: .seconds(2))
            }
        }
        throw UploadError.timeout
    }

    enum UploadError: LocalizedError {
        case failed(String)
        case noResult
        case analysisFailed(String)
        case timeout

        var errorDescription: String? {
            switch self {
            case .failed(let msg): return "上传失败：\(msg)"
            case .noResult: return "分析结果为空"
            case .analysisFailed(let msg): return "分析失败：\(msg)"
            case .timeout: return "分析超时，请稍后重试"
            }
        }
    }
}
