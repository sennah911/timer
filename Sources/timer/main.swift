import Foundation

// MARK: - Models

struct Timer: Codable {
    var startTime: Date?
    var stopTime: Date?
    var tags: [String]
    
    var isRunning: Bool {
        return startTime != nil && stopTime == nil
    }
    
    var duration: TimeInterval? {
        guard let start = startTime else { return nil }
        let end = stopTime ?? Date()
        return end.timeIntervalSince(start)
    }
}

// MARK: - Timer Manager

class TimerManager {
    let timersDirectory: URL
    
    init() {
        let fileManager = FileManager.default
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        timersDirectory = homeDirectory.appendingPathComponent(".timers")
        
        // Create timers directory if it doesn't exist
        try? fileManager.createDirectory(at: timersDirectory, withIntermediateDirectories: true)
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
    
    func saveTimer(name: String, timer: Timer) throws {
        let markdown = generateMarkdown(timer: timer, name: name)
        let path = timerPath(name: name)
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
            }
            
            index += 1
        }
        
        return timer
    }
    
    func generateMarkdown(timer: Timer, name: String) -> String {
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
        
        lines.append("---")
        lines.append("")
        
        return lines.joined(separator: "\n")
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
        simple.timeZone = TimeZone(secondsFromGMT: 0)
        return simple.date(from: string)
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
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
    
    var timer = Timer(startTime: nil, stopTime: nil, tags: [])
    timer.startTime = Date()
    timer.stopTime = nil
    
    do {
        try manager.saveTimer(name: name, timer: timer)
        print("✅ Started timer '\(name)' at \(manager.formatDate(Date()))")
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
        timer start <name>                    Start a timer
        timer stop <name>                     Stop a running timer
        timer tag <name> <tag>                Add a tag to a timer
        timer remove-tag <name> <tag>         Remove a tag from a timer
        timer set-start <name> <ISO8601>      Set the start time
        timer set-stop <name> <ISO8601>       Set the stop time
        timer show <name>                     Show timer details
        timer list                            List all timers
        timer help                            Show this help message
    
    Examples:
        timer start work
        timer stop work
        timer tag work client-project
        timer remove-tag work client-project
        timer set-start work 2025-11-04T09:00:00Z
        timer set-stop work 2025-11-04T17:00:00Z
    
    Timers are stored as Markdown files in ~/.timers/
    """)
}

// MARK: - Main

let args = CommandLine.arguments
let manager = TimerManager()

guard args.count > 1 else {
    printUsage()
    exit(0)
}

let command = args[1].lowercased()

switch command {
case "start":
    guard args.count >= 3 else {
        print("❌ Usage: timer start <name>")
        exit(1)
    }
    startTimer(name: args[2], manager: manager)
    
case "stop":
    guard args.count >= 3 else {
        print("❌ Usage: timer stop <name>")
        exit(1)
    }
    stopTimer(name: args[2], manager: manager)
    
case "tag":
    guard args.count >= 4 else {
        print("❌ Usage: timer tag <name> <tag>")
        exit(1)
    }
    tagTimer(name: args[2], tag: args[3], manager: manager)
    
case "remove-tag":
    guard args.count >= 4 else {
        print("❌ Usage: timer remove-tag <name> <tag>")
        exit(1)
    }
    removeTag(name: args[2], tag: args[3], manager: manager)
    
case "set-start":
    guard args.count >= 4 else {
        print("❌ Usage: timer set-start <name> <ISO8601-datetime>")
        exit(1)
    }
    setStart(name: args[2], dateString: args[3], manager: manager)
    
case "set-stop":
    guard args.count >= 4 else {
        print("❌ Usage: timer set-stop <name> <ISO8601-datetime>")
        exit(1)
    }
    setStop(name: args[2], dateString: args[3], manager: manager)
    
case "show":
    guard args.count >= 3 else {
        print("❌ Usage: timer show <name>")
        exit(1)
    }
    showTimer(name: args[2], manager: manager)
    
case "list":
    listTimers(manager: manager)
    
case "help", "--help", "-h":
    printUsage()
    
default:
    print("❌ Unknown command: \(command)")
    printUsage()
    exit(1)
}
