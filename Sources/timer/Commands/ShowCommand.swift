import Foundation

/// Displays detailed information about a timer.
///
/// Prints a formatted display showing the timer's:
/// - Start time
/// - Stop time (or "Running" if still active)
/// - Tags
/// - Duration
///
/// - Parameters:
///   - name: The name of the timer to display.
///   - manager: The timer manager to use.
public func showTimer(name: String, manager: TimerManager) {
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
