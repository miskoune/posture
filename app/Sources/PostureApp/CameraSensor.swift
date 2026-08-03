import AVFoundation
import CoreVideo
import Foundation
import PostureCore

/// Wakes the camera, keeps one usable frame, and shuts it off again.
///
/// The session is deliberately not left running. A live stream would keep the
/// camera powered all day; this takes one frame every few seconds and stops.
/// The visible consequence is that the camera light blinks rather than staying
/// lit — which is the honest signal, because it really is off in between.
///
/// The frame never leaves the capture queue. `CMSampleBufferGetImageBuffer`
/// returns a buffer owned by AVFoundation's pool, so it is measured in place
/// and only the resulting `Reading` — two doubles — crosses back to the caller.
final class CameraSensor: NSObject, PostureSensor, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "com.miskoune.posture.capture")
    private let reader = PoseReader()

    /// Auto-exposure needs a few frames to settle; the first is usually dark
    /// enough to lose the shoulders entirely.
    private let warmupFrames = 3
    private let frameTimeout: TimeInterval = 5

    private var remainingWarmup = 0
    private var pending: ((SensorOutcome) -> Void)?
    private var isConfigured = false

    /// Asks the user once. macOS remembers the answer; we never ask again.
    static func requestAccess(_ completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        default:
            completion(false)
        }
    }

    // MARK: - PostureSensor

    func sample(completion: @escaping (SensorOutcome) -> Void) {
        queue.async { [weak self] in
            guard let self else { return }

            // A sample is already in flight — skip this tick rather than
            // stacking captures up behind each other.
            guard self.pending == nil else {
                self.deliver(.noPersonVisible, to: completion)
                return
            }

            guard let failure = self.configureIfNeeded() else {
                self.begin(completion)
                return
            }

            self.deliver(.unavailable(reason: failure), to: completion)
        }
    }

    private func begin(_ completion: @escaping (SensorOutcome) -> Void) {
        pending = completion
        remainingWarmup = warmupFrames

        if !session.isRunning {
            session.startRunning()
        }

        // Never leave the camera running because a frame failed to arrive.
        queue.asyncAfter(deadline: .now() + frameTimeout) { [weak self] in
            self?.finish(with: .unavailable(reason: "No frame from the camera"))
        }
    }

    /// Returns nil on success, or the reason it could not be configured.
    private func configureIfNeeded() -> String? {
        guard !isConfigured else { return nil }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .medium

        guard let device = AVCaptureDevice.default(for: .video) else {
            return "No camera found"
        }
        guard let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            return "Camera is in use by another app"
        }
        session.addInput(input)

        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else {
            return "Cannot read from the camera"
        }
        session.addOutput(output)

        isConfigured = true
        return nil
    }

    // MARK: - Frames

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard pending != nil else { return }

        if remainingWarmup > 0 {
            remainingWarmup -= 1
            return
        }

        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            finish(with: .noPersonVisible)
            return
        }

        finish(with: reader.read(buffer))
    }

    /// Stops the session and answers exactly once. Only ever called on `queue`,
    /// which is what keeps `pending` free of races.
    private func finish(with outcome: SensorOutcome) {
        guard let completion = pending else { return }
        pending = nil

        if session.isRunning {
            session.stopRunning()
        }

        deliver(outcome, to: completion)
    }

    private func deliver(
        _ outcome: SensorOutcome,
        to completion: @escaping (SensorOutcome) -> Void
    ) {
        DispatchQueue.main.async { completion(outcome) }
    }
}
