import Foundation

/// A timer that tracks time intervals with optional tags and custom properties.
///
/// Timers are stored as Markdown files with YAML frontmatter containing metadata.
/// A timer can be in one of three states:
/// - Not started: both `startTime` and `stopTime` are `nil`
/// - Running: `startTime` is set but `stopTime` is `nil`
/// - Stopped: both `startTime` and `stopTime` are set
///
/// ## Example Usage
/// ```swift
/// // Create and start a timer
/// var timer = Timer(startTime: Date(), stopTime: nil, tags: ["work"])
///
/// // Check if running
/// if timer.isRunning {
///     print("Timer is running")
/// }
///
/// // Stop the timer
/// timer.stopTime = Date()
/// if let duration = timer.duration {
///     print("Duration: \(duration) seconds")
/// }
/// ```
public struct Timer: Codable {
    /// The time when the timer was started.
    ///
    /// When `nil`, the timer has not been started yet.
    public var startTime: Date?

    /// The time when the timer was stopped.
    ///
    /// When `nil` and `startTime` is set, the timer is currently running.
    public var stopTime: Date?

    /// An array of tags associated with this timer.
    ///
    /// Tags can be used to categorize and filter timers (e.g., "work", "personal", "project-name").
    public var tags: [String]

    /// Custom properties stored as raw strings.
    ///
    /// These are additional metadata lines that appear in the YAML frontmatter
    /// after the standard fields. They can be used for project-specific data.
    public var customProperties: [String] = []

    /// Whether the timer is currently running.
    ///
    /// A timer is considered running when it has a start time but no stop time.
    public var isRunning: Bool {
        return startTime != nil && stopTime == nil
    }

    /// The duration of the timer in seconds.
    ///
    /// - For stopped timers: returns the time between `startTime` and `stopTime`
    /// - For running timers: returns the time between `startTime` and the current time
    /// - For not-started timers: returns `nil`
    ///
    /// - Returns: The duration in seconds, or `nil` if the timer hasn't been started.
    public var duration: TimeInterval? {
        guard let start = startTime else { return nil }
        let end = stopTime ?? Date()
        return end.timeIntervalSince(start)
    }

    public init(startTime: Date? = nil, stopTime: Date? = nil, tags: [String] = [], customProperties: [String] = []) {
        self.startTime = startTime
        self.stopTime = stopTime
        self.tags = tags
        self.customProperties = customProperties
    }
}
