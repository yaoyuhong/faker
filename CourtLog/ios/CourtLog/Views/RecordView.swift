import SwiftUI

struct RecordView: View {
    @ObservedObject var camera: CameraService
    @ObservedObject var health: HealthKitService
    let onFinish: (URL, TimeInterval, HealthSummary) -> Void

    @State private var elapsed: TimeInterval = 0
    @State private var timer: Timer?
    @State private var recordingURL: URL?
    @State private var isStopping = false

    var body: some View {
        VStack {
            CameraPreview(session: camera.captureSession)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding()

            Text(timeString(elapsed))
                .font(.system(.title, design: .monospaced))

            if health.isAuthorized {
                Label("HealthKit 已授权", systemImage: "heart.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            HStack(spacing: 32) {
                if camera.isRecording {
                    Button {
                        stopSession()
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.red)
                    }
                    .disabled(isStopping)
                } else {
                    Button {
                        startSession()
                    } label: {
                        Image(systemName: "record.circle")
                            .font(.system(size: 64))
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("录制中")
        .onChange(of: camera.lastRecordingURL) { _, url in
            guard isStopping, let url else { return }
            Task { await finishWithVideo(url) }
        }
    }

    private func startSession() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("session-\(UUID().uuidString).mov")
        recordingURL = url
        Task {
            try? await health.startWorkout()
            camera.startRecording(to: url)
            startTimer()
        }
    }

    private func stopSession() {
        isStopping = true
        timer?.invalidate()
        camera.stopRecording()
    }

    private func finishWithVideo(_ url: URL) async {
        let summary = (try? await health.endWorkout()) ?? HealthSummary()
        let duration = summary.durationSec ?? elapsed
        onFinish(url, duration, summary)
    }

    private func startTimer() {
        elapsed = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsed += 1
        }
    }

    private func timeString(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%02d:%02d", m, s)
    }
}
