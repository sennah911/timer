import Foundation

/// Manages timer operations including loading, saving, and manipulating timer files.
///
/// `TimerManager` is responsible for:
/// - Reading and writing timer Markdown files with YAML frontmatter
/// - Parsing and generating Markdown format
/// - Managing timer directory and file operations
/// - Handling configuration settings
///
/// ## Example Usage
/// ```swift
/// let manager = TimerManager()
///
/// // Create and save a timer
/// var timer = Timer(startTime: Date(), stopTime: nil, tags: ["work"])
/// try manager.saveTimer(name: "project-work", timer: timer)
///
/// // Load and stop the timer
/// if var loadedTimer = manager.loadTimer(name: "project-work") {
///     loadedTimer.stopTime = Date()
///     try manager.saveTimer(name: "project-work", timer: loadedTimer)
/// }
/// ```
class TimerManager {
    /// The directory where timer Markdown files are stored.
    let timersDirectory: URL

    /// The configuration loaded from `~/.timer/config.json`.
    let config: TimerConfig

    private let defaultCustomPropertyLines: [String]
    private let defaultPlaceholderNotes: String?

    /// Initializes a timer manager with an optional directory override.
    ///
    /// The manager will:
    /// 1. Load configuration from `~/.timer/config.json` if it exists
    /// 2. Use the directory override if provided, otherwise use the config directory
    /// 3. Fall back to `~/.timer` if no directory is specified
    /// 4. Create the timers directory if it doesn't exist
    ///
    /// - Parameter directoryOverride: An optional directory URL to use instead of the configured directory.
    init(directoryOverride: URL? = nil) {
        let fileManager = FileManager.default
        let homeDirectory = fileManager.homeDirectoryForCurrentUser

        let loadedConfig = TimerConfig.load(fileManager: fileManager) ?? TimerConfig()
        config = loadedConfig
        defaultCustomPropertyLines = loadedConfig.customPropertyLines()
        defaultPlaceholderNotes = loadedConfig.placeholderNotes

        let configDirectory = loadedConfig
            .resolvedTimersDirectory(fileManager: fileManager)
        let resolvedDirectory = directoryOverride ?? configDirectory ?? homeDirectory.appendingPathComponent(".timer")
        timersDirectory = resolvedDirectory.standardizedFileURL

        // Create timers directory if it doesn't exist
        try? fileManager.createDirectory(at: timersDirectory, withIntermediateDirectories: true)
    }

    /// Returns the default custom property lines from the configuration.
    ///
    /// - Returns: An array of custom property lines to include in new timer files.
    func templateCustomProperties() -> [String] {
        return defaultCustomPropertyLines
    }

    /// Returns the placeholder notes template from the configuration.
    ///
    /// - Returns: The placeholder notes string, or `nil` if not configured.
    func templatePlaceholderNotes() -> String? {
        return defaultPlaceholderNotes
    }

    /// Returns the file path URL for a timer with the given name.
    ///
    /// - Parameter name: The name of the timer (without `.md` extension).
    /// - Returns: The full file URL for the timer's Markdown file.
    func timerPath(name: String) -> URL {
        return timersDirectory.appendingPathComponent("\(name).md")
    }

    /// Loads a timer from disk by name.
    ///
    /// Reads the Markdown file and parses it into a `Timer` object.
    ///
    /// - Parameter name: The name of the timer to load.
    /// - Returns: The parsed `Timer` object, or `nil` if the file doesn't exist or can't be parsed.
    func loadTimer(name: String) -> Timer? {
        let path = timerPath(name: name)
        guard let content = try? String(contentsOf: path, encoding: .utf8) else {
            return nil
        }

        return parseMarkdown(content)
    }

    /// Saves a timer to disk as a Markdown file.
    ///
    /// If the file already exists, preserves the existing notes section.
    /// If the file is new, uses the provided `defaultNotes` or the configured placeholder.
    ///
    /// - Parameters:
    ///   - name: The name for the timer file (without `.md` extension).
    ///   - timer: The timer object to save.
    ///   - defaultNotes: Optional notes to use for new files. Defaults to `nil`.
    /// - Throws: `TimerManagerError` or file system errors if saving fails.
    func saveTimer(name: String, timer: Timer, defaultNotes: String? = nil) throws {
        let path = timerPath(name: name)
        let fileExists = FileManager.default.fileExists(atPath: path.path)
        var existingNotes: String?

        if fileExists,
           let currentContent = try? String(contentsOf: path, encoding: .utf8) {
            existingNotes = TimerManager.extractNotes(from: currentContent)
        }

        let notesToPersist = fileExists ? existingNotes : defaultNotes
        let markdown = generateMarkdown(timer: timer, name: name, notes: notesToPersist)
        try markdown.write(to: path, atomically: true, encoding: .utf8)
    }

    /// Parses a Markdown file content string into a `Timer` object.
    ///
    /// Expects content in the format:
    /// ```
    /// ---
    /// start_time: 2025-11-16T10:30:00
    /// end_time: null
    /// tags:
    ///   - work
    ///   - project
    /// custom_property: value
    /// ---
    ///
    /// Notes content here...
    /// ```
    ///
    /// - Parameter content: The Markdown file content with YAML frontmatter.
    /// - Returns: A `Timer` object parsed from the frontmatter.
    func parseMarkdown(_ content: String) -> Timer {
        var timer = Timer(startTime: nil, stopTime: nil, tags: [])

        let lines = content.components(separatedBy: .newlines)

        var index = 1

        while index < lines.count {
            let rawLine = lines[index]
            let trimmedLine = rawLine.trimmingCharacters(in: .whitespaces)

            if trimmedLine == "---" {
                break
            }

            if trimmedLine.hasPrefix("start_time:") {
                let value = trimmedLine.dropFirst("start_time:".count).trimmingCharacters(in: .whitespaces)
                if !value.isEmpty && value.lowercased() != "null" {
                    timer.startTime = parseDate(value)
                } else {
                    timer.startTime = nil
                }
            } else if trimmedLine.hasPrefix("end_time:") {
                let value = trimmedLine.dropFirst("end_time:".count).trimmingCharacters(in: .whitespaces)
                if !value.isEmpty && value.lowercased() != "null" {
                    timer.stopTime = parseDate(value)
                } else {
                    timer.stopTime = nil
                }
            } else if trimmedLine.hasPrefix("tags:") {
                let remainder = trimmedLine.dropFirst("tags:".count).trimmingCharacters(in: .whitespaces)
                var parsedTags: [String] = []

                if remainder == "[]" {
                    parsedTags = []
                } else if !remainder.isEmpty {
                    parsedTags = remainder
                        .split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                } else {
                    index += 1
                    while index < lines.count {
                        let tagLine = lines[index]
                        let trimmedTagLine = tagLine.trimmingCharacters(in: .whitespaces)

                        if trimmedTagLine == "---" {
                            index -= 1
                            break
                        }

                        if trimmedTagLine.hasPrefix("- ") {
                            let tagValue = trimmedTagLine.dropFirst(2).trimmingCharacters(in: .whitespaces)
                            if !tagValue.isEmpty {
                                parsedTags.append(tagValue)
                            }
                            index += 1
                            continue
                        }

                        if trimmedTagLine.isEmpty {
                            index += 1
                            continue
                        }

                        index -= 1
                        break
                    }
                }

                timer.tags = parsedTags
            } else {
                timer.customProperties.append(rawLine)
            }

            index += 1
        }

        return timer
    }

    /// Generates Markdown file content from a `Timer` object.
    ///
    /// Creates content with YAML frontmatter containing timer metadata,
    /// followed by optional notes.
    ///
    /// - Parameters:
    ///   - timer: The timer object to convert to Markdown.
    ///   - name: The name of the timer (currently unused in output).
    ///   - notes: Optional notes to append after the frontmatter.
    /// - Returns: The complete Markdown file content as a string.
    func generateMarkdown(timer: Timer, name: String, notes: String?) -> String {
        var lines: [String] = ["---"]

        if let start = timer.startTime {
            lines.append("start_time: \(formatDate(start))")
        } else {
            lines.append("start_time: null")
        }

        if let stop = timer.stopTime {
            lines.append("end_time: \(formatDate(stop))")
        } else {
            lines.append("end_time: null")
        }

        if timer.tags.isEmpty {
            lines.append("tags: []")
        } else {
            lines.append("tags:")
            for tag in timer.tags {
                lines.append("  - \(tag)")
            }
        }

        if !timer.customProperties.isEmpty {
            for propertyLine in timer.customProperties {
                lines.append(propertyLine)
            }
        }

        lines.append("---")
        lines.append("")

        var result = lines.joined(separator: "\n")
        if let notes = notes, !notes.isEmpty {
            result.append(notes)
        }
        if !result.hasSuffix("\n") {
            result.append("\n")
        }
        return result
    }

    /// Parses a date string into a `Date` object.
    ///
    /// Supports multiple ISO 8601 formats:
    /// - With fractional seconds: `2025-11-16T10:30:00.123Z`
    /// - Without fractional seconds: `2025-11-16T10:30:00Z`
    /// - Local time format: `2025-11-16T10:30:00`
    ///
    /// - Parameter string: The date string to parse.
    /// - Returns: A `Date` object if parsing succeeds, otherwise `nil`.
    func parseDate(_ string: String) -> Date? {
        let isoWithFraction = ISO8601DateFormatter()
        isoWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoWithFraction.date(from: string) {
            return date
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: string) {
            return date
        }

        let simple = DateFormatter()
        simple.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        simple.timeZone = .current
        return simple.date(from: string)
    }

    /// Formats a `Date` object as a string for storage.
    ///
    /// Uses the format `yyyy-MM-dd'T'HH:mm:ss` in the current timezone.
    ///
    /// - Parameter date: The date to format.
    /// - Returns: The formatted date string (e.g., `2025-11-16T10:30:00`).
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    /// Formats a time interval as a human-readable duration string.
    ///
    /// Automatically selects the appropriate format:
    /// - Hours, minutes, seconds: `1h 30m 45s`
    /// - Minutes and seconds only: `30m 45s`
    /// - Seconds only: `45s`
    ///
    /// - Parameter duration: The time interval in seconds.
    /// - Returns: A formatted duration string.
    func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }

    /// Lists all timer names in the timers directory.
    ///
    /// Scans for `.md` files in the timers directory and returns their names
    /// (without the `.md` extension) in sorted order.
    ///
    /// - Returns: An array of timer names, sorted alphabetically.
    func listTimers() -> [String] {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: timersDirectory, includingPropertiesForKeys: nil) else {
            return []
        }

        return files
            .filter { $0.pathExtension == "md" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }

    /// Finds the first running timer.
    ///
    /// Iterates through all timers and returns the name of the first one
    /// that is currently running (has `startTime` but no `stopTime`).
    ///
    /// - Returns: The name of the first running timer, or `nil` if no timers are running.
    func firstRunningTimerName() -> String? {
        for name in listTimers() {
            if let timer = loadTimer(name: name), timer.isRunning {
                return name
            }
        }
        return nil
    }

    /// Generates the next sequential split name for a timer.
    ///
    /// Creates a new name by adding or incrementing a numeric suffix.
    /// For example:
    /// - `"work"` → `"work-1"`
    /// - `"work-1"` → `"work-2"`
    /// - `"project-meeting-3"` → `"project-meeting-4"`
    ///
    /// - Parameter currentName: The name of the timer being split.
    /// - Returns: The next available split name.
    func nextSplitName(from currentName: String) -> String {
        let base = TimerManager.baseNameForSplit(currentName)
        var maxSuffix = 0

        for name in listTimers() {
            if name == base {
                maxSuffix = max(maxSuffix, 0)
                continue
            }

            if let suffix = TimerManager.numericSuffix(in: name, base: base) {
                maxSuffix = max(maxSuffix, suffix)
            }
        }

        return "\(base)-\(maxSuffix + 1)"
    }

    private static func baseNameForSplit(_ name: String) -> String {
        var base = name
        let pattern = "-[0-9]+$"

        while let range = base.range(of: pattern, options: .regularExpression) {
            let candidate = String(base[..<range.lowerBound])
            if candidate.isEmpty {
                break
            }
            base = candidate
        }

        return base.isEmpty ? name : base
    }

    private static func numericSuffix(in name: String, base: String) -> Int? {
        guard name.hasPrefix(base + "-") else {
            return nil
        }
        let suffix = name.dropFirst(base.count + 1)
        guard !suffix.isEmpty else {
            return nil
        }
        return Int(suffix)
    }

    private static func extractNotes(from content: String) -> String? {
        guard content.hasPrefix("---") else { return nil }

        if let closingRange = content.range(of: "\n---\n") {
            let notesStart = closingRange.upperBound
            let notes = content[notesStart...]
            return notes.isEmpty ? nil : String(notes)
        }

        if let closingRange = content.range(of: "\n---", options: .backwards) {
            let after = closingRange.upperBound
            if after >= content.endIndex { return nil }
            let notes = content[after...]
            return notes.isEmpty ? nil : String(notes)
        }

        return nil
    }

    /// Archives a timer file by moving it to the `archived/` subdirectory.
    ///
    /// The timer file is moved to `{timersDirectory}/archived/{name}-{uuid}.md`
    /// where the UUID ensures the filename is unique.
    ///
    /// - Parameter name: The name of the timer to archive.
    /// - Returns: The URL of the archived file.
    /// - Throws: `TimerManagerError.timerNotFound` if the timer doesn't exist.
    func archiveTimerFile(name: String) throws -> URL {
        let fileManager = FileManager.default
        let sourceURL = timerPath(name: name)
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw TimerManagerError.timerNotFound(name)
        }
        let archiveDirectory = timersDirectory.appendingPathComponent("archived", isDirectory: true)
        try fileManager.createDirectory(at: archiveDirectory, withIntermediateDirectories: true)
        let uuidSuffix = UUID().uuidString.lowercased()
        let archivedName = "\(name)-\(uuidSuffix)"
        let destinationURL = archiveDirectory.appendingPathComponent("\(archivedName).md")
        try fileManager.moveItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }

    /// Renames a timer file.
    ///
    /// The timer file is renamed from `{oldName}.md` to `{newName}.md`.
    /// If the source and destination are the same (case-insensitive on some filesystems),
    /// the operation succeeds without error.
    ///
    /// - Parameters:
    ///   - oldName: The current name of the timer.
    ///   - newName: The new name for the timer.
    /// - Returns: The URL of the renamed file.
    /// - Throws:
    ///   - `TimerManagerError.timerNotFound` if the source timer doesn't exist.
    ///   - `TimerManagerError.timerAlreadyExists` if a different timer with the new name already exists.
    ///   - `TimerManagerError.invalidName` if the new name is empty or whitespace-only.
    func renameTimerFile(from oldName: String, to newName: String) throws -> URL {
        let trimmedNewName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNewName.isEmpty else {
            throw TimerManagerError.invalidName(newName)
        }

        let fileManager = FileManager.default
        let sourceURL = timerPath(name: oldName)
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw TimerManagerError.timerNotFound(oldName)
        }

        let destinationURL = timerPath(name: trimmedNewName)
        if fileManager.fileExists(atPath: destinationURL.path) {
            if sourceURL.standardizedFileURL == destinationURL.standardizedFileURL {
                return destinationURL
            }
            throw TimerManagerError.timerAlreadyExists(trimmedNewName)
        }

        try fileManager.moveItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }
}
