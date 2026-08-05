import AppKit
import AVFoundation
import PostureCore

/// The corner mirror. When a nudge fires it appears at the bottom-right of
/// the screen — the camera, the face box, and the calibrated guide line — so
/// the user can steer themselves back into position without opening the
/// dashboard. It leaves the moment the slouch is over.
///
/// A borderless, non-activating panel: it floats over whatever the user is
/// doing, joins every Space, and never steals keyboard focus.
final class NudgePreviewPanelController: NSObject {
    private let settings: SettingsStoring
    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "com.miskoune.posture.nudge-preview")
    private let reader = PoseReader()

    private let panelSize = NSSize(width: 240, height: 170)
    private let screenMargin: CGFloat = 16
    /// Room left above the panel for the notification banner it accompanies —
    /// macOS shows those at the top right, so the mirror sits just beneath.
    private let notificationClearance: CGFloat = 100

    /// Built on first use, never in `init` — the app constructs this
    /// controller before NSApplication is fully up.
    private var panel: NSPanel?
    private var previewView: PreviewView?

    private var isConfigured = false
    /// Vision runs on the capture queue; frames that arrive while it is busy
    /// are dropped rather than queued. Touched only on `queue`.
    private var lastDetectionTime: CFTimeInterval = 0
    private let detectionInterval: CFTimeInterval = 0.2

    init(settings: SettingsStoring) {
        self.settings = settings
    }

    func show() {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        guard !panel.isVisible else { return }

        position(panel)
        panel.orderFrontRegardless()
        queue.async { [weak self] in
            guard let self, self.configure() else { return }
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func hide() {
        guard let panel, panel.isVisible else { return }
        panel.orderOut(nil)
        queue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    // MARK: - The panel

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true

        let preview = PreviewView(session: session)
        preview.layer?.cornerRadius = 12
        preview.layer?.masksToBounds = true
        preview.layer?.borderWidth = 2.5
        preview.layer?.borderColor = NSColor.systemGray.cgColor
        preview.layer?.backgroundColor = NSColor.black.cgColor
        panel.contentView = preview
        previewView = preview

        return panel
    }

    private func position(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let area = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(
            x: area.maxX - panelSize.width - screenMargin,
            y: area.maxY - panelSize.height - notificationClearance
        ))
    }

    // MARK: - Capture

    /// Runs on `queue`. Returns whether the session is usable; a camera that
    /// cannot be opened simply leaves the panel black — the notification
    /// already said what matters.
    private func configure() -> Bool {
        guard !isConfigured else { return true }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .medium

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return false }
        session.addInput(input)

        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { return false }
        session.addOutput(output)

        // A mirror is what people expect to see of themselves.
        DispatchQueue.main.async { [weak self] in
            guard let connection = self?.previewView?.previewLayer.connection,
                  connection.isVideoMirroringSupported else { return }
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }

        isConfigured = true
        return true
    }

    private func render(_ detection: PoseDetection) {
        guard let previewView else { return }

        guard case .pose(let snapshot) = detection else {
            previewView.clear()
            previewView.layer?.borderColor = NSColor.systemGray.cgColor
            return
        }

        let isBad = settings.baseline?
            .drift(from: snapshot.reading)
            .exceeds(settings.tolerance) ?? false
        let color: NSColor = isBad ? .systemOrange : .systemGreen

        previewView.drawFace(
            snapshot.faceBox,
            guideHeight: settings.baseline?.uprightness,
            color: color
        )
        previewView.layer?.borderColor = color.cgColor
    }
}

// MARK: - Frames

extension NudgePreviewPanelController: AVCaptureVideoDataOutputSampleBufferDelegate {
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
