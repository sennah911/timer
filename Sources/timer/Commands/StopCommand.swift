import Foundation

/// Stops a running timer.
///
/// Sets the timer's stop time to the current time and saves it.
/// If the timer doesn't exist or is not running, prints a warning.
///
/// - Parameters:
///   - name: The name of the timer to stop.
///   - manager: The timer manager to use.
///   - silent: If `true`, suppresses all output. Defaults to `false`.
public func stopTimer(name: String, manager: TimerManager, silent: Bool = false) {
    guard var timer = manager.loadTimer(name: name) else {
        if !silent {
            print("❌ Timer '\(name)' not found!")
        }
        return
    }

    if !timer.isRunning {
        if !silent {
            print("⚠️  Timer '\(name)' is not running!")
        }
        return
    }

    timer.stopTime = Date()

    do {
        try manager.saveTimer(name: name, timer: timer)
        if let duration = timer.duration {
            if !silent {
                print("✅ Stopped timer '\(name)' - Duration: \(manager.formatDuration(duration))")
            }
        }
    } catch {
        if !silent {
            print("❌ Error saving timer: \(error)")
        }
    }
}
