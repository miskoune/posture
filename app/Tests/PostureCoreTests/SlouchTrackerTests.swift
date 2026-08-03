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
