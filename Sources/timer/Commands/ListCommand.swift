import Foundation

/// Lists all timers with their status and duration.
///
/// Displays a formatted table showing each timer's:
/// - Name
/// - Status (Running, Stopped, or Not started)
/// - Duration
///
/// - Parameter manager: The timer manager to use.
public func listTimers(manager: TimerManager) {
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
