import Foundation

/// How this session's time has been spent: sitting well, sitting badly, or
/// neither (paused, calibrating, unseen).
///
/// Fed one transition per state change and asked for totals at some `now`, so
/// an hour of unbroken good posture still reads as an hour — no state change
/// is needed for time to pass.
public struct PostureTally: Equatable {
    private enum Bucket {
        case good
        case bad
    }

    private var goodAccumulated: TimeInterval = 0
    private var badAccumulated: TimeInterval = 0
    private var current: Bucket?
    private var since: Date?

    public init() {}

    public mutating func transition(to state: PostureState, at now: Date) {
        settle(at: now)
        switch state {
        case .upright:
            current = .good
        case .slouching:
            current = .bad
        default:
            current = nil
        }
        since = now
    }

    public func goodTotal(at now: Date) -> TimeInterval {
        goodAccumulated + running(.good, at: now)
    }

    public func badTotal(at now: Date) -> TimeInterval {
        badAccumulated + running(.bad, at: now)
    }

    /// Banks the open bucket's elapsed time. Clocks that jump backwards are
    /// treated as no time passing rather than negative time.
    private mutating func settle(at now: Date) {
        guard let current, let since else { return }
        let elapsed = max(0, now.timeIntervalSince(since))
        switch current {
        case .good: goodAccumulated += elapsed
        case .bad: badAccumulated += elapsed
        }
    }

    private func running(_ bucket: Bucket, at now: Date) -> TimeInterval {
        guard current == bucket, let since else { return 0 }
        return max(0, now.timeIntervalSince(since))
    }
}
