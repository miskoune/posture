import AppKit
import PostureCore

/// The menu bar. There is no window, no dock icon and no preferences pane —
/// everything the app can do fits in one menu.
///
/// Presentation only: it renders a `PostureState` and reports what the user
/// clicked. Every decision belongs to `PostureMonitor`.
final class StatusMenuController {
    /// What the user asked for. The delegate decides what it means.
    enum Command {
        case calibrate
        case showPreview
        case togglePause
        case setTolerance(Double)
        case setPatience(Double)
    }

    private let statusItem = NSStatusBar.system.statusItem(
        withLength: NSStatusItem.variableLength
    )
    private let stateItem = NSMenuItem(title: "Starting…", action: nil, keyEquivalent: "")
    private let pauseItem = NSMenuItem(title: "Pause", action: nil, keyEquivalent: "")

    private let tolerances: [(label: String, value: Double)] = [
        ("Relaxed", 0.25),
        ("Normal", 0.15),
        ("Strict", 0.08)
    ]

    private let patiences: [(label: String, value: Double)] = [
        ("30 seconds", 30),
        ("2 minutes", 120),
        ("5 minutes", 300),
        ("15 minutes", 900)
    ]

    var onCommand: ((Command) -> Void)?

    init(tolerance: Double, patience: TimeInterval) {
        buildMenu(tolerance: tolerance, patience: patience)
    }

    // MARK: - Rendering

    func render(_ state: PostureState, isPaused: Bool) {
        let look = describe(state)
        stateItem.title = look.title
        pauseItem.title = isPaused ? "Resume" : "Pause"
        statusItem.button?.toolTip = "Posture — \(look.title)"
        apply(symbolNamed: look.symbol, badge: look.badge)
    }

    private func describe(
        _ state: PostureState
    ) -> (title: String, symbol: String, badge: String?) {
        switch state {
        case .needsCalibration:
            return ("Not calibrated yet", "figure.stand", nil)
        case .calibrating(let collected, let needed):
            return ("Calibrating \(collected)/\(needed) — hold still", "figure.stand", nil)
        case .paused:
            return ("Paused", "pause.circle", nil)
        case .cannotSee:
            return ("Cannot see you", "eye.slash", nil)
        case .unavailable(let reason):
            return (reason, "exclamationmark.circle", nil)
        case .upright:
            return ("Good posture", "figure.stand", "checkmark")
        case .slouching:
            return ("Bad posture", "figure.stand", "xmark")
        }
    }

    private func apply(symbolNamed name: String, badge: String? = nil) {
        statusItem.button?.image = composedIcon(symbol: name, badge: badge)
    }

    /// The figure with a small verdict badge tucked into its bottom-right
    /// corner — a check when sitting well, a cross when slouching. Drawn as
    /// one template image so the menu bar tints it like any other icon.
    private func composedIcon(symbol: String, badge: String?) -> NSImage? {
        let base = NSImage(systemSymbolName: symbol, accessibilityDescription: "Posture")?
            .withSymbolConfiguration(.init(pointSize: 15, weight: .regular))
        guard let base else { return nil }

        guard let badge,
              let badgeImage = NSImage(systemSymbolName: badge, accessibilityDescription: nil)?
                  .withSymbolConfiguration(.init(pointSize: 7, weight: .black)) else {
            base.isTemplate = true
            return base
        }

        let canvas = NSSize(width: 20, height: 17)
        let composed = NSImage(size: canvas, flipped: false) { _ in
            let baseRect = NSRect(
                x: (canvas.width - base.size.width) / 2 - 2,
                y: (canvas.height - base.size.height) / 2,
                width: base.size.width,
                height: base.size.height
            )
            base.draw(in: baseRect)

            let badgeRect = NSRect(
                x: canvas.width - badgeImage.size.width - 1,
                y: 0,
                width: badgeImage.size.width,
                height: badgeImage.size.height
            )
            // Punch a gap around the badge so it reads against the figure
            // rather than merging with it.
            NSColor.black.set()
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            NSBezierPath(ovalIn: badgeRect.insetBy(dx: -1.5, dy: -1.5)).fill()
            NSGraphicsContext.current?.compositingOperation = .sourceOver
            badgeImage.draw(in: badgeRect)
            return true
        }
        composed.isTemplate = true
        return composed
    }

    // MARK: - Building

    private func buildMenu(tolerance: Double, patience: TimeInterval) {
        let menu = NSMenu()

        menu.addItem(stateItem)
        menu.addItem(.separator())

        let calibrate = NSMenuItem(
            title: "Calibrate — sit how you want to sit",
            action: #selector(calibrateClicked),
            keyEquivalent: ""
        )
        calibrate.target = self
        menu.addItem(calibrate)

        let preview = NSMenuItem(
            title: "Show Preview — see what it sees",
            action: #selector(previewClicked),
            keyEquivalent: ""
        )
        preview.target = self
        menu.addItem(preview)

        pauseItem.action = #selector(pauseClicked)
        pauseItem.target = self
        menu.addItem(pauseItem)

        menu.addItem(.separator())
        menu.addItem(choiceMenu(
            title: "Sensitivity",
            options: tolerances,
            current: tolerance,
            action: #selector(toleranceClicked(_:))
        ))
        menu.addItem(choiceMenu(
            title: "Wait before nudging",
            options: patiences,
            current: patience,
            action: #selector(patienceClicked(_:))
        ))

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit Posture",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        statusItem.menu = menu
        apply(symbolNamed: "figure.stand")
    }

    private func choiceMenu(
        title: String,
        options: [(label: String, value: Double)],
        current: Double,
        action: Selector
    ) -> NSMenuItem {
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let menu = NSMenu()

        for option in options {
            let item = NSMenuItem(title: option.label, action: action, keyEquivalent: "")
            item.target = self
            item.representedObject = option.value
            item.state = (option.value == current) ? .on : .off
            menu.addItem(item)
        }

        parent.submenu = menu
        return parent
    }

    // MARK: - Clicks

    @objc private func calibrateClicked() {
        onCommand?(.calibrate)
    }

    @objc private func previewClicked() {
        onCommand?(.showPreview)
    }

    @objc private func pauseClicked() {
        onCommand?(.togglePause)
    }

    @objc private func toleranceClicked(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Double else { return }
        tick(sender)
        onCommand?(.setTolerance(value))
    }

    @objc private func patienceClicked(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Double else { return }
        tick(sender)
        onCommand?(.setPatience(value))
    }

    private func tick(_ sender: NSMenuItem) {
        sender.menu?.items.forEach { $0.state = ($0 === sender) ? .on : .off }
    }
}
