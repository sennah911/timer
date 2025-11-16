import Foundation

func renameTimer(name: String, newName: String, manager: TimerManager, silent: Bool = false) {
    do {
        let destination = try manager.renameTimerFile(from: name, to: newName)
        if !silent {
            print("✏️  Renamed timer '\(name)' to '\(destination.deletingPathExtension().lastPathComponent)'")
        }
    } catch let error as TimerManagerError {
        if silent { return }
        switch error {
        case .timerNotFound:
            print("❌ Timer '\(name)' not found!")
        case .timerAlreadyExists(let conflict):
            print("⚠️  Timer '\(conflict)' already exists.")
        case .invalidName:
            print("❌ Invalid name provided.")
        }
    } catch {
        if !silent {
            print("❌ Failed to rename timer '\(name)': \(error)")
        }
    }
}
