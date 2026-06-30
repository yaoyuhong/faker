import AVFoundation
import SwiftUI

@MainActor
final class CameraService: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var permissionGranted = false
    @Published var errorMessage: String?

    private let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?

    var captureSession: AVCaptureSession { session }

    func configure() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
        case .notDetermined:
            permissionGranted = await AVCaptureDevice.requestAccess(for: .video)
        default:
            permissionGranted = false
            errorMessage = "请在设置中允许相机权限"
            return
        }

        guard permissionGranted else { return }

        session.beginConfiguration()
        session.sessionPreset = .hd1920x1080

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            errorMessage = "无法访问后置摄像头"
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
            if let connection = movieOutput.connection(with: .video) {
                connection.videoRotationAngle = 90
            }
        }

        session.commitConfiguration()
    }

    func startPreview() {
        guard !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    func stopPreview() {
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
        }
    }

    func startRecording(to url: URL) {
        guard !movieOutput.isRecording else { return }
        movieOutput.startRecording(to: url, recordingDelegate: self)
        isRecording = true
    }

    func stopRecording() {
        guard movieOutput.isRecording else { return }
        movieOutput.stopRecording()
    }
}

extension CameraService: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        Task { @MainActor in
            isRecording = false
            if let error {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        context.coordinator.layer = layer
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.layer?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var layer: AVCaptureVideoPreviewLayer?
    }
}
