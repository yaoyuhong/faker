import SwiftUI

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
                    Label("练完上传，2–5 分钟出报告", systemImage: "chart.bar.fill")
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

/// Orchestrates calibration → record → processing.
struct SessionFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var step: FlowStep = .calibration
    @State private var calibrationPoints: [CGPoint] = []
    @StateObject private var camera = CameraService()
    @StateObject private var health = HealthKitService()

    enum FlowStep {
        case calibration, record, processing
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .calibration:
                    CalibrationView(points: $calibrationPoints) {
                        step = .record
                    }
                case .record:
                    RecordView(camera: camera, health: health) {
                        step = .processing
                    }
                case .processing:
                    ProcessingView {
                        dismiss()
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
}

struct ProcessingView: View {
    let onDone: () -> Void
    @State private var progress: Double = 0

    var body: some View {
        VStack(spacing: 20) {
            ProgressView(value: progress)
                .padding()
            Text("正在分析落点与球速…")
            Text("通常需要 2–5 分钟")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .task {
            // Poll mock progress; wire to AnalysisAPIClient in Phase 1
            for i in 1...10 {
                try? await Task.sleep(for: .seconds(1))
                progress = Double(i) / 10.0
            }
            onDone()
        }
    }
}
