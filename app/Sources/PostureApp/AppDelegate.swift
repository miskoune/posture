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
    private var dashboard: DashboardWindowController?
    private var timer: Timer?
    private var timerInterval: TimeInterval = 0

    /// Calibration wants five clean readings; at the normal sampling pace
    /// that is close to half a minute of apparent silence. Sampling fast
    /// while calibrating turns it into a couple of seconds.
    private let calibrationSampleInterval: TimeInterval = 0.5

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

        let dashboard = DashboardWindowController(settings: settings, monitor: monitor)
        dashboard.onCommand = { [weak self] command in
            self?.handle(command)
        }
        self.dashboard = dashboard

        monitor.onStateChange = { [weak self] state in
            self?.render(state)
        }
        render(monitor.state)

        nudger.requestAuthorization()
        CameraSensor.requestAccess { [weak self] granted in
            guard granted else {
                self?.render(.unavailable(reason: "Camera access denied"))
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
        schedule(interval: desiredInterval(for: monitor.state))
        monitor.sampleNow()
    }

    private func schedule(interval: TimeInterval) {
        timer?.invalidate()
        timerInterval = interval

        let timer = Timer(
            timeInterval: interval,
            target: self,
            selector: #selector(tick),
            userInfo: nil,
            repeats: true
        )
        // .common keeps it firing while a menu is open, which is exactly when
        // someone is checking whether the thing works.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func desiredInterval(for state: PostureState) -> TimeInterval {
        if case .calibrating = state { return calibrationSampleInterval }
        return settings.sampleInterval
    }

    /// Speeds the clock up while calibrating and back down afterwards. Only
    /// once sampling has started — before camera access there is no timer to
    /// retune.
    private func retuneTimer(for state: PostureState) {
        guard timer != nil else { return }
        let desired = desiredInterval(for: state)
        guard desired != timerInterval else { return }
        schedule(interval: desired)
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
        case .showDashboard:
            dashboard?.show()
        case .togglePause:
            monitor.setPaused(!settings.isPaused)
            render(monitor.state)
        case .setTolerance(let value):
            settings.tolerance = value
            menu?.syncChoices(tolerance: settings.tolerance, patience: settings.patience)
        case .setPatience(let value):
            settings.patience = value
            menu?.syncChoices(tolerance: settings.tolerance, patience: settings.patience)
        }
    }

    private func render(_ state: PostureState) {
        menu?.render(state, isPaused: settings.isPaused)
        retuneTimer(for: state)
    }
}
