import AppKit
import PostureCore

/// Drives the clock and connects the menu to the monitor. The only type in the
/// app that knows both sides exist.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings: SettingsStoring
    private let monitor: PostureMonitor
    private let nudger: NotificationNudger

    /// Built in `applicationDidFinishLaunching`, never in `init`: an
    /// NSStatusItem may only be created once NSApplication is up.
    private var menu: StatusMenuController?
    private var timer: Timer?

    init(
        settings: SettingsStoring,
        monitor: PostureMonitor,
        nudger: NotificationNudger
    ) {
        self.settings = settings
        self.monitor = monitor
        self.nudger = nudger
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = StatusMenuController(
            tolerance: settings.tolerance,
            patience: settings.patience
        )
        menu.onCommand = { [weak self] command in
            self?.handle(command)
        }
        self.menu = menu

        monitor.onStateChange = { [weak self] state in
            self?.renderMenu(state)
        }
        renderMenu(monitor.state)

        nudger.requestAuthorization()
        CameraSensor.requestAccess { [weak self] granted in
            guard granted else {
                self?.renderMenu(.unavailable(reason: "Camera access denied"))
                return
            }
            self?.startSampling()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - The clock

    private func startSampling() {
        timer?.invalidate()

        let timer = Timer(
            timeInterval: settings.sampleInterval,
            target: self,
            selector: #selector(tick),
            userInfo: nil,
            repeats: true
        )
        // .common keeps it firing while a menu is open, which is exactly when
        // someone is checking whether the thing works.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        monitor.sampleNow()
    }

    @objc private func tick() {
        monitor.sampleNow()
    }

    // MARK: - Wiring

    private func handle(_ command: StatusMenuController.Command) {
        switch command {
        case .calibrate:
            monitor.beginCalibration()
        case .togglePause:
            monitor.setPaused(!settings.isPaused)
            renderMenu(monitor.state)
        case .setTolerance(let value):
            settings.tolerance = value
        case .setPatience(let value):
            settings.patience = value
        }
    }

    private func renderMenu(_ state: PostureState) {
        menu?.render(state, isPaused: settings.isPaused)
    }
}
