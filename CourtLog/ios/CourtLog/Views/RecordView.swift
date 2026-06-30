import SwiftUI

struct RecordView: View {
    @ObservedObject var camera: CameraService
    @ObservedObject var health: HealthKitService
    let onFinish: () -> Void

    @State private var elapsed: TimeInterval = 0
    @State private var timer: Timer?

    var body: some View {
        VStack {
            CameraPreview(session: camera.captureSession)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding()

            Text(timeString(elapsed))
                .font(.system(.title, design: .monospaced))

            if health.isAuthorized {
                Label("Apple Watch 已连接", systemImage: "heart.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            HStack(spacing: 32) {
                if camera.isRecording {
                    Button {
                        camera.stopRecording()
                        timer?.invalidate()
                        onFinish()
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.red)
                    }
                } else {
                    Button {
                        Task {
                            try? await health.startWorkout()
                            let url = FileManager.default.temporaryDirectory
                                .appendingPathComponent("session-\(UUID().uuidString).mov")
                            camera.startRecording(to: url)
                            startTimer()
                        }
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
