import AVFoundation
import CoreVideo
import Foundation
import PostureCore

/// Keeps the camera running and measures one frame whenever asked.
///
/// The session stays on while monitoring is active, so the camera light is
/// simply lit — a steady, legible signal. A blinking light (duty-cycling the
/// session per sample) was tried first and reads as the camera sneaking
/// glances; solid on while monitoring, off while paused is calmer and just as
/// honest. Pausing stops the session, and the light, entirely.
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

    /// Which sample the armed timeout belongs to. A timeout may only cancel
    /// its own sample — without this, sample N's stale timeout fires just as
    /// sample N+1 begins (both run on the same interval) and kills it.
    private var sampleGeneration = 0

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
        sampleGeneration += 1
        let thisSample = sampleGeneration

        if session.isRunning {
            // The stream is warm; the next frame is representative.
            remainingWarmup = 0
        } else {
            // Auto-exposure needs a few frames to settle after a cold start.
            remainingWarmup = warmupFrames
            session.startRunning()
        }

        // Answer even if no frame ever arrives, so the monitor is not stuck
        // waiting on a completion forever.
        queue.asyncAfter(deadline: .now() + frameTimeout) { [weak self] in
            guard let self, self.sampleGeneration == thisSample else { return }
            self.finish(with: .unavailable(reason: "No frame from the camera"))
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

    /// Answers exactly once, leaving the session running for the next sample.
    /// Only ever called on `queue`, which is what keeps `pending` free of
    /// races.
    private func finish(with outcome: SensorOutcome) {
        guard let completion = pending else { return }
        pending = nil
        deliver(outcome, to: completion)
    }

    /// Called when monitoring pauses: the light must go out, or "paused"
    /// would be a lie the LED contradicts.
    func rest() {
        queue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    private func deliver(
        _ outcome: SensorOutcome,
        to completion: @escaping (SensorOutcome) -> Void
    ) {
        DispatchQueue.main.async { completion(outcome) }
    }
}
