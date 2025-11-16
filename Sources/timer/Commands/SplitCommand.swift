import Foundation

/// Splits a running timer into two timers.
///
/// Stops the current timer and immediately starts a new timer.
/// The new timer inherits the tags and custom properties from the original.
/// If no new name is provided, generates one automatically (e.g., "work" → "work-1").
///
/// - Parameters:
///   - name: The name of the timer to split.
///   - newName: Optional name for the new timer. If `nil`, generates automatically.
///   - manager: The timer manager to use.
///   - silent: If `true`, suppresses all output. Defaults to `false`.
func splitTimer(name: String, newName: String?, manager: TimerManager, silent: Bool = false) {
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

    let generatedName: String
    if let supplied = newName?.trimmingCharacters(in: .whitespacesAndNewlines), !supplied.isEmpty {
        generatedName = supplied
    } else {
        generatedName = manager.nextSplitName(from: name)
    }

    if manager.loadTimer(name: generatedName) != nil {
        if !silent {
            print("⚠️  Timer '\(generatedName)' already exists! Choose a different name or specify one manually.")
        }
        return
    }

    let splitDate = Date()
    timer.stopTime = splitDate

    do {
        try manager.saveTimer(name: name, timer: timer)
    } catch {
        if !silent {
            print("❌ Error saving timer: \(error)")
        }
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
        if !silent {
            print("✅ Split timer '\(name)' into '\(generatedName)' at \(manager.formatDate(splitDate))")
        }
    } catch {
        if !silent {
            print("❌ Error creating timer '\(generatedName)': \(error)")
        }
    }
}
