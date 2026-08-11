import AppKit
import AVFoundation
import SwiftUI
import PostureCore

/// The app's one real window, now a SwiftUI shell: a collapsible sidebar with
/// the app identity and pages (camera, stats, settings) and the selected page
/// filling the rest. This controller owns the window, its camera feed, and
/// the bridge between the AppKit world and the `DashboardModel` the SwiftUI
/// views observe. Green means good posture, amber means bad, matching the
/// site.
///
/// The window owns its own camera feed, separate from the always-on
/// `CameraSensor`. It streams only while the window is open and stops the
/// moment it closes. While open, the app also steps up from menu-bar accessory
/// to a regular app with a Dock icon — a window deserves an app switcher entry.
final class DashboardWindowController: NSWindowController, NSWindowDelegate {
    private let settings: SettingsStoring
    private let monitor: PostureMonitor
    private let feed: CameraFeed
    private let previewView: PreviewView
    private let model = DashboardModel()

    private var statsTimer: Timer?

    /// What the user asked for; the delegate decides what it means. The same
    /// `AppCommand` vocabulary as the menu bar, so `AppDelegate` handles both
    /// sources identically.
    var onCommand: ((AppCommand) -> Void)? {
        didSet { model.onCommand = onCommand }
    }

    init(settings: SettingsStoring, monitor: PostureMonitor) {
        self.settings = settings
        self.monitor = monitor
        let feed = CameraFeed(
            preset: .high,
            queueLabel: "com.miskoune.posture.dashboard"
        )
        self.feed = feed
        self.previewView = PreviewView(session: feed.session)

        let hosting = NSHostingController(
            rootView: DashboardView(model: model, previewView: previewView)
        )
        // Never let SwiftUI drive the window frame. Each page reports a
        // different ideal/minimum size (the camera page hosts an AppKit
        // view), and any sizing option makes the window jump when tabs
        // switch. The window enforces its own minimum instead.
        hosting.sizingOptions = []
        let window = NSWindow(contentViewController: hosting)
        window.title = "Posture"
        window.setContentSize(NSSize(width: 920, height: 560))
        window.contentMinSize = NSSize(width: 760, height: 480)
        window.toolbarStyle = .unified
        window.titlebarSeparatorStyle = .automatic
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        window.delegate = self
        feed.onDetection = { [weak self] detection in
            self?.render(detection)
        }
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

        feed.start(mirroring: previewView) { [weak self] failure in
            self?.setStatus(failure, tone: .bad, detail: "")
        }
    }

    func windowWillClose(_ notification: Notification) {
        statsTimer?.invalidate()
        statsTimer = nil
        NSApp.setActivationPolicy(.accessory)
        feed.stop()
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
}
