import Foundation
import TimerCore

public struct TimerDashboardEntry: Identifiable, Equatable {
    public let name: String
    public let statusSymbol: String
    public let statusDescription: String
    public let durationText: String
    public let isRunning: Bool
    public let startText: String
    public let stopText: String
    public let startTime: Date?
    public let stopTime: Date?
    public let tags: [String]
    public var id: String { name }

    public func updatingDurationText(_ newText: String) -> TimerDashboardEntry {
        TimerDashboardEntry(
            name: name,
            statusSymbol: statusSymbol,
            statusDescription: statusDescription,
            durationText: newText,
            isRunning: isRunning,
            startText: startText,
            stopText: stopText,
            startTime: startTime,
            stopTime: stopTime,
            tags: tags)
    }
}

public func makeDashboardEntries(manager: TimerManager) -> [TimerDashboardEntry] {
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
            stopTime: timer.stopTime,
            tags: timer.tags)
    }
}
