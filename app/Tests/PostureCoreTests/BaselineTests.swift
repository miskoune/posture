import XCTest
@testable import PostureCore

final class BaselineTests: XCTestCase {
    func testAveragingRejectsAnEmptyRun() {
        XCTAssertNil(Baseline(averaging: []))
    }

    func testAveragingMeansOneBadFrameCannotDefineThePose() {
        let good = Reading(uprightness: 1.0, proximity: 0.30)
        let outlier = Reading(uprightness: 0.2, proximity: 0.90)

        let baseline = Baseline(averaging: [good, good, good, good, outlier])

        // The outlier moves the average, but nowhere near its own value.
        XCTAssertEqual(baseline?.uprightness ?? 0, 0.84, accuracy: 0.001)
        XCTAssertEqual(baseline?.proximity ?? 0, 0.42, accuracy: 0.001)
    }

    func testSittingExactlyAsCalibratedHasNoDrift() {
        let baseline = Baseline.upright
        let drift = baseline.drift(
            from: Reading(uprightness: baseline.uprightness, proximity: baseline.proximity)
        )

        XCTAssertEqual(drift.slump, 0, accuracy: 0.0001)
        XCTAssertEqual(drift.lean, 0, accuracy: 0.0001)
        XCTAssertFalse(drift.exceeds(0.15))
    }

    func testHeadSinkingTowardShouldersReadsAsSlump() {
        // 20% less head height than calibrated.
        let drift = Baseline.upright.drift(from: Reading(uprightness: 0.8, proximity: 0.3))

        XCTAssertEqual(drift.slump, 0.2, accuracy: 0.0001)
        XCTAssertTrue(drift.exceeds(0.15))
        XCTAssertFalse(drift.exceeds(0.25))
    }

    func testMovingTowardTheScreenReadsAsLean() {
        // Shoulders 20% wider in frame means 20% closer to the camera.
        let drift = Baseline.upright.drift(from: Reading(uprightness: 1.0, proximity: 0.36))

        XCTAssertEqual(drift.lean, 0.2, accuracy: 0.0001)
        XCTAssertTrue(drift.exceeds(0.15))
    }

    func testSittingBetterThanCalibratedIsNeverASlouch() {
        // Taller and further away than the baseline: both drifts go negative.
        let drift = Baseline.upright.drift(from: Reading(uprightness: 1.4, proximity: 0.2))

        XCTAssertLessThan(drift.slump, 0)
        XCTAssertLessThan(drift.lean, 0)
        XCTAssertFalse(drift.exceeds(0.01))
    }

    func testNoddingTheHeadDownReadsAsTilt() {
        // ~18° of pitch away from calibrated, with the face box unmoved —
        // the slouch the box alone cannot see.
        let drift = Baseline.upright.drift(
            from: Reading(uprightness: 1.0, proximity: 0.3, pitch: -0.32)
        )

        XCTAssertEqual(drift.tilt, 0.2, accuracy: 0.01)
        XCTAssertTrue(drift.exceeds(0.15))
        XCTAssertEqual(drift.slump, 0, accuracy: 0.0001)
    }

    func testTiltingTowardAShoulderReadsAsTilt() {
        let drift = Baseline.upright.drift(
            from: Reading(uprightness: 1.0, proximity: 0.3, roll: 0.32)
        )

        XCTAssertEqual(drift.tilt, 0.2, accuracy: 0.01)
        XCTAssertTrue(drift.exceeds(0.15))
    }

    func testTiltMeasuresDeviationFromTheCalibratedAngleNotFromZero() {
        // Someone whose natural pose Vision reads as pitched is judged
        // against their own calibration, not against an ideal zero.
        let pitched = Baseline(uprightness: 1.0, proximity: 0.3, pitch: -0.2)
        let drift = pitched.drift(
            from: Reading(uprightness: 1.0, proximity: 0.3, pitch: -0.2)
        )

        XCTAssertEqual(drift.tilt, 0, accuracy: 0.0001)
    }

    func testAveragingIncludesTheHeadAngles() {
        let baseline = Baseline(averaging: [
            Reading(uprightness: 1.0, proximity: 0.3, pitch: -0.1, roll: 0.2),
            Reading(uprightness: 1.0, proximity: 0.3, pitch: -0.3, roll: 0.0)
        ])

        XCTAssertEqual(baseline?.pitch ?? .nan, -0.2, accuracy: 0.0001)
        XCTAssertEqual(baseline?.roll ?? .nan, 0.1, accuracy: 0.0001)
    }

    func testNearZeroBaselineCannotExplodeIntoInfiniteDrift() {
        let degenerate = Baseline(uprightness: 0, proximity: 0)
        let drift = degenerate.drift(from: Reading(uprightness: -0.001, proximity: 0.001))

        XCTAssertTrue(drift.slump.isFinite)
        XCTAssertTrue(drift.lean.isFinite)
    }

    func testBaselineSurvivesEncodingRoundTrip() throws {
        let original = Baseline.upright
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(Baseline.self, from: data)

        XCTAssertEqual(original, restored)
    }
}
