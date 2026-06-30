import Foundation

/// Client for CourtLog CV cloud API (see docs/openapi.yaml).
final class AnalysisAPIClient {
    var baseURL: URL

    init(baseURL: URL = URL(string: "http://localhost:8000/v1")!) {
        self.baseURL = baseURL
    }

    struct CreateSessionPayload: Encodable {
        var calibration: CalibrationPayload
        var health: HealthPayload?
        var deviceId: String
    }

    struct CalibrationPayload: Encodable {
        var imagePoints: [CodablePoint]
        var courtPointsMeters: [CodablePoint]
    }

    struct HealthPayload: Encodable {
        var avgHeartRate: Double?
        var maxHeartRate: Double?
        var activeCalories: Double?
        var durationSec: Double?
    }

    struct CreateSessionResponse: Decodable {
        var sessionId: UUID
        var uploadUrl: URL
    }

    struct JobResponse: Decodable {
        var jobId: UUID
    }

    struct JobStatus: Decodable {
        var status: String
        var progress: Double
        var error: String?
        var result: AnalysisResult?
    }

    func createSession(session: Session) async throws -> CreateSessionResponse {
        let url = baseURL.appendingPathComponent("sessions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = CreateSessionPayload(
            calibration: CalibrationPayload(
                imagePoints: session.calibrationImagePoints,
                courtPointsMeters: session.calibrationCourtPoints
            ),
            health: HealthPayload(
                avgHeartRate: session.avgHeartRate,
                maxHeartRate: session.maxHeartRate,
                activeCalories: session.activeCalories,
                durationSec: session.durationSec
            ),
            deviceId: UIDeviceFallback.identifier
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.badStatus
        }
        return try JSONDecoder().decode(CreateSessionResponse.self, from: data)
    }

    func startAnalysis(sessionId: UUID) async throws -> JobResponse {
        let url = baseURL.appendingPathComponent("sessions/\(sessionId.uuidString)/analyze")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.badStatus
        }
        return try JSONDecoder().decode(JobResponse.self, from: data)
    }

    func pollJob(jobId: UUID) async throws -> JobStatus {
        let url = baseURL.appendingPathComponent("jobs/\(jobId.uuidString)")
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(JobStatus.self, from: data)
    }

    enum APIError: Error {
        case badStatus
    }
}

/// Avoid UIKit import in scaffold; replace with UIDevice.current in full target.
enum UIDeviceFallback {
    static var identifier: String {
        UserDefaults.standard.string(forKey: "courtlog.deviceId")
            ?? {
                let id = UUID().uuidString
                UserDefaults.standard.set(id, forKey: "courtlog.deviceId")
                return id
            }()
    }
}
