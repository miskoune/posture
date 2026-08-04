import Foundation

/// The rule a reading is judged against: the calibrated pose, how far you may
/// stray from it, how long you may stray before it says anything, and how
/// often it may repeat itself while you keep straying.
public struct PostureRule: Equatable {
    public let baseline: Baseline
    public let tolerance: Double
    public let patience: TimeInterval
    /// Seconds between reminders while the slouch continues. `nil` means say
    /// it once and hold your peace until the user sits up.
    public let repeatEvery: TimeInterval?

    public init(
        baseline: Baseline,
        tolerance: Double,
        patience: TimeInterval,
        repeatEvery: TimeInterval? = nil
    ) {
        self.baseline = baseline
        self.tolerance = tolerance
        self.patience = patience
        self.repeatEvery = repeatEvery
    }
}

/// What the app should do about one reading.
public struct Verdict: Equatable {
    public let state: PostureState
    /// Minutes slouched, when this is the moment to say something. `nil` means
    /// stay quiet — which is the answer almost every time.
    public let nudgeAfterMinutes: Int?

    public var shouldNudge: Bool { nudgeAfterMinutes != nil }
}

/// Decides when a slouch has lasted long enough to deserve a banner.
///
/// Pure decision logic: no camera, no notifications, no timers. It holds only
/// the two facts that cannot be recomputed from a single reading — when the
/// current slouch began, and when it was last mentioned.
public final class SlouchTracker {
    private let clock: Clock
    private var slouchStartedAt: Date?
    private var lastNudgedAt: Date?

    public init(clock: Clock) {
        self.clock = clock
    }

    /// Forgets the current slouch. Used when calibrating or pausing, so the
    /// user is never nudged for a posture the app was told to stop judging.
    public func reset() {
        slouchStartedAt = nil
        lastNudgedAt = nil
    }

    public func evaluate(_ outcome: SensorOutcome, against rule: PostureRule) -> Verdict {
        switch outcome {
        case .unavailable(let reason):
            return Verdict(state: .unavailable(reason: reason), nudgeAfterMinutes: nil)

        case .noPersonVisible:
            // An empty chair is not good posture, but it is not a slouch
            // either. Hold the clock rather than reset it, so stepping out for
            // a moment neither nudges you nor wipes the slouch you left in.
            return Verdict(state: .cannotSee, nudgeAfterMinutes: nil)

        case .measured(let reading):
            return judge(reading, against: rule)
        }
    }

    private func judge(_ reading: Reading, against rule: PostureRule) -> Verdict {
        guard rule.baseline.drift(from: reading).exceeds(rule.tolerance) else {
            reset()
            return Verdict(state: .upright, nudgeAfterMinutes: nil)
        }

        let since = slouchStartedAt ?? clock.now
        slouchStartedAt = since

        return Verdict(
            state: .slouching(since: since),
            nudgeAfterMinutes: overdueMinutes(since: since, rule: rule)
        )
    }

    /// The first nudge fires once patience runs out. After that, the rule's
    /// `repeatEvery` decides whether staying folded over earns reminders or
    /// silence; sitting up always re-arms the first nudge.
    private func overdueMinutes(since: Date, rule: PostureRule) -> Int? {
        guard clock.now.timeIntervalSince(since) >= rule.patience else { return nil }
        guard isDueForAnotherNudge(rule: rule) else { return nil }

        lastNudgedAt = clock.now
        return max(1, Int(clock.now.timeIntervalSince(since) / 60))
    }

    private func isDueForAnotherNudge(rule: PostureRule) -> Bool {
        guard let lastNudgedAt else { return true }
        guard let repeatEvery = rule.repeatEvery else { return false }
        return clock.now.timeIntervalSince(lastNudgedAt) >= repeatEvery
    }
}
