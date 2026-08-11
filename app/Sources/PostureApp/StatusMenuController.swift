import AppKit
import PostureCore

/// The menu bar: the current verdict and the few actions worth reaching for
/// quickly. Everything configurable lives in the dashboard's settings page.
///
/// Presentation only: it renders a `PostureState` and reports what the user
/// clicked. Every decision belongs to `PostureMonitor`.
final class StatusMenuController {
    /// What the user asked for. The delegate decides what it means.
    enum Command {
        case calibrate
        case showDashboard
        case togglePause
        case setTolerance(Double)
        case setPatience(Double)
        case setNudgeRepeat(Double)
        case togglePreviewOnNudge
    }

    private let statusItem = NSStatusBar.system.statusItem(
        withLength: NSStatusItem.variableLength
    )
    private let stateItem = NSMenuItem(title: "Starting…", action: nil, keyEquivalent: "")
    private let pauseItem = NSMenuItem(title: "Pause", action: nil, keyEquivalent: "")

    var onCommand: ((Command) -> Void)?

    init() {
        buildMenu()
    }

    // MARK: - Rendering

    func render(_ state: PostureState, isPaused: Bool) {
        let look = describe(state)
        stateItem.title = look.title
        pauseItem.title = isPaused ? "Resume" : "Pause"
        statusItem.button?.toolTip = "Posture: \(look.title)"
        apply(symbolNamed: look.symbol, badge: look.badge)
    }

    private func describe(
        _ state: PostureState
    ) -> (title: String, symbol: String, badge: String?) {
        switch state {
        case .needsCalibration:
            return ("Not calibrated yet", "app", nil)
        case .calibrating(let collected, let needed):
            return ("Calibrating \(collected)/\(needed), hold still", "app", nil)
        case .paused:
            return ("Paused", "pause.circle", nil)
        case .cannotSee:
            return ("Cannot see you", "eye.slash", nil)
        case .unavailable(let reason):
            return (reason, "exclamationmark.circle", nil)
        case .upright:
            return ("Good posture", "app", "checkmark")
        case .slouching:
            return ("Bad posture", "app", "xmark")
        }
    }

    private func apply(symbolNamed name: String, badge: String? = nil) {
        statusItem.button?.image = composedIcon(symbol: name, badge: badge)
    }

    /// The square with a small verdict badge tucked into its bottom-right
    /// corner — a check when sitting well, a cross when slouching. Drawn as
    /// one template image so the menu bar tints it like any other icon.
    private func composedIcon(symbol: String, badge: String?) -> NSImage? {
        // Medium weight so the square carries the same mass as the app icon.
        let base = NSImage(systemSymbolName: symbol, accessibilityDescription: "Posture")?
            .withSymbolConfiguration(.init(pointSize: 15, weight: .medium))
        guard let base else { return nil }

        guard let badge,
              let badgeImage = NSImage(systemSymbolName: badge, accessibilityDescription: nil)?
                  .withSymbolConfiguration(.init(pointSize: 7, weight: .black)) else {
            base.isTemplate = true
            return base
        }

        let canvas = NSSize(width: 22, height: 17)
        let composed = NSImage(size: canvas, flipped: false) { _ in
            // The square sits left, the badge fully clear of it on the right —
            // side by side rather than punched into the corner, so neither
            // crowds the other.
            let baseRect = NSRect(
                x: 0,
                y: (canvas.height - base.size.height) / 2,
                width: base.size.width,
                height: base.size.height
            )
            base.draw(in: baseRect)

            let badgeRect = NSRect(
                x: canvas.width - badgeImage.size.width,
                y: 0,
                width: badgeImage.size.width,
                height: badgeImage.size.height
            )
            // Punch a gap around the badge so it reads against the square
            // rather than merging with it.
            NSColor.black.set()
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            NSBezierPath(ovalIn: badgeRect.insetBy(dx: -2, dy: -2)).fill()
            NSGraphicsContext.current?.compositingOperation = .sourceOver
            badgeImage.draw(in: badgeRect)
            return true
        }
        composed.isTemplate = true
        return composed
    }

    // MARK: - Building

    private func buildMenu() {
        let menu = NSMenu()

        menu.addItem(stateItem)
        menu.addItem(.separator())

        let dashboard = NSMenuItem(
            title: "Settings",
            action: #selector(dashboardClicked),
            keyEquivalent: ""
        )
        dashboard.target = self
        menu.addItem(dashboard)

        let calibrate = NSMenuItem(
            title: "Calibrate",
            action: #selector(calibrateClicked),
            keyEquivalent: ""
        )
        calibrate.target = self
        calibrate.toolTip = "Sit the way you want to sit, then click"
        menu.addItem(calibrate)

        pauseItem.action = #selector(pauseClicked)
        pauseItem.target = self
        menu.addItem(pauseItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit Posture",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        statusItem.menu = menu
        apply(symbolNamed: "app")
    }

    // MARK: - Clicks

    @objc private func calibrateClicked() {
        onCommand?(.calibrate)
    }

    @objc private func dashboardClicked() {
        onCommand?(.showDashboard)
    }

    @objc private func pauseClicked() {
        onCommand?(.togglePause)
    }
}
