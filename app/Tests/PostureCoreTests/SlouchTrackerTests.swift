import XCTest
@testable import PostureCore

final class SlouchTrackerTests: XCTestCase {
    private let rule = PostureRule(baseline: .upright, tolerance: 0.15, patience: 120)

    private let goodPosture = SensorOutcome.measured(
        Reading(uprightness: 1.0, proximity: 0.3)
    )
    private let slouched = SensorOutcome.measured(
        Reading(uprightness: 0.7, proximity: 0.3)
    )

    private func makeTracker() -> (SlouchTracker, FakeClock) {
        let clock = FakeClock()
        return (SlouchTracker(clock: clock), clock)
    }

    func testSittingWellSaysNothing() {
        let (tracker, _) = makeTracker()

        let verdict = tracker.evaluate(goodPosture, against: rule)

        XCTAssertEqual(verdict.state, .upright)
        XCTAssertFalse(verdict.shouldNudge)
    }

    func testASlouchShorterThanPatienceIsToleratedInSilence() {
        let (tracker, clock) = makeTracker()

        _ = tracker.evaluate(slouched, against: rule)
        clock.advance(seconds: 119)
        let verdict = tracker.evaluate(slouched, against: rule)

        XCTAssertFalse(verdict.shouldNudge, "119s is inside the 120s patience")
    }

    func testTheNudgeArrivesOncePatienceHasPassed() {
        let (tracker, clock) = makeTracker()

        _ = tracker.evaluate(slouched, against: rule)
        clock.advance(seconds: 120)
        let verdict = tracker.evaluate(slouched, against: rule)

        XCTAssertTrue(verdict.shouldNudge)
        XCTAssertEqual(verdict.nudgeAfterMinutes, 2)
    }

    func testItNudgesOnlyOncePerSlouch() {
        let (tracker, clock) = makeTracker()

        _ = tracker.evaluate(slouched, against: rule)
        clock.advance(seconds: 200)
        let first = tracker.evaluate(slouched, against: rule)

        clock.advance(seconds: 600)
        let second = tracker.evaluate(slouched, against: rule)

        XCTAssertTrue(first.shouldNudge)
        XCTAssertFalse(second.shouldNudge, "staying folded over must not repeat")
    }

    func testSittingUpRearmsTheNudge() {
        let (tracker, clock) = makeTracker()

        _ = tracker.evaluate(slouched, against: rule)
        clock.advance(seconds: 200)
        XCTAssertTrue(tracker.evaluate(slouched, against: rule).shouldNudge)

        // Sit back up, then slide again.
        _ = tracker.evaluate(goodPosture, against: rule)
        _ = tracker.evaluate(slouched, against: rule)
        clock.advance(seconds: 200)

        XCTAssertTrue(
            tracker.evaluate(slouched, against: rule).shouldNudge,
            "a new slouch deserves a new nudge"
        )
    }

    func testARepeatingRuleNudgesAgainAfterTheRepeatInterval() {
        let (tracker, clock) = makeTracker()
        let repeating = PostureRule(
            baseline: .upright, tolerance: 0.15, patience: 120, repeatEvery: 300
        )

        _ = tracker.evaluate(slouched, against: repeating)
        clock.advance(seconds: 120)
        XCTAssertTrue(tracker.evaluate(slouched, against: repeating).shouldNudge)

        clock.advance(seconds: 299)
        XCTAssertFalse(
            tracker.evaluate(slouched, against: repeating).shouldNudge,
            "299s is inside the 300s repeat interval"
        )

        clock.advance(seconds: 1)
        let reminder = tracker.evaluate(slouched, against: repeating)
        XCTAssertTrue(reminder.shouldNudge)
        XCTAssertEqual(reminder.nudgeAfterMinutes, 7, "120s + 300s of slouching")
    }

    func testARepeatingRuleKeepsRemindingForAsLongAsTheSlouchLasts() {
        let (tracker, clock) = makeTracker()
        let repeating = PostureRule(
            baseline: .upright, tolerance: 0.15, patience: 120, repeatEvery: 300
        )

        var nudges = 0
        for _ in 0..<40 {
            clock.advance(seconds: 30)
            if tracker.evaluate(slouched, against: repeating).shouldNudge {
                nudges += 1
            }
        }

        XCTAssertEqual(nudges, 4, "20 minutes folded over: patience, then every 5")
    }

    func testTheRepeatClockStartsAtTheLastNudgeNotTheSlouch() {
        let (tracker, clock) = makeTracker()
        let repeating = PostureRule(
            baseline: .upright, tolerance: 0.15, patience: 120, repeatEvery: 300
        )

        // The first nudge lands late — nothing sampled until well past patience.
        _ = tracker.evaluate(slouched, against: repeating)
        clock.advance(seconds: 400)
        XCTAssertTrue(tracker.evaluate(slouched, against: repeating).shouldNudge)

        // 300s after the slouch began has passed, but not 300s after the nudge.
        clock.advance(seconds: 100)
        XCTAssertFalse(tracker.evaluate(slouched, against: repeating).shouldNudge)
    }

    func testSittingUpSilencesARepeatingRule() {
        let (tracker, clock) = makeTracker()
        let repeating = PostureRule(
            baseline: .upright, tolerance: 0.15, patience: 120, repeatEvery: 300
        )

        _ = tracker.evaluate(slouched, against: repeating)
        clock.advance(seconds: 120)
        XCTAssertTrue(tracker.evaluate(slouched, against: repeating).shouldNudge)

        _ = tracker.evaluate(goodPosture, against: repeating)
        clock.advance(seconds: 600)

        XCTAssertFalse(
            tracker.evaluate(goodPosture, against: repeating).shouldNudge,
            "good posture earns silence, however long ago the last nudge was"
        )
    }

    func testTheSlouchClockStartsAtTheFirstBadReading() {
        let (tracker, clock) = makeTracker()
        let started = clock.now

        _ = tracker.evaluate(slouched, against: rule)
        clock.advance(seconds: 60)
        let verdict = tracker.evaluate(slouched, against: rule)

        XCTAssertEqual(verdict.state, .slouching(since: started))
    }

    func testAnEmptyChairNeitherNudgesNorForgets() {
        let (tracker, clock) = makeTracker()
        let started = clock.now

        _ = tracker.evaluate(slouched, against: rule)
        clock.advance(seconds: 60)

        let away = tracker.evaluate(.noPersonVisible, against: rule)
        XCTAssertEqual(away.state, .cannotSee)
        XCTAssertFalse(away.shouldNudge)

        clock.advance(seconds: 60)
        let back = tracker.evaluate(slouched, against: rule)

        XCTAssertEqual(
            back.state,
            .slouching(since: started),
            "stepping away must not restart the slouch clock"
        )
        XCTAssertTrue(back.shouldNudge)
    }

    func testAnUnavailableCameraIsReportedNotGuessedAt() {
        let (tracker, _) = makeTracker()

        let verdict = tracker.evaluate(
            .unavailable(reason: "No camera found"),
            against: rule
        )

        XCTAssertEqual(verdict.state, .unavailable(reason: "No camera found"))
        XCTAssertFalse(verdict.shouldNudge)
    }

    func testResetForgetsTheCurrentSlouch() {
        let (tracker, clock) = makeTracker()

        _ = tracker.evaluate(slouched, against: rule)
        clock.advance(seconds: 200)
        tracker.reset()

        let verdict = tracker.evaluate(slouched, against: rule)

        XCTAssertFalse(verdict.shouldNudge, "the clock restarts after a reset")
        XCTAssertEqual(verdict.state, .slouching(since: clock.now))
    }

    func testAStricterToleranceCatchesASmallerDrift() {
        let (tracker, _) = makeTracker()
        let slightSlouch = SensorOutcome.measured(
            Reading(uprightness: 0.9, proximity: 0.3)
        )
        let strict = PostureRule(baseline: .upright, tolerance: 0.08, patience: 120)

        XCTAssertEqual(tracker.evaluate(slightSlouch, against: rule).state, .upright)

        let (stricter, clock) = makeTracker()
        XCTAssertEqual(
            stricter.evaluate(slightSlouch, against: strict).state,
            .slouching(since: clock.now)
        )
    }
}
