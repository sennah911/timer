import SwiftTUI

struct TimerDashboardView: View {
    @ObservedObject var timerVM: TimerViewModel
    var manager: TimerManager
    let directoryPath: String
    @State private var newTimerMessage: String?
    @State private var showStoppedTimers = false
    @State private var showDuplicatePrompt = false
    @State private var duplicateBaseName: String = ""
    @State private var duplicateSuggestedName: String = ""
    
    var body: some View {
        let timers = timerVM.timers
        let stoppedCount = timers.filter { !$0.isRunning }.count
        
        return VStack(alignment: .leading, spacing: 1) {
            Text("Timer Dashboard")
                .bold()
            Text(directoryPath)
                .foregroundColor(.gray)
                .padding(.bottom, 1)
            
            
            if showDuplicatePrompt {
                duplicatePromptSection
            } else {
                newTimerSection
            }
            
            if timers.isEmpty {
                Text("No timers found. Run `timer start <name>` to begin.")
                    .foregroundColor(.yellow)
                    .padding(.top, 1)
            } else {
                TimerPicker(timers: timers, manager: manager, showStopped: showStoppedTimers) {
                    timerVM.refresh()
                }
            }
            
            HStack {
                HStack {
                    Button("Refresh (updates elapsed times)") {
                        timerVM.refresh()
                    }
                    .border(.brightBlue)
                    
                    Text("|")
                    
                    if stoppedCount > 0 || showStoppedTimers {
                        Button(showStoppedTimers ? "Hide stopped timers" : "Show stopped timers (\(stoppedCount))") {
                            showStoppedTimers.toggle()
                        }
                        .border(.brightBlue)
                    }
                }
                
                Spacer()
            }

            if let message = newTimerMessage {
                Text(message)
                    .foregroundColor(.cyan)
                    .padding(.top, 1)
            }
            
            Text("Press Ctrl+C to exit, or use CLI commands for actions.")
                .foregroundColor(.gray)
                .padding(.top, 1)
        }
        .padding()
    }
    
    @ViewBuilder
    private var newTimerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Create Timer")
                .bold()
            TextField(placeholder: "Type a name and press Enter") { value in
                createTimer(named: value)
            }
            .border(Color.gray)
        }
        .padding(1)
        .padding(.bottom, 1)
    }
    
    @ViewBuilder
    private var duplicatePromptSection: some View {
        if showDuplicatePrompt {
            VStack(alignment: .leading, spacing: 0) {
                Text("Timer '\(duplicateBaseName)' already exists.")
                    .foregroundColor(.yellow)
                Text("Suggested: \(duplicateSuggestedName)")
                    .foregroundColor(.gray)
                    .padding(.bottom, 0)
                HStack(spacing: 1) {
                    Button("Use suggestion") {
                        confirmCreateTimer(with: duplicateSuggestedName)
                    }
                    .border(.brightBlue)
                    Button("Cancel") {
                        cancelDuplicatePrompt()
                    }
                    .border(.brightBlue)
                }
                TextField(placeholder: "Or type a different name, then Enter") { value in
                    confirmCreateTimer(with: value)
                }
                .border(Color.gray)
            }
            .padding(1)
            .border(Color.gray)
        }
    }
    
    private func createTimer(named input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            newTimerMessage = "Enter a name before starting a timer."
            return
        }
        
        if manager.loadTimer(name: trimmed) != nil {
            duplicateBaseName = trimmed
            duplicateSuggestedName = manager.nextSplitName(from: trimmed)
            newTimerMessage = "Timer '\(trimmed)' already exists. Choose another name."
            showDuplicatePrompt = true
            return
        }
        
        confirmCreateTimer(with: trimmed)
    }
    
    private func confirmCreateTimer(with rawName: String) {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            newTimerMessage = "Enter a name before starting a timer."
            return
        }
        
        if manager.loadTimer(name: trimmed) != nil {
            duplicateBaseName = trimmed
            duplicateSuggestedName = manager.nextSplitName(from: trimmed)
            newTimerMessage = "Timer '\(trimmed)' already exists. Choose another name."
            showDuplicatePrompt = true
            return
        }
        
        startTimer(name: trimmed, manager: manager, silent: true)
        newTimerMessage = "Started timer '\(trimmed)'."
        showDuplicatePrompt = false
        timerVM.refresh()
    }
    
    private func cancelDuplicatePrompt() {
        showDuplicatePrompt = false
        duplicateBaseName = ""
        duplicateSuggestedName = ""
    }
}
