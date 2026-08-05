import XCTest
@testable import PostureCore

final class PostureMonitorTests: XCTestCase {
    private let slouched = SensorOutcome.measured(
        Reading(uprightness: 0.7, proximity: 0.3)
    )
    private let goodPosture = SensorOutcome.measured(
        Reading(uprightness: 1.0, proximity: 0.3)
    )

    private func makeMonitor(
        settings: FakeSettings
    ) -> (PostureMonitor, FakeSensor, FakeNudger, FakeClock) {
        let sensor = FakeSensor()
        let nudger = FakeNudger()
        let clock = FakeClock()
        let monitor = PostureMonitor(
            sensor: sensor,
            nudger: nudger,
            settings: settings,
            clock: clock
        )
        return (monitor, sensor, nudger, clock)
    }

    func testItAsksToBeCalibratedBeforeItJudgesAnything() {
        let settings = FakeSettings(baseline: nil)
        let (monitor, sensor, nudger, _) = makeMonitor(settings: settings)
        sensor.nextOutcome = slouched

        XCTAssertEqual(monitor.state, .needsCalibration)

        monitor.sampleNow()

        XCTAssertEqual(monitor.state, .needsCalibration)
        XCTAssertTrue(nudger.nudges.isEmpty, "no baseline means nothing to judge against")
    }

    func testCalibrationStoresTheAveragedPose() {
        let settings = FakeSettings(baseline: nil)
        let (monitor, sensor, _, _) = makeMonitor(settings: settings)
        sensor.nextOutcome = goodPosture

        monitor.beginCalibration()
        XCTAssertEqual(monitor.state, .calibrating(collected: 0, needed: 10))

        for _ in 0..<10 {
            monitor.sampleNow()
        }

        XCTAssertEqual(monitor.state, .upright)
        XCTAssertEqual(settings.baseline?.uprightness ?? .nan, 1.0, accuracy: 0.0001)
        XCTAssertEqual(settings.baseline?.proximity ?? .nan, 0.3, accuracy: 0.0001)
    }

    func testFramesVisionCannotReadDoNotShortenCalibration() {
        let settings = FakeSettings(baseline: nil)
        let (monitor, sensor, _, _) = makeMonitor(settings: settings)

        monitor.beginCalibration()
        sensor.nextOutcome = .noPersonVisible
        for _ in 0..<10 {
            monitor.sampleNow()
        }

        XCTAssertEqual(monitor.state, .calibrating(collected: 0, needed: 10))
        XCTAssertNil(settings.baseline, "a dark room must not produce a baseline")
    }

    func testItNudgesOnceTheSlouchOutlastsPatience() {
        let settings = FakeSettings(baseline: .upright)
        let (monitor, sensor, nudger, clock) = makeMonitor(settings: settings)
        sensor.nextOutcome = slouched

        monitor.sampleNow()
        clock.advance(seconds: 130)
        monitor.sampleNow()

        XCTAssertEqual(nudger.nudges, [130])
    }

    func testPausingStopsLookingEntirely() {
        let settings = FakeSettings(baseline: .upright)
        let (monitor, sensor, nudger, clock) = makeMonitor(settings: settings)
        sensor.nextOutcome = slouched

        monitor.setPaused(true)
        clock.advance(seconds: 600)
        monitor.sampleNow()

        XCTAssertEqual(monitor.state, .paused)
        XCTAssertEqual(sensor.sampleCount, 0, "a paused app must not open the camera")
        XCTAssertTrue(nudger.nudges.isEmpty)
    }

    func testResumingReturnsToWatching() {
        let settings = FakeSettings(baseline: .upright)
        let (monitor, sensor, _, _) = makeMonitor(settings: settings)
        sensor.nextOutcome = goodPosture

        monitor.setPaused(true)
        monitor.setPaused(false)
        monitor.sampleNow()

        XCTAssertEqual(monitor.state, .upright)
        XCTAssertEqual(sensor.sampleCount, 1)
    }

    func testStateChangesAreAnnouncedOnlyWhenTheyChange() {
        let settings = FakeSettings(baseline: .upright)
        let (monitor, sensor, _, _) = makeMonitor(settings: settings)

        // A calibrated app starts upright, so start from somewhere else to see
        // both the change and the silence that should follow it.
        var announced: [PostureState] = []
        monitor.onStateChange = { announced.append($0) }

        sensor.nextOutcome = .noPersonVisible
        monitor.sampleNow()
        monitor.sampleNow()

        sensor.nextOutcome = goodPosture
        monitor.sampleNow()
        monitor.sampleNow()

        XCTAssertEqual(
            announced,
            [.cannotSee, .upright],
            "the menu must redraw on a change and stay quiet otherwise"
        )
    }

    func testSittingUpWithdrawsTheNudge() {
        let settings = FakeSettings(baseline: .upright)
        let (monitor, sensor, nudger, clock) = makeMonitor(settings: settings)

        sensor.nextOutcome = slouched
        monitor.sampleNow()
        clock.advance(seconds: 130)
        monitor.sampleNow()
        XCTAssertEqual(nudger.nudges, [130])
        XCTAssertEqual(nudger.clearCount, 0)

        sensor.nextOutcome = goodPosture
        monitor.sampleNow()

        XCTAssertEqual(nudger.clearCount, 1)
    }

    func testSteppingAwayLeavesTheNudgeStanding() {
        let settings = FakeSettings(baseline: .upright)
        let (monitor, sensor, nudger, clock) = makeMonitor(settings: settings)

        sensor.nextOutcome = slouched
        monitor.sampleNow()
        clock.advance(seconds: 130)
        monitor.sampleNow()

        sensor.nextOutcome = .noPersonVisible
        monitor.sampleNow()

        XCTAssertEqual(
            nudger.clearCount, 0,
            "losing sight of the user is not the end of the slouch"
        )
    }

    func testPausingWithdrawsTheNudge() {
        let settings = FakeSettings(baseline: .upright)
        let (monitor, sensor, nudger, clock) = makeMonitor(settings: settings)

        sensor.nextOutcome = slouched
        monitor.sampleNow()
        clock.advance(seconds: 130)
        monitor.sampleNow()

        monitor.setPaused(true)

        XCTAssertEqual(nudger.clearCount, 1, "a paused app has no opinion to display")
    }

    func testCalibratingClearsAnActiveSlouch() {
        let settings = FakeSettings(baseline: .upright)
        let (monitor, sensor, nudger, clock) = makeMonitor(settings: settings)
        sensor.nextOutcome = slouched

        monitor.sampleNow()
        clock.advance(seconds: 100)

        // Recalibrating to the current pose must not immediately nudge for it.
        monitor.beginCalibration()
        for _ in 0..<10 {
            monitor.sampleNow()
        }
        monitor.sampleNow()

        XCTAssertTrue(nudger.nudges.isEmpty)
    }
}
