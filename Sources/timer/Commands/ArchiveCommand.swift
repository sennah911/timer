import Foundation

public func archiveTimer(name: String, manager: TimerManager, silent: Bool = false) {
    do {
        let destination = try manager.archiveTimerFile(name: name)
        if !silent {
            print("📦 Archived timer '\(name)' to \(destination.path)")
        }
    } catch let error as TimerManagerError {
        if silent { return }
        switch error {
        case .timerNotFound:
            print("❌ Timer '\(name)' not found!")
        case .timerAlreadyExists:
            print("⚠️  Destination already exists for '\(name)'.")
        case .invalidName:
            print("❌ Invalid archive name for '\(name)'.")
        }
    } catch {
        if !silent {
            print("❌ Failed to archive timer '\(name)': \(error)")
        }
    }
}
