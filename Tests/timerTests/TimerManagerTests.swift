import XCTest
@testable import timer

final class TimerManagerTests: XCTestCase {
    var tempDirectory: URL!
    var manager: TimerManager!

    override func setUp() {
        super.setUp()
        // Create a temporary directory for testing
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TimerTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        manager = TimerManager(directoryOverride: tempDirectory)
    }

    override func tearDown() {
        super.tearDown()
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    // MARK: - Date Formatting Tests

    func testFormatDate() {
        let dateString = "2025-11-16T10:30:00"
        let date = manager.parseDate(dateString)
        XCTAssertNotNil(date)

        let formatted = manager.formatDate(date!)
        XCTAssertEqual(formatted, dateString)
    }

    func testParseDateWithFractionalSeconds() {
        let dateString = "2025-11-16T10:30:00.123Z"
        let date = manager.parseDate(dateString)
        XCTAssertNotNil(date)
    }

    func testParseDateWithoutFractionalSeconds() {
        let dateString = "2025-11-16T10:30:00Z"
        let date = manager.parseDate(dateString)
        XCTAssertNotNil(date)
    }

    func testParseDateWithLocalFormat() {
        let dateString = "2025-11-16T10:30:00"
        let date = manager.parseDate(dateString)
        XCTAssertNotNil(date)
    }

    // MARK: - Duration Formatting Tests

    func testFormatDurationWithHours() {
        let duration: TimeInterval = 3661 // 1h 1m 1s
        let formatted = manager.formatDuration(duration)
        XCTAssertEqual(formatted, "1h 1m 1s")
    }

    func testFormatDurationWithMinutes() {
        let duration: TimeInterval = 125 // 2m 5s
        let formatted = manager.formatDuration(duration)
        XCTAssertEqual(formatted, "2m 5s")
    }

    func testFormatDurationWithSeconds() {
        let duration: TimeInterval = 45
        let formatted = manager.formatDuration(duration)
        XCTAssertEqual(formatted, "45s")
    }

    // MARK: - Timer Save/Load Tests

    func testSaveAndLoadTimer() throws {
        let timer = Timer(startTime: Date(), stopTime: nil, tags: ["test"])
        try manager.saveTimer(name: "test-timer", timer: timer)

        let loaded = manager.loadTimer(name: "test-timer")
        XCTAssertNotNil(loaded)
        XCTAssertNotNil(loaded?.startTime)
        XCTAssertNil(loaded?.stopTime)
        XCTAssertEqual(loaded?.tags, ["test"])
    }

    func testLoadNonexistentTimer() {
        let loaded = manager.loadTimer(name: "nonexistent")
        XCTAssertNil(loaded)
    }

    // MARK: - Markdown Parsing Tests

    func testParseMarkdownWithStartTime() {
        let markdown = """
        ---
        start_time: 2025-11-16T10:30:00
        end_time: null
        tags: []
        ---

        """
        let timer = manager.parseMarkdown(markdown)
        XCTAssertNotNil(timer.startTime)
        XCTAssertNil(timer.stopTime)
        XCTAssertTrue(timer.tags.isEmpty)
    }

    func testParseMarkdownWithTags() {
        let markdown = """
        ---
        start_time: 2025-11-16T10:30:00
        end_time: null
        tags:
          - work
          - project
        ---

        """
        let timer = manager.parseMarkdown(markdown)
        XCTAssertEqual(timer.tags.count, 2)
        XCTAssertTrue(timer.tags.contains("work"))
        XCTAssertTrue(timer.tags.contains("project"))
    }

    func testParseMarkdownWithEmptyTags() {
        let markdown = """
        ---
        start_time: null
        end_time: null
        tags: []
        ---

        """
        let timer = manager.parseMarkdown(markdown)
        XCTAssertTrue(timer.tags.isEmpty)
    }

    // MARK: - List Timers Tests

    func testListTimersEmpty() {
        let timers = manager.listTimers()
        XCTAssertTrue(timers.isEmpty)
    }

    func testListTimers() throws {
        try manager.saveTimer(name: "timer1", timer: Timer(startTime: Date(), stopTime: nil, tags: []))
        try manager.saveTimer(name: "timer2", timer: Timer(startTime: Date(), stopTime: nil, tags: []))

        let timers = manager.listTimers()
        XCTAssertEqual(timers.count, 2)
        XCTAssertTrue(timers.contains("timer1"))
        XCTAssertTrue(timers.contains("timer2"))
    }

    // MARK: - Split Name Tests

    func testNextSplitNameForBaseTimer() {
        let nextName = manager.nextSplitName(from: "work")
        XCTAssertEqual(nextName, "work-1")
    }

    func testNextSplitNameWithExistingTimers() throws {
        try manager.saveTimer(name: "work", timer: Timer(startTime: Date(), stopTime: nil, tags: []))
        try manager.saveTimer(name: "work-1", timer: Timer(startTime: Date(), stopTime: nil, tags: []))

        let nextName = manager.nextSplitName(from: "work")
        XCTAssertEqual(nextName, "work-2")
    }

    func testNextSplitNameWithGaps() throws {
        try manager.saveTimer(name: "work", timer: Timer(startTime: Date(), stopTime: nil, tags: []))
        try manager.saveTimer(name: "work-1", timer: Timer(startTime: Date(), stopTime: nil, tags: []))
        try manager.saveTimer(name: "work-3", timer: Timer(startTime: Date(), stopTime: nil, tags: []))

        let nextName = manager.nextSplitName(from: "work")
        XCTAssertEqual(nextName, "work-4")
    }

    // MARK: - First Running Timer Tests

    func testFirstRunningTimerName() throws {
        try manager.saveTimer(name: "stopped", timer: Timer(startTime: Date(), stopTime: Date(), tags: []))
        try manager.saveTimer(name: "running", timer: Timer(startTime: Date(), stopTime: nil, tags: []))

        let runningName = manager.firstRunningTimerName()
        XCTAssertEqual(runningName, "running")
    }

    func testFirstRunningTimerNameWhenNoneRunning() throws {
        try manager.saveTimer(name: "stopped", timer: Timer(startTime: Date(), stopTime: Date(), tags: []))

        let runningName = manager.firstRunningTimerName()
        XCTAssertNil(runningName)
    }

    // MARK: - Archive Tests

    func testArchiveTimerFile() throws {
        try manager.saveTimer(name: "archive-me", timer: Timer(startTime: Date(), stopTime: nil, tags: []))

        let destination = try manager.archiveTimerFile(name: "archive-me")
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: manager.timerPath(name: "archive-me").path))
    }

    func testArchiveNonexistentTimer() {
        XCTAssertThrowsError(try manager.archiveTimerFile(name: "nonexistent")) { error in
            guard case TimerManagerError.timerNotFound = error else {
                XCTFail("Expected timerNotFound error")
                return
            }
        }
    }

    // MARK: - Rename Tests

    func testRenameTimerFile() throws {
        try manager.saveTimer(name: "old-name", timer: Timer(startTime: Date(), stopTime: nil, tags: []))

        let destination = try manager.renameTimerFile(from: "old-name", to: "new-name")
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: manager.timerPath(name: "old-name").path))

        let loaded = manager.loadTimer(name: "new-name")
        XCTAssertNotNil(loaded)
    }

    func testRenameNonexistentTimer() {
        XCTAssertThrowsError(try manager.renameTimerFile(from: "nonexistent", to: "new-name")) { error in
            guard case TimerManagerError.timerNotFound = error else {
                XCTFail("Expected timerNotFound error")
                return
            }
        }
    }

    func testRenameToExistingName() throws {
        try manager.saveTimer(name: "timer1", timer: Timer(startTime: Date(), stopTime: nil, tags: []))
        try manager.saveTimer(name: "timer2", timer: Timer(startTime: Date(), stopTime: nil, tags: []))

        XCTAssertThrowsError(try manager.renameTimerFile(from: "timer1", to: "timer2")) { error in
            guard case TimerManagerError.timerAlreadyExists = error else {
                XCTFail("Expected timerAlreadyExists error")
                return
            }
        }
    }

    func testRenameWithEmptyName() throws {
        try manager.saveTimer(name: "test", timer: Timer(startTime: Date(), stopTime: nil, tags: []))

        XCTAssertThrowsError(try manager.renameTimerFile(from: "test", to: "   ")) { error in
            guard case TimerManagerError.invalidName = error else {
                XCTFail("Expected invalidName error")
                return
            }
        }
    }
}
