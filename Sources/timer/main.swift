import Foundation

// MARK: - Models

struct Timer: Codable {
    var startTime: Date?
    var stopTime: Date?
    var tags: [String]
    var customProperties: [String] = []
    
    var isRunning: Bool {
        return startTime != nil && stopTime == nil
    }
    
    var duration: TimeInterval? {
        guard let start = startTime else { return nil }
        let end = stopTime ?? Date()
        return end.timeIntervalSince(start)
    }
}

struct TimerConfig: Codable {
    var timersDirectory: String?
    var placeholderNotes: String?
    var customProperties: [String]?
    
    enum CodingKeys: String, CodingKey {
        case timersDirectory
        case placeholderNotes = "placeholder_notes"
        case customProperties = "custom_properties"
    }
    
    init(timersDirectory: String? = nil,
         placeholderNotes: String? = nil,
         customProperties: [String]? = nil) {
        self.timersDirectory = timersDirectory
        self.placeholderNotes = TimerConfig.normalizePlaceholder(placeholderNotes)
        if let customProperties {
            self.customProperties = TimerConfig.normalizeCustomPropertiesArray(customProperties)
        } else {
            self.customProperties = nil
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timersDirectory = try container.decodeIfPresent(String.self, forKey: .timersDirectory)
        let placeholder = try container.decodeIfPresent(String.self, forKey: .placeholderNotes)
        placeholderNotes = TimerConfig.normalizePlaceholder(placeholder)
        
        if let propertiesArray = try container.decodeIfPresent([String].self, forKey: .customProperties) {
            customProperties = TimerConfig.normalizeCustomPropertiesArray(propertiesArray)
        } else if let propertiesString = try container.decodeIfPresent(String.self, forKey: .customProperties) {
            customProperties = TimerConfig.normalizeCustomPropertiesString(propertiesString)
        } else {
            customProperties = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(timersDirectory, forKey: .timersDirectory)
        try container.encodeIfPresent(placeholderNotes, forKey: .placeholderNotes)
        if let customProperties {
            try container.encode(customProperties, forKey: .customProperties)
        }
    }
    
    static func load(fileManager: FileManager = .default) -> TimerConfig? {
        let configDirectory = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".timer")
        let configURL = configDirectory.appendingPathComponent("config.json")
        
        guard fileManager.fileExists(atPath: configURL.path),
              let data = try? Data(contentsOf: configURL) else {
            return nil
        }
        
        let decoder = JSONDecoder()
        return try? decoder.decode(TimerConfig.self, from: data)
    }
    
    func resolvedTimersDirectory(fileManager: FileManager = .default) -> URL? {
        guard let rawPath = timersDirectory?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !rawPath.isEmpty else {
            return nil
        }
        let base = fileManager.homeDirectoryForCurrentUser
        return resolveDirectoryPath(rawPath, relativeTo: base)
    }
    
    func customPropertyLines() -> [String] {
        return customProperties ?? []
    }
    
    private static func normalizePlaceholder(_ value: String?) -> String? {
        guard let value else { return nil }
        let sanitized = value.replacingOccurrences(of: "\r", with: "")
        return sanitized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : sanitized
    }
    
    private static func normalizeCustomPropertiesArray(_ array: [String]) -> [String]? {
        let sanitized = sanitizeCustomPropertyLines(array)
        let hasContent = sanitized.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return hasContent ? sanitized : nil
    }
    
    private static func normalizeCustomPropertiesString(_ string: String) -> [String]? {
        let sanitizedString = string.replacingOccurrences(of: "\r", with: "")
        let lines = sanitizedString.components(separatedBy: .newlines)
        return normalizeCustomPropertiesArray(lines)
    }
    
    private static func sanitizeCustomPropertyLines(_ lines: [String]) -> [String] {
        return lines.map { $0.replacingOccurrences(of: "\r", with: "") }
    }
}

func resolveDirectoryPath(_ path: String, relativeTo base: URL) -> URL {
    let expanded = (path as NSString).expandingTildeInPath
    if expanded.hasPrefix("/") {
        return URL(fileURLWithPath: expanded, isDirectory: true).standardizedFileURL
    } else {
        return URL(fileURLWithPath: expanded, isDirectory: true, relativeTo: base).standardizedFileURL
    }
}

// MARK: - Timer Manager

class TimerManager {
    let timersDirectory: URL
    let config: TimerConfig
    private let defaultCustomPropertyLines: [String]
    private let defaultPlaceholderNotes: String?
    
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
    
    func templateCustomProperties() -> [String] {
        return defaultCustomPropertyLines
    }
    
    func templatePlaceholderNotes() -> String? {
        return defaultPlaceholderNotes
    }
    
    func timerPath(name: String) -> URL {
        return timersDirectory.appendingPathComponent("\(name).md")
    }
    
    func loadTimer(name: String) -> Timer? {
        let path = timerPath(name: name)
        guard let content = try? String(contentsOf: path, encoding: .utf8) else {
            return nil
        }
        
        return parseMarkdown(content)
    }
    
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
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }
    
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
}

// MARK: - Commands

func startTimer(name: String, manager: TimerManager) {
    if let existingTimer = manager.loadTimer(name: name) {
        if existingTimer.isRunning {
            print("⚠️  Timer '\(name)' is already running!")
        } else {
            print("⚠️  Timer '\(name)' already exists. Use 'timer show \(name)' to inspect it or delete the file before starting a new timer with the same name.")
        }
        return
    }
    
    let now = Date()
    var timer = Timer(startTime: now, stopTime: nil, tags: [])
    timer.customProperties = manager.templateCustomProperties()
    
    do {
        try manager.saveTimer(name: name, timer: timer, defaultNotes: manager.templatePlaceholderNotes())
        print("✅ Started timer '\(name)' at \(manager.formatDate(now))")
    } catch {
        print("❌ Error saving timer: \(error)")
    }
}

func stopTimer(name: String, manager: TimerManager) {
    guard var timer = manager.loadTimer(name: name) else {
        print("❌ Timer '\(name)' not found!")
        return
    }
    
    if !timer.isRunning {
        print("⚠️  Timer '\(name)' is not running!")
        return
    }
    
    timer.stopTime = Date()
    
    do {
        try manager.saveTimer(name: name, timer: timer)
        if let duration = timer.duration {
            print("✅ Stopped timer '\(name)' - Duration: \(manager.formatDuration(duration))")
        }
    } catch {
        print("❌ Error saving timer: \(error)")
    }
}

func splitTimer(name: String, newName: String?, manager: TimerManager) {
    guard var timer = manager.loadTimer(name: name) else {
        print("❌ Timer '\(name)' not found!")
        return
    }
    
    if !timer.isRunning {
        print("⚠️  Timer '\(name)' is not running!")
        return
    }
    
    let generatedName: String
    if let supplied = newName?.trimmingCharacters(in: .whitespacesAndNewlines), !supplied.isEmpty {
        generatedName = supplied
    } else {
        generatedName = manager.nextSplitName(from: name)
    }
    
    if manager.loadTimer(name: generatedName) != nil {
        print("⚠️  Timer '\(generatedName)' already exists! Choose a different name or specify one manually.")
        return
    }
    
    let splitDate = Date()
    timer.stopTime = splitDate
    
    do {
        try manager.saveTimer(name: name, timer: timer)
    } catch {
        print("❌ Error saving timer: \(error)")
        return
    }
    
    var newTimer = Timer(startTime: splitDate, stopTime: nil, tags: timer.tags)
    if timer.customProperties.isEmpty {
        newTimer.customProperties = manager.templateCustomProperties()
    } else {
        newTimer.customProperties = timer.customProperties
    }
    
    do {
        try manager.saveTimer(name: generatedName, timer: newTimer, defaultNotes: manager.templatePlaceholderNotes())
        print("✅ Split timer '\(name)' into '\(generatedName)' at \(manager.formatDate(splitDate))")
    } catch {
        print("❌ Error creating timer '\(generatedName)': \(error)")
    }
}

func tagTimer(name: String, tag: String, manager: TimerManager) {
    guard var timer = manager.loadTimer(name: name) else {
        print("❌ Timer '\(name)' not found!")
        return
    }
    
    if !timer.tags.contains(tag) {
        timer.tags.append(tag)
        do {
            try manager.saveTimer(name: name, timer: timer)
            print("✅ Added tag '\(tag)' to timer '\(name)'")
        } catch {
            print("❌ Error saving timer: \(error)")
        }
    } else {
        print("⚠️  Tag '\(tag)' already exists on timer '\(name)'")
    }
}

func removeTag(name: String, tag: String, manager: TimerManager) {
    guard var timer = manager.loadTimer(name: name) else {
        print("❌ Timer '\(name)' not found!")
        return
    }
    
    if let index = timer.tags.firstIndex(of: tag) {
        timer.tags.remove(at: index)
        do {
            try manager.saveTimer(name: name, timer: timer)
            print("✅ Removed tag '\(tag)' from timer '\(name)'")
        } catch {
            print("❌ Error saving timer: \(error)")
        }
    } else {
        print("⚠️  Tag '\(tag)' not found on timer '\(name)'")
    }
}

func setStart(name: String, dateString: String, manager: TimerManager) {
    guard var timer = manager.loadTimer(name: name) else {
        print("❌ Timer '\(name)' not found!")
        return
    }
    
    guard let date = manager.parseDate(dateString) else {
        print("❌ Invalid date format. Use ISO 8601 format (e.g., 2025-11-04T10:30:00Z)")
        return
    }
    
    timer.startTime = date
    
    do {
        try manager.saveTimer(name: name, timer: timer)
        print("✅ Set start time for timer '\(name)' to \(manager.formatDate(date))")
    } catch {
        print("❌ Error saving timer: \(error)")
    }
}

func setStop(name: String, dateString: String, manager: TimerManager) {
    guard var timer = manager.loadTimer(name: name) else {
        print("❌ Timer '\(name)' not found!")
        return
    }
    
    guard let date = manager.parseDate(dateString) else {
        print("❌ Invalid date format. Use ISO 8601 format (e.g., 2025-11-04T10:30:00Z)")
        return
    }
    
    timer.stopTime = date
    
    do {
        try manager.saveTimer(name: name, timer: timer)
        print("✅ Set stop time for timer '\(name)' to \(manager.formatDate(date))")
    } catch {
        print("❌ Error saving timer: \(error)")
    }
}

func showTimer(name: String, manager: TimerManager) {
    guard let timer = manager.loadTimer(name: name) else {
        print("❌ Timer '\(name)' not found!")
        return
    }
    
    print("\n📊 Timer: \(name)")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    if let start = timer.startTime {
        print("Start:    \(manager.formatDate(start))")
    } else {
        print("Start:    Not started")
    }
    
    if let stop = timer.stopTime {
        print("Stop:     \(manager.formatDate(stop))")
    } else if timer.isRunning {
        print("Stop:     Running ⏱️")
    } else {
        print("Stop:     Not started")
    }
    
    if !timer.tags.isEmpty {
        print("Tags:     \(timer.tags.joined(separator: ", "))")
    }
    
    if let duration = timer.duration {
        print("Duration: \(manager.formatDuration(duration))")
    }
    
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
}

func listTimers(manager: TimerManager) {
    let timers = manager.listTimers()
    
    if timers.isEmpty {
        print("No timers found. Create one with 'timer start <name>'")
        return
    }
    
    print("\n📋 Available Timers:")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    for name in timers {
        if let timer = manager.loadTimer(name: name) {
            let status = timer.isRunning ? "⏱️  Running" : (timer.startTime != nil ? "⏹️  Stopped" : "○  Not started")
            let durationStr = timer.duration.map { manager.formatDuration($0) } ?? "—"
            let paddedName = name.padding(toLength: max(name.count, 20), withPad: " ", startingAt: 0)
            print("\(paddedName) \(status)  (\(durationStr))")
        }
    }
    
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
}

func printUsage() {
    print("""
    Timer - A command-line timer tool
    
    Usage:
        timer [--directory <path>] start <name>               Start a timer
        timer [--directory <path>] stop <name>                Stop a running timer
        timer [--directory <path>] split <name> [new_name]    Stop one timer and start another
        timer [--directory <path>] tag <name> <tag>           Add a tag to a timer
        timer [--directory <path>] remove-tag <name> <tag>    Remove a tag from a timer
        timer [--directory <path>] set-start <name> <ISO8601> Set the start time
        timer [--directory <path>] set-stop <name> <ISO8601>  Set the stop time
        timer [--directory <path>] show <name>                Show timer details
        timer [--directory <path>] list                       List all timers
        timer help                                            Show this help message
    
    Global options:
        -d, --directory <path>            Override the timers directory for this command
    
    Config:
        Default directory is ~/.timer unless overridden in ~/.timer/config.json
        Supported keys:
            "timersDirectory"     Override the timers directory
            "custom_properties"   Array or newline string inserted after tags
            "placeholder_notes"   Notes appended after metadata for new timers
        Example config:
        {
            "timersDirectory": "/path/to/timers",
            "custom_properties": ["project: Client", "billable: true"],
            "placeholder_notes": "## Notes\\n- Fill in details"
        }
    
    Examples:
        timer start work
        timer stop work
        timer split work
        timer tag work client-project
        timer remove-tag work client-project
        timer set-start work 2025-11-04T09:00:00Z
        timer set-stop work 2025-11-04T17:00:00Z
    
    Timers are stored as Markdown files in ~/.timer/
    """)
}

// MARK: - Main

let rawArgs = CommandLine.arguments
var arguments = Array(rawArgs.dropFirst())

let workingDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
var directoryOverride: URL?
var cleanedArguments: [String] = []

var index = 0
while index < arguments.count {
    let argument = arguments[index]
    if argument == "--directory" || argument == "-d" {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            print("❌ --directory requires a path argument")
            exit(1)
        }
        
        let path = arguments[valueIndex]
        directoryOverride = resolveDirectoryPath(path, relativeTo: workingDirectory)
        index += 2
        continue
    }
    
    cleanedArguments.append(argument)
    index += 1
}

guard let commandRaw = cleanedArguments.first else {
    printUsage()
    exit(0)
}

let command = commandRaw.lowercased()
var remainingArguments = Array(cleanedArguments.dropFirst())

let manager = TimerManager(directoryOverride: directoryOverride)

switch command {
case "start":
    guard let name = remainingArguments.first else {
        print("❌ Usage: timer [--directory <path>] start <name>")
        exit(1)
    }
    startTimer(name: name, manager: manager)
    
case "stop":
    guard let name = remainingArguments.first else {
        print("❌ Usage: timer [--directory <path>] stop <name>")
        exit(1)
    }
    stopTimer(name: name, manager: manager)
    
case "split":
    guard let name = remainingArguments.first else {
        print("❌ Usage: timer [--directory <path>] split <name> [new_name]")
        exit(1)
    }
    if remainingArguments.count > 2 {
        print("❌ Usage: timer [--directory <path>] split <name> [new_name]")
        exit(1)
    }
    let newName = remainingArguments.count == 2 ? remainingArguments[1] : nil
    splitTimer(name: name, newName: newName, manager: manager)
    
case "tag":
    guard remainingArguments.count >= 2 else {
        print("❌ Usage: timer [--directory <path>] tag <name> <tag>")
        exit(1)
    }
    tagTimer(name: remainingArguments[0], tag: remainingArguments[1], manager: manager)
    
case "remove-tag":
    guard remainingArguments.count >= 2 else {
        print("❌ Usage: timer [--directory <path>] remove-tag <name> <tag>")
        exit(1)
    }
    removeTag(name: remainingArguments[0], tag: remainingArguments[1], manager: manager)
    
case "set-start":
    guard remainingArguments.count >= 2 else {
        print("❌ Usage: timer [--directory <path>] set-start <name> <ISO8601-datetime>")
        exit(1)
    }
    setStart(name: remainingArguments[0], dateString: remainingArguments[1], manager: manager)
    
case "set-stop":
    guard remainingArguments.count >= 2 else {
        print("❌ Usage: timer [--directory <path>] set-stop <name> <ISO8601-datetime>")
        exit(1)
    }
    setStop(name: remainingArguments[0], dateString: remainingArguments[1], manager: manager)
    
case "show":
    guard let name = remainingArguments.first else {
        print("❌ Usage: timer [--directory <path>] show <name>")
        exit(1)
    }
    showTimer(name: name, manager: manager)
    
case "list":
    listTimers(manager: manager)
    
case "help", "--help", "-h":
    printUsage()
    
default:
    print("❌ Unknown command: \(command)")
    printUsage()
    exit(1)
}
