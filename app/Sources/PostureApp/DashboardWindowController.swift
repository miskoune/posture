import AppKit
import AVFoundation
import PostureCore

/// The app's one real window: the camera on the left with the measured face
/// drawn on it, and a sidebar with the verdict, this session's totals, and
/// the settings. Green means good posture, amber means bad, matching the site.
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
    private let statusLabel = NSTextField(wrappingLabelWithString: "Starting camera…")
    private let detailLabel = NSTextField(wrappingLabelWithString: "")
    private let goodTimeValue = NSTextField(labelWithString: "0s")
    private let badTimeValue = NSTextField(labelWithString: "0s")
    private let tolerancePopup = NSPopUpButton()
    private let patiencePopup = NSPopUpButton()
    private let nudgeRepeatPopup = NSPopUpButton()
    private let previewCheckbox = NSButton(
        checkboxWithTitle: "Show preview when notified",
        target: nil,
        action: nil
    )
    private let pauseButton = NSButton(title: "Pause", target: nil, action: nil)

    private var statsTimer: Timer?
    private var isConfigured = false
    /// Vision runs on the capture queue; frames that arrive while it is busy
    /// are dropped rather than queued. Touched only on `queue`.
    private var lastDetectionTime: CFTimeInterval = 0
    private let detectionInterval: CFTimeInterval = 0.2

    private let goodColor = NSColor.systemGreen
    private let warnColor = NSColor.systemOrange
    private let neutralColor = NSColor.systemGray

    /// What the user asked for; the delegate decides what it means. Reuses the
    /// menu's vocabulary so `AppDelegate` handles both sources identically.
    var onCommand: ((StatusMenuController.Command) -> Void)?

    private let tolerances: [(label: String, value: Double)] = [
        ("Relaxed", 0.25),
        ("Normal", 0.15),
        ("Strict", 0.08)
    ]

    private let patiences: [(label: String, value: Double)] = [
        ("10 seconds", 10),
        ("30 seconds", 30),
        ("1 minute", 60),
        ("2 minutes", 120),
        ("5 minutes", 300),
        ("15 minutes", 900)
    ]

    private let nudgeRepeats: [(label: String, value: Double)] = [
        ("Only once", 0),
        ("Every 30 seconds", 30),
        ("Every minute", 60),
        ("Every 2 minutes", 120),
        ("Every 5 minutes", 300),
        ("Every 10 minutes", 600)
    ]

    init(settings: SettingsStoring, monitor: PostureMonitor) {
        self.settings = settings
        self.monitor = monitor
        self.previewView = PreviewView(session: session)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 520),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Posture"
        window.minSize = NSSize(width: 700, height: 420)
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        window.delegate = self
        buildContent(in: window)
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

        refreshControls()
        statsTimer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.refreshControls()
        }
        RunLoop.main.add(timer, forMode: .common)
        statsTimer = timer

        queue.async { [weak self] in
            guard let self else { return }
            if let failure = self.configureIfNeeded() {
                DispatchQueue.main.async {
                    self.statusLabel.stringValue = failure
                    self.statusLabel.textColor = self.warnColor
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

    // MARK: - Layout

    private func buildContent(in window: NSWindow) {
        let content = NSView()
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor.black.cgColor

        previewView.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(previewView)

        let sidebar = NSVisualEffectView()
        sidebar.material = .sidebar
        sidebar.blendingMode = .behindWindow
        sidebar.state = .active
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(sidebar)

        let stack = buildSidebarStack()
        stack.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(stack)

        NSLayoutConstraint.activate([
            previewView.topAnchor.constraint(equalTo: content.topAnchor),
            previewView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            previewView.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            previewView.trailingAnchor.constraint(equalTo: sidebar.leadingAnchor),

            sidebar.topAnchor.constraint(equalTo: content.topAnchor),
            sidebar.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            sidebar.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: 260),

            stack.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: sidebar.bottomAnchor, constant: -16)
        ])

        window.contentView = content
    }

    private func buildSidebarStack() -> NSStackView {
        statusLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        statusLabel.textColor = neutralColor
        detailLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        detailLabel.textColor = .secondaryLabelColor

        goodTimeValue.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        goodTimeValue.textColor = goodColor
        badTimeValue.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        badTimeValue.textColor = warnColor

        for (popup, options, current) in [
            (tolerancePopup, tolerances, settings.tolerance),
            (patiencePopup, patiences, settings.patience),
            (nudgeRepeatPopup, nudgeRepeats, settings.nudgeRepeat)
        ] {
            for option in options {
                popup.addItem(withTitle: option.label)
                popup.lastItem?.representedObject = option.value
            }
            select(value: current, in: popup)
            popup.target = self
        }
        tolerancePopup.action = #selector(toleranceChanged(_:))
        patiencePopup.action = #selector(patienceChanged(_:))
        nudgeRepeatPopup.action = #selector(nudgeRepeatChanged(_:))

        previewCheckbox.state = settings.showPreviewOnNudge ? .on : .off
        previewCheckbox.target = self
        previewCheckbox.action = #selector(previewToggled)

        let calibrateButton = NSButton(
            title: "Calibrate",
            target: self,
            action: #selector(calibrateClicked)
        )
        calibrateButton.bezelStyle = .rounded
        calibrateButton.toolTip = "Sit the way you want to sit, then click"

        pauseButton.bezelStyle = .rounded
        pauseButton.target = self
        pauseButton.action = #selector(pauseClicked)

        let stack = NSStackView(views: [
            statusLabel,
            detailLabel,
            separator(),
            sectionLabel("THIS SESSION"),
            statRow("Good posture", goodTimeValue),
            statRow("Bad posture", badTimeValue),
            separator(),
            sectionLabel("SENSITIVITY"),
            tolerancePopup,
            sectionLabel("WAIT BEFORE NOTIFYING"),
            patiencePopup,
            sectionLabel("REMIND AGAIN WHILE BAD"),
            nudgeRepeatPopup,
            previewCheckbox,
            separator(),
            calibrateButton,
            pauseButton
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.setCustomSpacing(4, after: statusLabel)
        for view in [tolerancePopup, patiencePopup, nudgeRepeatPopup, calibrateButton, pauseButton] {
            view.translatesAutoresizingMaskIntoConstraints = false
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        return stack
    }

    private func sectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.textColor = .tertiaryLabelColor
        return label
    }

    private func statRow(_ title: String, _ value: NSTextField) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13)
        let row = NSStackView(views: [label, NSView(), value])
        row.orientation = .horizontal
        row.translatesAutoresizingMaskIntoConstraints = false
        return row
    }

    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }

    // MARK: - Sidebar state

    /// Ticks once a second while the window is open: totals, button titles,
    /// and popups that may have been changed from the menu bar instead.
    private func refreshControls() {
        let now = Date()
        goodTimeValue.stringValue = format(monitor.tally.goodTotal(at: now))
        badTimeValue.stringValue = format(monitor.tally.badTotal(at: now))
        pauseButton.title = settings.isPaused ? "Resume" : "Pause"
        select(value: settings.tolerance, in: tolerancePopup)
        select(value: settings.patience, in: patiencePopup)
        select(value: settings.nudgeRepeat, in: nudgeRepeatPopup)
        previewCheckbox.state = settings.showPreviewOnNudge ? .on : .off
    }

    private func select(value: Double, in popup: NSPopUpButton) {
        guard let index = popup.itemArray.firstIndex(
            where: { ($0.representedObject as? Double) == value }
        ) else { return }
        popup.selectItem(at: index)
    }

    private func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m \(total % 60)s" }
        return "\(total)s"
    }

    // MARK: - Clicks

    @objc private func calibrateClicked() {
        onCommand?(.calibrate)
    }

    @objc private func pauseClicked() {
        onCommand?(.togglePause)
        refreshControls()
    }

    @objc private func toleranceChanged(_ sender: NSPopUpButton) {
        guard let value = sender.selectedItem?.representedObject as? Double else { return }
        onCommand?(.setTolerance(value))
    }

    @objc private func patienceChanged(_ sender: NSPopUpButton) {
        guard let value = sender.selectedItem?.representedObject as? Double else { return }
        onCommand?(.setPatience(value))
    }

    @objc private func nudgeRepeatChanged(_ sender: NSPopUpButton) {
        guard let value = sender.selectedItem?.representedObject as? Double else { return }
        onCommand?(.setNudgeRepeat(value))
    }

    @objc private func previewToggled() {
        onCommand?(.togglePreviewOnNudge)
    }

    // MARK: - Rendering

    private func render(_ detection: PoseDetection) {
        switch detection {
        case .pose(let snapshot):
            renderPose(snapshot)
        case .nobody:
            previewView.clear()
            setStatus("Cannot see you", color: neutralColor, detail: "")
        case .failed(let reason):
            previewView.clear()
            setStatus(reason, color: warnColor, detail: "")
        }
    }

    private func renderPose(_ snapshot: PoseSnapshot) {
        let verdict = judge(snapshot.reading)
        previewView.drawFace(
            snapshot.faceBox,
            guideHeight: settings.baseline?.uprightness,
            color: verdict.color
        )
        setStatus(verdict.title, color: verdict.color, detail: verdict.detail)
    }

    private func judge(_ reading: Reading) -> (title: String, detail: String, color: NSColor) {
        if case .calibrating(let collected, let needed) = monitor.state {
            return (
                "Calibrating \(collected)/\(needed)",
                "Hold still, sitting the way you want to sit",
                goodColor
            )
        }

        guard let baseline = settings.baseline else {
            return (
                "Not calibrated yet",
                "Click Calibrate while sitting the way you want to sit",
                neutralColor
            )
        }

        let drift = baseline.drift(from: reading)
        let detail = String(
            format: "slump %+.0f%%   lean %+.0f%%   tilt %+.0f%%   tolerance %.0f%%",
            drift.slump * 100, drift.lean * 100, drift.tilt * 100,
            settings.tolerance * 100
        )

        if drift.exceeds(settings.tolerance) {
            return ("Bad posture, \(advice(for: drift))", detail, warnColor)
        }
        return ("Good posture", detail, goodColor)
    }

    /// Names the axis that is furthest gone, so the fix is always actionable.
    private func advice(for drift: Drift) -> String {
        if drift.slump >= drift.lean && drift.slump >= drift.tilt { return "sit up" }
        if drift.lean >= drift.tilt { return "sit back" }
        return "straighten your head"
    }

    private func setStatus(_ title: String, color: NSColor, detail: String) {
        statusLabel.stringValue = title
        statusLabel.textColor = color
        detailLabel.stringValue = detail
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
