import Foundation

/// The use case: look, judge, and occasionally speak.
///
/// It owns no timer. The app layer decides when to call `sampleNow()`, which
/// keeps every rule in here testable without waiting for real seconds to pass.
public final class PostureMonitor {
    private let sensor: PostureSensor
    private let nudger: NudgeDelivering
    private let settings: SettingsStoring
    private let tracker: SlouchTracker

    private var calibration: Calibration?

    public var onStateChange: ((PostureState) -> Void)?

    public private(set) var state: PostureState {
        didSet {
            guard state != oldValue else { return }
            onStateChange?(state)
        }
    }

    public init(
        sensor: PostureSensor,
        nudger: NudgeDelivering,
        settings: SettingsStoring,
        clock: Clock = SystemClock()
    ) {
        self.sensor = sensor
        self.nudger = nudger
        self.settings = settings
        self.tracker = SlouchTracker(clock: clock)
        self.state = Self.initialState(for: settings)
    }

    private static func initialState(for settings: SettingsStoring) -> PostureState {
        if settings.isPaused { return .paused }
        return settings.baseline == nil ? .needsCalibration : .upright
    }

    // MARK: - Commands

    /// Takes one measurement and acts on it. Safe to call on a timer.
    public func sampleNow() {
        guard !settings.isPaused else { return }
        sensor.sample { [weak self] outcome in
            self?.receive(outcome)
        }
    }

    /// Starts a calibration run. The next few readings define the pose the user
    /// is judged against.
    public func beginCalibration() {
        tracker.reset()
        let run = Calibration()
        calibration = run
        state = .calibrating(collected: run.collected, needed: run.samplesNeeded)
    }

    public func setPaused(_ paused: Bool) {
        settings.isPaused = paused
        tracker.reset()
        calibration = nil
        if paused {
            sensor.rest()
        }
        state = Self.initialState(for: settings)
    }

    // MARK: - Reacting to a measurement

    private func receive(_ outcome: SensorOutcome) {
        if calibration != nil {
            advanceCalibration(with: outcome)
            return
        }

        guard let baseline = settings.baseline else {
            state = .needsCalibration
            return
        }

        let rule = PostureRule(
            baseline: baseline,
            tolerance: settings.tolerance,
            patience: settings.patience
        )

        let verdict = tracker.evaluate(outcome, against: rule)
        state = verdict.state

        if let minutes = verdict.nudgeAfterMinutes {
            nudger.deliverNudge(minutesSlouching: minutes)
        }
    }

    private func advanceCalibration(with outcome: SensorOutcome) {
        guard var run = calibration else { return }

        run.collect(outcome)
        calibration = run

        guard let baseline = run.baseline else {
            state = .calibrating(collected: run.collected, needed: run.samplesNeeded)
            return
        }

        settings.baseline = baseline
        calibration = nil
        state = .upright
    }
}
