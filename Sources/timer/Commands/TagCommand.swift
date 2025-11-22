import Foundation

public func tagTimer(name: String, tag: String, manager: TimerManager, silent: Bool = false) {
    guard var timer = manager.loadTimer(name: name) else {
        if !silent {
            print("❌ Timer '\(name)' not found!")
        }
        return
    }

    if !timer.tags.contains(tag) {
        timer.tags.append(tag)
        do {
            try manager.saveTimer(name: name, timer: timer)
            if !silent {
                print("✅ Added tag '\(tag)' to timer '\(name)'")
            }
        } catch {
            if !silent {
                print("❌ Error saving timer: \(error)")
            }
        }
    } else {
        if !silent {
            print("⚠️  Tag '\(tag)' already exists on timer '\(name)'")
        }
    }
}

public func removeTag(name: String, tag: String, manager: TimerManager) {
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
