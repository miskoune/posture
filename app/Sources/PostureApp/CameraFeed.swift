import AVFoundation
import Foundation

/// The one recipe for wiring the default camera into a capture session.
/// Shared by the one-shot sensor and the live preview feeds, so "how do we
/// open the camera" is answered in exactly one place.
enum CaptureSetup {
    /// Returns nil on success, or the reason it could not be configured.
    static func configure(
        session: AVCaptureSession,
        preset: AVCaptureSession.Preset,
        output: AVCaptureVideoDataOutput,
        delegate: AVCaptureVideoDataOutputSampleBufferDelegate,
        queue: DispatchQueue
    ) -> String? {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = preset

        guard let device = AVCaptureDevice.default(for: .video) else {
            return "No camera found"
        }
        guard let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            return "Camera is in use by another app"
        }
        session.addInput(input)

        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(delegate, queue: queue)
        guard session.canAddOutput(output) else {
            return "Cannot read from the camera"
        }
        session.addOutput(output)
        return nil
    }
}

/// A live, mirrored camera feed behind a preview surface: it owns the
/// session, throttles Vision to a sane pace, and reports each detection on
/// the main queue. The dashboard and the corner nudge panel each own one;
/// neither knows how a session is stood up or torn down.
final class CameraFeed: NSObject {
    /// For building the `PreviewView` that will display this feed.
    let session = AVCaptureSession()

    private let preset: AVCaptureSession.Preset
    private let output = AVCaptureVideoDataOutput()
    private let queue: DispatchQueue
    private let reader = PoseReader()

    /// Vision runs on the capture queue; frames that arrive while it is busy
    /// are dropped rather than queued. Touched only on `queue`.
    private var lastDetectionTime: CFTimeInterval = 0
    private let detectionInterval: CFTimeInterval = 0.2
    private var isConfigured = false

    /// Runs on the main queue with each throttled detection.
    var onDetection: ((PoseDetection) -> Void)?

    init(preset: AVCaptureSession.Preset, queueLabel: String) {
        self.preset = preset
        self.queue = DispatchQueue(label: queueLabel)
    }

    /// Configures on first call, then streams into `previewView`. `onFailure`
    /// runs on the main queue with the reason the camera is unusable.
    func start(mirroring previewView: PreviewView, onFailure: ((String) -> Void)? = nil) {
        queue.async { [weak self] in
            guard let self else { return }
            if let failure = self.configureIfNeeded(mirroring: previewView) {
                DispatchQueue.main.async { onFailure?(failure) }
                return
            }
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    /// Runs on `queue`. Returns nil on success, or the reason it failed.
    private func configureIfNeeded(mirroring previewView: PreviewView) -> String? {
        guard !isConfigured else { return nil }

        if let failure = CaptureSetup.configure(
            session: session,
            preset: preset,
            output: output,
            delegate: self,
            queue: queue
        ) {
            return failure
        }

        // A mirror is what people expect to see of themselves. The overlay
        // points come back through the preview layer's own conversion, so
        // they mirror with it.
        DispatchQueue.main.async {
            guard let connection = previewView.previewLayer.connection,
                  connection.isVideoMirroringSupported else { return }
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }

        isConfigured = true
        return nil
    }
}

// MARK: - Frames

extension CameraFeed: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = CACurrentMediaTime()
        guard now - lastDetectionTime >= detectionInterval else { return }
        lastDetectionTime = now

        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let detection = reader.detect(buffer)

        DispatchQueue.main.async { [weak self] in
            self?.onDetection?(detection)
        }
    }
}
