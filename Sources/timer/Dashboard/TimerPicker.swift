import SwiftTUI

struct TimerPicker: View {
    var timers: [TimerDashboardEntry]
    var manager: TimerManager
    var showStopped: Bool
    var onAction: () -> Void
    
    private var runningTimers: [TimerDashboardEntry] {
        timers.filter { $0.isRunning }
    }
    
    private var stoppedTimers: [TimerDashboardEntry] {
        timers.filter { !$0.isRunning }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !runningTimers.isEmpty {
                TimerSection(title: "Running", entries: runningTimers, manager: manager, onAction: onAction)
            }
            if showStopped, !stoppedTimers.isEmpty {
                TimerSection(title: "Stopped / Idle", entries: stoppedTimers, manager: manager, onAction: onAction)
            }
        }
    }
}

private struct TimerSection: View {
    let title: String
    let entries: [TimerDashboardEntry]
    var manager: TimerManager
    var onAction: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .bold()
            ForEach(entries) { entry in
                TimerPickerRow(timer: entry, manager: manager, onAction: onAction)
                Divider()
            }
        }
        .padding(.vertical, 1)
    }
}

private struct TimerPickerRow: View {
    let timer: TimerDashboardEntry
    var manager: TimerManager
    var onAction: () -> Void
    @State private var isSplitExpanded = false
    @State private var rowMessage: String?
    @State private var suggestedSplitName: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 1) {
                Text(timer.statusSymbol)
                    .foregroundColor(timer.isRunning ? .green : .red)
                    .bold()
                VStack(alignment: .leading, spacing: 0) {
                    Text(timer.name)
                        .bold()
                    Text(timer.statusDescription)
                        .foregroundColor(.gray)
                    HStack(spacing: 1) {
                        Text("Start:")
                            .foregroundColor(.gray)
                        Text(timer.startText)
                        Text("| Stop:")
                            .foregroundColor(.gray)
                        Text(timer.stopText)
                    }
                    Text("Elapsed: \(timer.durationText)")
                        .foregroundColor(.cyan)
                }
                
                Spacer()
            }
            .padding(.vertical, 0)
            
            HStack(spacing: 1) {
                if timer.isRunning {
                    Button("Stop") {
                        stopTimer(name: timer.name, manager: manager, silent: true)
                        rowMessage = "Stopped timer."
                        onAction()
                    }
                    
                    Button(isSplitExpanded ? "Cancel" : "Split") {
                        toggleSplit()
                    }
                } else {
                    Button("Archive") {
                        archiveTimer(name: timer.name, manager: manager, silent: true)
                        rowMessage = "Archived timer."
                        onAction()
                    }
                }
            }
            
            if isSplitExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Suggested: \(suggestedSplitName)")
                        .foregroundColor(.gray)
                    HStack(spacing: 1) {
                        Button("Use suggestion") {
                            performSplit(named: suggestedSplitName)
                        }
                        
                        TextField(placeholder: "Or type a name, then Enter") { value in
                            performSplit(named: value)
                        }
                    }
                }
            }
            
            if let rowMessage {
                Text(rowMessage)
                    .foregroundColor(.gray)
            }
        }
    }
    
    private func toggleSplit() {
        if isSplitExpanded {
            isSplitExpanded = false
            rowMessage = nil
        } else {
            if !timer.isRunning {
                rowMessage = "Start the timer before splitting."
                return
            }
            suggestedSplitName = manager.nextSplitName(from: timer.name)
            isSplitExpanded = true
        }
    }
    
    private func performSplit(named input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let providedName = trimmed.isEmpty ? nil : trimmed
        
        if let providedName, manager.loadTimer(name: providedName) != nil {
            rowMessage = "Timer '\(providedName)' already exists."
            return
        }
        
        splitTimer(name: timer.name, newName: providedName, manager: manager, silent: true)
        rowMessage = "Split timer into \(providedName ?? suggestedSplitName)."
        isSplitExpanded = false
        onAction()
    }
}
