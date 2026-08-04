import AppKit
import AVFoundation
import PostureCore

/// A window that shows you what the camera sees, with the measured landmarks
/// drawn on top and a verdict underneath — the "am I sitting well right now?"
/// mirror. Green means upright, amber means slouching, matching the site.
///
/// The window owns its own capture session, separate from the duty-cycled
/// `CameraSensor`. It streams only while the window is open and stops the
/// moment it closes, so the monitor's blinking-light behaviour is untouched
/// the rest of the time.
final class PreviewWindowController: NSWindowController, NSWindowDelegate {
    private let settings: SettingsStoring
    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "com.miskoune.posture.preview")
    private let reader = PoseReader()

    private let previewView: PreviewView
    private let statusLabel = NSTextField(labelWithString: "Starting camera…")
    private let detailLabel = NSTextField(labelWithString: "")

    private var isConfigured = false
    /// Vision runs on the capture queue; frames that arrive while it is busy
    /// are dropped rather than queued. Touched only on `queue`.
    private var lastDetectionTime: CFTimeInterval = 0
    private let detectionInterval: CFTimeInterval = 0.2

    private let goodColor = NSColor.systemGreen
    private let warnColor = NSColor.systemOrange
    private let neutralColor = NSColor.systemGray

    /// Mirrors the monitor, so the window can narrate a calibration run
    /// instead of flatly repeating "not calibrated" while one is underway.
    var monitorState: PostureState = .needsCalibration

    init(settings: SettingsStoring) {
        self.settings = settings
        self.previewView = PreviewView(session: session)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 460),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Posture — Preview"
        window.minSize = NSSize(width: 360, height: 300)
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
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)

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

        let bar = NSVisualEffectView()
        bar.material = .hudWindow
        bar.blendingMode = .withinWindow
        bar.state = .active
        bar.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(bar)

        statusLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        statusLabel.textColor = neutralColor
        statusLabel.alignment = .center
        detailLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.alignment = .center

        let stack = NSStackView(views: [statusLabel, detailLabel])
        stack.orientation = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(stack)

        NSLayoutConstraint.activate([
            previewView.topAnchor.constraint(equalTo: content.topAnchor),
            previewView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            previewView.bottomAnchor.constraint(equalTo: bar.topAnchor),

            bar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            bar.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            bar.heightAnchor.constraint(equalToConstant: 56),

            stack.centerXAnchor.constraint(equalTo: bar.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: bar.centerYAnchor)
        ])

        window.contentView = content
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
        if case .calibrating(let collected, let needed) = monitorState {
            return (
                "Calibrating \(collected)/\(needed)",
                "Hold still, sitting the way you want to sit",
                goodColor
            )
        }

        guard let baseline = settings.baseline else {
            return (
                "Not calibrated yet",
                "Open the menu bar icon and press Calibrate",
                neutralColor
            )
        }

        let drift = baseline.drift(from: reading)
        let detail = String(
            format: "slump %+.0f%%   lean %+.0f%%   tolerance %.0f%%",
            drift.slump * 100, drift.lean * 100, settings.tolerance * 100
        )

        if drift.exceeds(settings.tolerance) {
            let axis = drift.slump > drift.lean ? "sit up" : "sit back"
            return ("Slouching — \(axis)", detail, warnColor)
        }
        return ("Upright", detail, goodColor)
    }

    private func setStatus(_ title: String, color: NSColor, detail: String) {
        statusLabel.stringValue = title
        statusLabel.textColor = color
        detailLabel.stringValue = detail
    }
}

// MARK: - Frames

extension PreviewWindowController: AVCaptureVideoDataOutputSampleBufferDelegate {
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

// MARK: - The video view

/// Hosts the preview layer, the face box drawn over it, and a dashed guide
/// line at the calibrated head height.
private final class PreviewView: NSView {
    let previewLayer: AVCaptureVideoPreviewLayer
    private let faceLayer = CAShapeLayer()
    private let guideLayer = CAShapeLayer()

    init(session: AVCaptureSession) {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        super.init(frame: .zero)

        wantsLayer = true
        previewLayer.videoGravity = .resizeAspect

        faceLayer.fillColor = nil
        faceLayer.lineWidth = 3
        faceLayer.lineJoin = .round

        guideLayer.fillColor = nil
        guideLayer.lineWidth = 1.5
        guideLayer.lineDashPattern = [6, 6]
        guideLayer.strokeColor = NSColor.white.withAlphaComponent(0.6).cgColor

        layer?.addSublayer(previewLayer)
        layer?.addSublayer(guideLayer)
        layer?.addSublayer(faceLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.frame = bounds
        faceLayer.frame = bounds
        guideLayer.frame = bounds
        CATransaction.commit()
    }

    /// `faceBox` in Vision's normalised coordinates; `guideHeight` is the
    /// calibrated head height (the baseline's uprightness), or nil before
    /// calibration.
    func drawFace(_ faceBox: CGRect, guideHeight: Double?, color: NSColor) {
        // The preview conversion is axis-aligned, so two opposite corners
        // are enough to rebuild the rectangle, mirrored and fitted.
        let a = convert(CGPoint(x: faceBox.minX, y: faceBox.minY))
        let b = convert(CGPoint(x: faceBox.maxX, y: faceBox.maxY))
        let rect = CGRect(
            x: min(a.x, b.x), y: min(a.y, b.y),
            width: abs(b.x - a.x), height: abs(b.y - a.y)
        )
        let face = CGPath(
            roundedRect: rect,
            cornerWidth: min(12, rect.width / 4),
            cornerHeight: min(12, rect.height / 4),
            transform: nil
        )

        let guide = CGMutablePath()
        if let guideHeight {
            let y = convert(CGPoint(x: 0.5, y: guideHeight)).y
            guide.move(to: CGPoint(x: 0, y: y))
            guide.addLine(to: CGPoint(x: bounds.width, y: y))
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        faceLayer.path = face
        faceLayer.strokeColor = color.cgColor
        guideLayer.path = guide
        CATransaction.commit()
    }

    func clear() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        faceLayer.path = nil
        guideLayer.path = nil
        CATransaction.commit()
    }

    /// Vision's origin is bottom-left; the preview layer wants capture-device
    /// coordinates with origin top-left, and hands back a point that already
    /// accounts for aspect fitting and mirroring.
    private func convert(_ visionPoint: CGPoint) -> CGPoint {
        previewLayer.layerPointConverted(
            fromCaptureDevicePoint: CGPoint(x: visionPoint.x, y: 1 - visionPoint.y)
        )
    }
}
