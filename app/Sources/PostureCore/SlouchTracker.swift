import Foundation

/// The rule a reading is judged against: the calibrated pose, how far you may
/// stray from it, and how long you may stray before it says anything.
public struct PostureRule: Equatable {
    public let baseline: Baseline
    public let tolerance: Double
    public let patience: TimeInterval

    public init(baseline: Baseline, tolerance: Double, patience: TimeInterval) {
        self.baseline = baseline
        self.tolerance = tolerance
        self.patience = patience
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

/// Decides when a slouch has lasted long enough to deserve the one banner.
///
/// Pure decision logic: no camera, no notifications, no timers. It holds only
/// the two facts that cannot be recomputed from a single reading — when the
/// current slouch began, and whether this slouch has already been mentioned.
public final class SlouchTracker {
    private let clock: Clock
    private var slouchStartedAt: Date?
    private var alreadyNudged = false

    public init(clock: Clock) {
        self.clock = clock
    }

    /// Forgets the current slouch. Used when calibrating or pausing, so the
    /// user is never nudged for a posture the app was told to stop judging.
    public func reset() {
        slouchStartedAt = nil
        alreadyNudged = false
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
            nudgeAfterMinutes: overdueMinutes(since: since, patience: rule.patience)
        )
    }

    /// The nudge fires once per slouch. Sitting up and slouching again earns a
    /// new one; staying folded over does not.
    private func overdueMinutes(since: Date, patience: TimeInterval) -> Int? {
        guard !alreadyNudged else { return nil }

        let elapsed = clock.now.timeIntervalSince(since)
        guard elapsed >= patience else { return nil }

        alreadyNudged = true
        return max(1, Int(elapsed / 60))
    }
}
