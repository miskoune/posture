import Foundation
@testable import PostureCore

/// Time under test control, so "two minutes of slouching" costs no seconds.
final class FakeClock: Clock {
    var now: Date

    init(now: Date = Date(timeIntervalSince1970: 0)) {
        self.now = now
    }

    func advance(seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }
}

/// A sensor that answers with whatever the test queued, immediately.
final class FakeSensor: PostureSensor {
    var nextOutcome: SensorOutcome = .noPersonVisible
    private(set) var sampleCount = 0

    func sample(completion: @escaping (SensorOutcome) -> Void) {
        sampleCount += 1
        completion(nextOutcome)
    }
}

final class FakeNudger: NudgeDelivering {
    private(set) var nudges: [Int] = []

    func deliverNudge(minutesSlouching: Int) {
        nudges.append(minutesSlouching)
    }
}

final class FakeSettings: SettingsStoring {
    var baseline: Baseline?
    var tolerance: Double = 0.15
    var patience: TimeInterval = 120
    var sampleInterval: TimeInterval = 5
    var isPaused = false

    init(baseline: Baseline? = nil) {
        self.baseline = baseline
    }
}

extension Baseline {
    /// A calibrated pose to measure against in tests.
    static var upright: Baseline {
        Baseline(uprightness: 1.0, proximity: 0.3)
    }
}
