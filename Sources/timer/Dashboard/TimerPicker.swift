import SwiftTUI

struct TimerPicker: View {
    var timers: [TimerDashboardEntry]
    var manager: TimerManager
    var onAction: () -> Void
    
    private var runningTimers: [TimerDashboardEntry] {
        timers.filter { $0.isRunning }
    }
    
    private var stoppedTimers: [TimerDashboardEntry] {
        timers.filter { !$0.isRunning }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if !runningTimers.isEmpty {
                TimerSection(title: "Running", entries: runningTimers, manager: manager, onAction: onAction)
                    .border(Color.gray)
                    .background(.black)
            }
            if !stoppedTimers.isEmpty {
                TimerSection(title: "Stopped / Idle", entries: stoppedTimers, manager: manager, onAction: onAction)
                    .border(Color.gray)
                    .background(.black)
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
                .padding(.vertical, 0)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    TimerPickerRow(timer: entry, manager: manager, onAction: onAction, rowIndex: index)
                }
            }
        }
        .padding(.bottom, 1)
    }
}

private struct TimerPickerRow: View {
    let timer: TimerDashboardEntry
    var manager: TimerManager
    var onAction: () -> Void
    let rowIndex: Int
    @State private var isSplitExpanded = false
    @State private var rowMessage: String?
    @State private var suggestedSplitName: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .top, spacing: 1) {
                Text(timer.statusSymbol)
                    .foregroundColor(timer.isRunning ? .green : .red)
                    .bold()
                VStack(alignment: .leading, spacing: 0) {
                    Text(timer.name)
                        .bold()
                    Text(timer.statusDescription)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text(timer.durationText)
                    .foregroundColor(.cyan)
            }
            .padding(.vertical, 0)
            
            HStack(spacing: 1) {
                Button("Stop") {
                    if timer.isRunning {
                        stopTimer(name: timer.name, manager: manager, silent: true)
                        rowMessage = "Stopped timer."
                        onAction()
                    } else {
                        rowMessage = "Timer is not running."
                    }
                }
                .padding(1)
                .background(.xterm(white: 6))
                
                Button(isSplitExpanded ? "Cancel" : "Split") {
                    toggleSplit()
                }
                .padding(1)
                .background(.xterm(white: 6))
            }
            
            if isSplitExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Suggested: \(suggestedSplitName)")
                        .foregroundColor(.gray)
                    HStack(spacing: 1) {
                        Button("Use suggestion") {
                            performSplit(named: suggestedSplitName)
                        }
                        .padding(1)
                        .background(.xterm(white: 6))
                        
                        TextField(placeholder: "Or type a name, then Enter") { value in
                            performSplit(named: value)
                        }
                        .border()
                    }
                }
            }
            
            if let rowMessage {
                Text(rowMessage)
                    .foregroundColor(.gray)
            }
        }
        .padding(1)
        .background(rowBackground)
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
    
    private var rowBackground: Color {
        rowIndex.isMultiple(of: 2) ? .black : .xterm(white: 1)
    }
}
