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
    @State private var isAddingTag = false
    @State private var isRenaming = false
    @State private var renameSuggestedName: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 1) {
                Text(timer.statusSymbol)
                    .foregroundColor(timer.isRunning ? .green : .red)
                    .bold()
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(timer.name) \(formattedTags)")
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
                    
                    Button(isSplitExpanded ? "Cancel Split" : "Split") {
                        toggleSplit()
                    }
                } else {
                    Button("Archive") {
                        archiveTimer(name: timer.name, manager: manager, silent: true)
                        rowMessage = "Archived timer."
                        onAction()
                    }
                }
                
                Button(isAddingTag ? "Cancel Tag" : "Add Tag") {
                    toggleAddTag()
                }
                
                Button(isRenaming ? "Cancel Rename" : "Rename") {
                    toggleRename()
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
            
            if isRenaming {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Rename Suggested: \(renameSuggestedName)")
                        .foregroundColor(.gray)
                    HStack(spacing: 1) {
                        Button("Use suggestion") {
                            confirmRename(named: renameSuggestedName)
                        }
                        TextField(placeholder: "Or type a new name, then Enter") { value in
                            confirmRename(named: value)
                        }
                    }
                }
            }
            
            if isAddingTag {
                HStack(spacing: 1) {
                    TextField(placeholder: "Enter tag, then Enter") { value in
                        confirmAddTag(value)
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
    
    private func toggleAddTag() {
        if isAddingTag {
            isAddingTag = false
        } else {
            isAddingTag = true
        }
    }
    
    private func confirmAddTag(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            rowMessage = "Enter a tag."
            return
        }
        if timer.tags.contains(trimmed) {
            rowMessage = "Tag '\(trimmed)' already exists."
            return
        }
        tagTimer(name: timer.name, tag: trimmed, manager: manager, silent: true)
        rowMessage = "Added tag '\(trimmed)'."
        isAddingTag = false
        onAction()
    }
    
    private func toggleRename() {
        if isRenaming {
            isRenaming = false
        } else {
            renameSuggestedName = manager.nextSplitName(from: timer.name)
            isRenaming = true
        }
    }
    
    private func confirmRename(named input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            rowMessage = "Enter a new name."
            return
        }
        renameTimer(name: timer.name, newName: trimmed, manager: manager, silent: true)
        rowMessage = "Renamed timer to \(trimmed)."
        isRenaming = false
        onAction()
    }
    
    private var formattedTags: String {
        if timer.tags.isEmpty { return "[]" }
        return "[\(timer.tags.joined(separator: ", "))]"
    }
}
