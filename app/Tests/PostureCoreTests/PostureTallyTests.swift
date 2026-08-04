import XCTest
@testable import PostureCore

final class PostureTallyTests: XCTestCase {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000)

    private func at(_ seconds: TimeInterval) -> Date {
        start.addingTimeInterval(seconds)
    }

    func testTimeAccruesWhileAStateIsHeld() {
        var tally = PostureTally()
        tally.transition(to: .upright, at: at(0))

        XCTAssertEqual(tally.goodTotal(at: at(90)), 90)
        XCTAssertEqual(tally.badTotal(at: at(90)), 0)
    }

    func testTransitionsSplitTimeBetweenBuckets() {
        var tally = PostureTally()
        tally.transition(to: .upright, at: at(0))
        tally.transition(to: .slouching(since: at(60)), at: at(60))

        XCTAssertEqual(tally.goodTotal(at: at(100)), 60)
        XCTAssertEqual(tally.badTotal(at: at(100)), 40)
    }

    func testNeutralStatesCountNowhere() {
        var tally = PostureTally()
        tally.transition(to: .upright, at: at(0))
        tally.transition(to: .paused, at: at(30))

        XCTAssertEqual(tally.goodTotal(at: at(500)), 30)
        XCTAssertEqual(tally.badTotal(at: at(500)), 0)
    }

    func testResumingKeepsEarlierTime() {
        var tally = PostureTally()
        tally.transition(to: .upright, at: at(0))
        tally.transition(to: .cannotSee, at: at(10))
        tally.transition(to: .upright, at: at(20))

        XCTAssertEqual(tally.goodTotal(at: at(25)), 15)
    }

    func testABackwardsClockAddsNothing() {
        var tally = PostureTally()
        tally.transition(to: .upright, at: at(100))

        XCTAssertEqual(tally.goodTotal(at: at(50)), 0)
    }
}
