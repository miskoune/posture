import AppKit
import AVFoundation
import SwiftUI
import PostureCore

/// The app's one real window, now a SwiftUI shell: a collapsible sidebar with
/// the app identity and pages (camera, stats, settings) and the selected page
/// filling the rest. This controller owns the window, the capture session,
/// and the bridge between the AppKit world and the `DashboardModel` the
/// SwiftUI views observe. Green means good posture, amber means bad, matching
/// the site.
///
/// The window owns its own capture session, separate from the always-on
/// `CameraSensor`. It streams only while the window is open and stops the
/// moment it closes. While open, the app also steps up from menu-bar accessory
/// to a regular app with a Dock icon — a window deserves an app switcher entry.
final class DashboardWindowController: NSWindowController, NSWindowDelegate {
    private let settings: SettingsStoring
    private let monitor: PostureMonitor
    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "com.miskoune.posture.dashboard")
    private let reader = PoseReader()

    private let previewView: PreviewView
    private let model = DashboardModel()

    private var statsTimer: Timer?
    private var isConfigured = false
    /// Vision runs on the capture queue; frames that arrive while it is busy
    /// are dropped rather than queued. Touched only on `queue`.
    private var lastDetectionTime: CFTimeInterval = 0
    private let detectionInterval: CFTimeInterval = 0.2

    /// What the user asked for; the delegate decides what it means. Reuses the
    /// menu's vocabulary so `AppDelegate` handles both sources identically.
    var onCommand: ((StatusMenuController.Command) -> Void)? {
        didSet { model.onCommand = onCommand }
    }

    init(settings: SettingsStoring, monitor: PostureMonitor) {
        self.settings = settings
        self.monitor = monitor
        self.previewView = PreviewView(session: session)

        let hosting = NSHostingController(
            rootView: DashboardView(model: model, previewView: previewView)
        )
        let window = NSWindow(contentViewController: hosting)
        window.title = "Posture"
        window.setContentSize(NSSize(width: 920, height: 560))
        window.toolbarStyle = .unified
        window.titlebarSeparatorStyle = .automatic
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        window.delegate = self
        syncModel()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Showing and hiding

    func show() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)

        syncModel()
        statsTimer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.syncModel()
        }
        RunLoop.main.add(timer, forMode: .common)
        statsTimer = timer

        queue.async { [weak self] in
            guard let self else { return }
            if let failure = self.configureIfNeeded() {
                DispatchQueue.main.async {
                    self.setStatus(failure, tone: .bad, detail: "")
                }
                return
            }
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func windowWillClose(_ notification: Notification) {
        statsTimer?.invalidate()
        statsTimer = nil
        NSApp.setActivationPolicy(.accessory)
        queue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    // MARK: - Model sync

    /// Ticks once a second while the window is open: totals, the pause state,
    /// and settings that may have been changed from the menu bar instead.
    private func syncModel() {
        let now = Date()
        setIfChanged(\.goodSeconds, monitor.tally.goodTotal(at: now))
        setIfChanged(\.badSeconds, monitor.tally.badTotal(at: now))
        setIfChanged(\.isPaused, settings.isPaused)
        setIfChanged(\.isCalibrated, settings.baseline != nil)
        setIfChanged(\.tolerance, settings.tolerance)
        setIfChanged(\.patience, settings.patience)
        setIfChanged(\.nudgeRepeat, settings.nudgeRepeat)
        setIfChanged(\.showPreviewOnNudge, settings.showPreviewOnNudge)
    }

    /// Skips no-op writes so `objectWillChange` only fires for real changes.
    private func setIfChanged<T: Equatable>(
        _ keyPath: ReferenceWritableKeyPath<DashboardModel, T>,
        _ value: T
    ) {
        guard model[keyPath: keyPath] != value else { return }
        model[keyPath: keyPath] = value
    }

    // MARK: - Rendering

    private func render(_ detection: PoseDetection) {
        switch detection {
        case .pose(let snapshot):
            renderPose(snapshot)
        case .nobody:
            previewView.clear()
            setStatus("Cannot see you", tone: .neutral, detail: "")
        case .failed(let reason):
            previewView.clear()
            setStatus(reason, tone: .bad, detail: "")
        }
    }

    private func renderPose(_ snapshot: PoseSnapshot) {
        let verdict = judge(snapshot.reading)
        previewView.drawFace(
            snapshot.faceBox,
            guideHeight: settings.baseline?.uprightness,
            color: nsColor(for: verdict.tone)
        )
        setStatus(verdict.title, tone: verdict.tone, detail: verdict.detail)
    }

    private func judge(
        _ reading: Reading
    ) -> (title: String, detail: String, tone: DashboardModel.Tone) {
        if case .calibrating(let collected, let needed) = monitor.state {
            return (
                "Calibrating \(collected)/\(needed)",
                "Hold still, sitting the way you want to sit",
                .good
            )
        }

        guard let baseline = settings.baseline else {
            return (
                "Not calibrated yet",
                "Click Calibrate while sitting the way you want to sit",
                .neutral
            )
        }

        let drift = baseline.drift(from: reading)
        let detail = String(
            format: "slump %+.0f%%   lean %+.0f%%   tilt %+.0f%%   tolerance %.0f%%",
            drift.slump * 100, drift.lean * 100, drift.tilt * 100,
            settings.tolerance * 100
        )

        if drift.exceeds(settings.tolerance) {
            return ("Bad posture: \(advice(for: drift))", detail, .bad)
        }
        return ("Good posture", detail, .good)
    }

    /// Names the axis that is furthest gone, so the fix is always actionable.
    private func advice(for drift: Drift) -> String {
        if drift.slump >= drift.lean && drift.slump >= drift.tilt { return "sit up" }
        if drift.lean >= drift.tilt { return "sit back" }
        return "straighten your head"
    }

    private func setStatus(_ title: String, tone: DashboardModel.Tone, detail: String) {
        setIfChanged(\.statusTitle, title)
        setIfChanged(\.statusTone, tone)
        setIfChanged(\.statusDetail, detail)
    }

    private func nsColor(for tone: DashboardModel.Tone) -> NSColor {
        switch tone {
        case .good: return .systemGreen
        case .bad: return .systemOrange
        case .neutral: return .systemGray
        }
    }

    // MARK: - Capture

    /// Returns nil on success, or the reason it could not be configured.
    private func configureIfNeeded() -> String? {
        guard !isConfigured else { return nil }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .high

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

        // A mirror is what people expect to see of themselves. The overlay
        // points come back through the preview layer's own conversion, so
        // they mirror with it.
        DispatchQueue.main.async { [weak self] in
            guard let connection = self?.previewView.previewLayer.connection,
                  connection.isVideoMirroringSupported else { return }
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }

        isConfigured = true
        return nil
    }
}

// MARK: - Frames

extension DashboardWindowController: AVCaptureVideoDataOutputSampleBufferDelegate {
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
            self?.render(detection)
        }
    }
}
