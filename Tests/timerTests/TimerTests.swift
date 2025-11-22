import XCTest
@testable import TimerCore

final class TimerTests: XCTestCase {
    func testTimerIsRunningWhenStartedButNotStopped() {
        let timer = Timer(startTime: Date(), stopTime: nil, tags: [])
        XCTAssertTrue(timer.isRunning)
    }

    func testTimerIsNotRunningWhenStopped() {
        let timer = Timer(startTime: Date(), stopTime: Date(), tags: [])
        XCTAssertFalse(timer.isRunning)
    }

    func testTimerIsNotRunningWhenNotStarted() {
        let timer = Timer(startTime: nil, stopTime: nil, tags: [])
        XCTAssertFalse(timer.isRunning)
    }

    func testTimerDurationIsNilWhenNotStarted() {
        let timer = Timer(startTime: nil, stopTime: nil, tags: [])
        XCTAssertNil(timer.duration)
    }

    func testTimerDurationIsCalculatedCorrectly() {
        let start = Date()
        let stop = start.addingTimeInterval(100) // 100 seconds later
        let timer = Timer(startTime: start, stopTime: stop, tags: [])

        XCTAssertNotNil(timer.duration)
        XCTAssertEqual(timer.duration!, 100, accuracy: 0.01)
    }

    func testTimerDurationUsesCurrentTimeWhenRunning() {
        let start = Date().addingTimeInterval(-50) // Started 50 seconds ago
        let timer = Timer(startTime: start, stopTime: nil, tags: [])

        XCTAssertNotNil(timer.duration)
        XCTAssertGreaterThan(timer.duration!, 49)
        XCTAssertLessThan(timer.duration!, 51)
    }

    func testTimerInitializesWithEmptyCustomProperties() {
        let timer = Timer(startTime: nil, stopTime: nil, tags: [])
        XCTAssertTrue(timer.customProperties.isEmpty)
    }

    func testTimerCanHaveTags() {
        let timer = Timer(startTime: nil, stopTime: nil, tags: ["work", "project"])
        XCTAssertEqual(timer.tags.count, 2)
        XCTAssertTrue(timer.tags.contains("work"))
        XCTAssertTrue(timer.tags.contains("project"))
    }
}
