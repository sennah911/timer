import Foundation

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
