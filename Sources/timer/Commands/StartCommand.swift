import Foundation

/// Starts a new timer with the given name.
///
/// Creates a new timer file with the current time as the start time.
/// If a timer with the same name already exists, prints a warning and does nothing.
///
/// - Parameters:
///   - name: The name for the new timer.
///   - manager: The timer manager to use.
///   - silent: If `true`, suppresses all output. Defaults to `false`.
public func startTimer(name: String, manager: TimerManager, silent: Bool = false) {
    if let existingTimer = manager.loadTimer(name: name) {
        if existingTimer.isRunning {
            if !silent {
                print("⚠️  Timer '\(name)' is already running!")
            }
        } else {
            if !silent {
                print("⚠️  Timer '\(name)' already exists. Use 'timer show \(name)' to inspect it or delete the file before starting a new timer with the same name.")
            }
        }
        return
    }

    let now = Date()
    var timer = Timer(startTime: now, stopTime: nil, tags: [])
    timer.customProperties = manager.templateCustomProperties()

    do {
        try manager.saveTimer(name: name, timer: timer, defaultNotes: manager.templatePlaceholderNotes())
        if !silent {
            print("✅ Started timer '\(name)' at \(manager.formatDate(now))")
        }
    } catch {
        if !silent {
            print("❌ Error saving timer: \(error)")
        }
    }
}
