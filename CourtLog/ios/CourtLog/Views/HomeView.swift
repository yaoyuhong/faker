import SwiftUI
import SwiftData

struct HomeView: View {
    @State private var showSessionFlow = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "tennisball.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)

                Text("CourtLog")
                    .font(.largeTitle.bold())

                Text("架好手机，记录落点与球速")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Label("侧方固定机位，拍清整个球场", systemImage: "camera.viewfinder")
                    Label("佩戴 Apple Watch 同步心率", systemImage: "applewatch")
                    Label("练完上传，分析落点热力图", systemImage: "chart.bar.fill")
                }
                .font(.subheadline)
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

                Button {
                    showSessionFlow = true
                } label: {
                    Text("开始训练")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("首页")
            .fullScreenCover(isPresented: $showSessionFlow) {
                SessionFlowView()
            }
        }
    }
}

struct SessionFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var step: FlowStep = .calibration
    @State private var normalizedPoints: [CGPoint] = []
    @State private var overlaySize: CGSize = .zero
    @StateObject private var camera = CameraService()
    @StateObject private var health = HealthKitService()

    @State private var session: Session?
    @State private var videoURL: URL?
    @State private var durationSec: Double = 0
    @State private var healthSummary = HealthSummary()

    enum FlowStep {
        case calibration, record, processing
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .calibration:
                    CalibrationView(points: $normalizedPoints, overlaySize: $overlaySize) {
                        step = .record
                    }
                case .record:
                    RecordView(camera: camera, health: health) { url, duration, summary in
                        videoURL = url
                        durationSec = duration
                        healthSummary = summary
                        session = buildSession()
                        if let session {
                            modelContext.insert(session)
                        }
                        step = .processing
                    }
                case .processing:
                    if let session, let videoURL {
                        ProcessingView(session: session, videoURL: videoURL) {
                            dismiss()
                        }
                    } else {
                        ContentUnavailableView("缺少录制文件", systemImage: "exclamationmark.triangle")
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .task {
            await health.requestAuthorization()
            await camera.configure()
            camera.startPreview()
        }
        .onDisappear { camera.stopPreview() }
    }

    private func buildSession() -> Session {
        let imagePoints = pixelCalibrationPoints()
        let courtPoints = CourtGeometry.defaultCornersMeters
        let s = Session(
            durationSec: durationSec > 0 ? durationSec : healthSummary.durationSec ?? 0,
            videoFileName: videoURL?.lastPathComponent,
            uploadState: .pending,
            analysisState: .pending,
            calibrationImagePoints: imagePoints,
            calibrationCourtPoints: courtPoints
        )
        s.avgHeartRate = healthSummary.avgHeartRate
        s.maxHeartRate = healthSummary.maxHeartRate
        s.activeCalories = healthSummary.activeCalories
        return s
    }

    /// Map normalized overlay taps → 1080p pixel coordinates (portrait 1080×1920 after rotation).
    private func pixelCalibrationPoints() -> [CodablePoint] {
        let videoW = 1080.0
        let videoH = 1920.0
        return normalizedPoints.map { p in
            CodablePoint(x: p.x * videoW, y: p.y * videoH)
        }
    }
}

struct ProcessingView: View {
    @Environment(\.modelContext) private var modelContext

    let session: Session
    let videoURL: URL
    let onDone: () -> Void

    @State private var progress: Double = 0
    @State private var errorMessage: String?
    @State private var finished = false

    private let uploader = SessionUploadService()

    var body: some View {
        VStack(spacing: 20) {
            if let errorMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text(errorMessage)
                    .multilineTextAlignment(.center)
                Button("关闭") { onDone() }
            } else {
                ProgressView(value: progress)
                    .padding()
                Text(finished ? "分析完成" : "正在上传并分析…")
                Text("TrackNet 分析可能需要 1–5 分钟")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if finished {
                    NavigationLink("查看报告") {
                        ReportView(session: session)
                    }
                    .buttonStyle(.borderedProminent)
                    Button("完成") { onDone() }
                }
            }
        }
        .padding()
        .task { await runPipeline() }
    }

    private func runPipeline() async {
        session.uploadState = .uploading
        progress = 0.1

        do {
            progress = 0.25
            let result = try await uploader.submit(session: session, videoURL: videoURL)
            session.uploadState = .uploaded
            session.analysisState = .done
            session.analysisJSON = try JSONEncoder().encode(result)
            if let max = result.bounces.map(\.speedKmh).max() {
                _ = max // speeds surfaced in report
            }
            try modelContext.save()
            progress = 1.0
            finished = true
        } catch {
            session.uploadState = .failed
            session.analysisState = .failed
            errorMessage = error.localizedDescription
            try? modelContext.save()
        }
    }
}
