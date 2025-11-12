import SwiftTUI

struct TimerDashboardView: View {
    @ObservedObject var timerVM: TimerViewModel
    var manager: TimerManager
    let directoryPath: String
    @State private var newTimerMessage: String?
    
    var body: some View {
        let timers = timerVM.timers
        
        return VStack(alignment: .leading, spacing: 1) {
            Text("Timer Dashboard")
                .bold()
            Text(directoryPath)
                .foregroundColor(.gray)
                .padding(.bottom, 1)
            
            newTimerSection
            
            if timers.isEmpty {
                Text("No timers found. Run `timer start <name>` to begin.")
                    .foregroundColor(.yellow)
                    .padding(.top, 1)
            } else {
                TimerPicker(timers: timers, manager: manager) {
                    timerVM.refresh()
                }
//                    .border(Color.gray)
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
        }
        .padding(1)
        .border(Color.gray)
        .padding(.bottom, 1)
    }
    
    private func createTimer(named input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            newTimerMessage = "Enter a name before starting a timer."
            return
        }
        
        if manager.loadTimer(name: trimmed) != nil {
            newTimerMessage = "Timer '\(trimmed)' already exists."
            return
        }
        
        startTimer(name: trimmed, manager: manager, silent: true)
        newTimerMessage = "Started timer '\(trimmed)'."
        timerVM.refresh()
    }
}
