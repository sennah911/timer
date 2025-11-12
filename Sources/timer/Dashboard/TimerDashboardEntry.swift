import Foundation

struct TimerDashboardEntry: Identifiable, Equatable {
    let name: String
    let statusSymbol: String
    let statusDescription: String
    let durationText: String
    let isRunning: Bool
    let startText: String
    let stopText: String
    let startTime: Date?
    let stopTime: Date?
    var id: String { name }
    
    func updatingDurationText(_ newText: String) -> TimerDashboardEntry {
        TimerDashboardEntry(
            name: name,
            statusSymbol: statusSymbol,
            statusDescription: statusDescription,
            durationText: newText,
            isRunning: isRunning,
            startText: startText,
            stopText: stopText,
            startTime: startTime,
            stopTime: stopTime)
    }
}

func makeDashboardEntries(manager: TimerManager) -> [TimerDashboardEntry] {
    return manager.listTimers().compactMap { name -> TimerDashboardEntry? in
        guard let timer = manager.loadTimer(name: name) else {
            return nil
        }
        let statusSymbol: String
        let statusDescription: String
        if timer.isRunning {
            statusSymbol = "⏱"
            statusDescription = "Running"
        } else if timer.startTime != nil {
            statusSymbol = "⏹"
            statusDescription = "Stopped"
        } else {
            statusSymbol = "○"
            statusDescription = "Idle"
        }
        let durationText = timer.duration.map { manager.formatDuration($0) } ?? "—"
        let startText = timer.startTime.map { manager.formatDate($0) } ?? "—"
        let stopText = timer.stopTime.map { manager.formatDate($0) } ?? "—"
        return TimerDashboardEntry(
            name: name,
            statusSymbol: statusSymbol,
            statusDescription: statusDescription,
            durationText: durationText,
            isRunning: timer.isRunning,
            startText: startText,
            stopText: stopText,
            startTime: timer.startTime,
            stopTime: timer.stopTime)
    }
}
