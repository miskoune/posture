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
        let (title, symbol) = describe(state)
        stateItem.title = title
        pauseItem.title = isPaused ? "Resume" : "Pause"
        statusItem.button?.toolTip = "Posture — \(title)"
        apply(symbolNamed: symbol)
    }

    private func describe(_ state: PostureState) -> (title: String, symbol: String) {
        switch state {
        case .needsCalibration:
            return ("Not calibrated yet", "figure.stand")
        case .calibrating(let collected, let needed):
            return ("Calibrating \(collected)/\(needed) — hold still", "figure.stand")
        case .paused:
            return ("Paused", "pause.circle")
        case .cannotSee:
            return ("Cannot see you", "eye.slash")
        case .unavailable(let reason):
            return (reason, "exclamationmark.circle")
        case .upright:
            return ("Upright", "figure.stand")
        case .slouching(let since):
            let minutes = max(1, Int(Date().timeIntervalSince(since) / 60))
            return ("Slouching for \(minutes) min", "exclamationmark.triangle")
        }
    }

    private func apply(symbolNamed name: String) {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Posture")
        image?.isTemplate = true
        statusItem.button?.image = image
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
