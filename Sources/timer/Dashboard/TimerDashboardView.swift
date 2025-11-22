import SwiftTUI
import TimerCore

struct TimerDashboardView: View {
    @ObservedObject var timerVM: TimerViewModel
    var manager: TimerManager
    let directoryPath: String
    @State private var newTimerMessage: String?
    @State private var showStoppedTimers = false
    @State private var showDuplicatePrompt = false
    @State private var duplicateBaseName: String = ""
    @State private var duplicateSuggestedName: String = ""

    // Global button state
    @State private var expandedGlobalButton: String? = nil
    @State private var globalButtonInputs: [String: [String: String]] = [:]
    @State private var globalButtonOutput: String? = nil
    @State private var globalButtonOutputExpanded = false
    @State private var globalOutputLinesToShow: Int = 10

    var body: some View {
        let timers = timerVM.timers
        let stoppedCount = timers.filter { !$0.isRunning }.count
        
        return VStack(alignment: .leading, spacing: 1) {
            Text("Timer Dashboard")
                .bold()
            Text(directoryPath)
                .foregroundColor(.gray)
                .padding(.bottom, 1)

            // Global buttons section
            globalButtonsSection

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
    private var globalButtonsSection: some View {
        let globalButtons = manager.config.customButtons?.filter { button in
            (button.placement ?? .running) == .global
        } ?? []

        if !globalButtons.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("Global Actions")
                    .bold()
                    .foregroundColor(.cyan)

                HStack(spacing: 1) {
                    ForEach(globalButtons, id: \.title) { buttonConfig in
                        Button(expandedGlobalButton == buttonConfig.title ? "Cancel" : buttonConfig.title) {
                            toggleGlobalButton(buttonConfig)
                        }
                        .border(.brightBlue)
                    }
                }

                // Global button argument input section
                if let expandedButton = expandedGlobalButton,
                   let buttonConfig = globalButtons.first(where: { $0.title == expandedButton }),
                   let arguments = buttonConfig.arguments,
                   !arguments.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(arguments, id: \.name) { argument in
                            HStack(spacing: 1) {
                                Text("\(argument.label)")
                                    .foregroundColor(.gray)
                                TextField(placeholder: argument.label) { value in
                                    updateGlobalButtonInput(buttonTitle: expandedButton, argName: argument.name, value: value)
                                }
                                .border(Color.gray)
                            }
                        }
                        Button("Execute") {
                            executeGlobalButton(buttonConfig)
                        }
                        .border(.brightBlue)
                    }
                }

                // Global button output section
                if globalButtonOutputExpanded, let output = globalButtonOutput {
                    VStack(alignment: .leading, spacing: 0) {
                        Button("Hide Output") {
                            globalButtonOutputExpanded = false
                            globalOutputLinesToShow = 10
                        }
                        .border(.brightBlue)

                        let lines = output.components(separatedBy: .newlines)
                        let totalLines = lines.count
                        let linesToDisplay = min(globalOutputLinesToShow, totalLines)

                        ForEach(0..<linesToDisplay, id: \.self) { index in
                            Text(lines[index])
                                .foregroundColor(.gray)
                        }

                        if totalLines > globalOutputLinesToShow {
                            HStack(spacing: 1) {
                                Button("Show More (\(totalLines - globalOutputLinesToShow) more lines)") {
                                    globalOutputLinesToShow += 10
                                }
                                .border(.brightBlue)

                                Button("Show All") {
                                    globalOutputLinesToShow = totalLines
                                }
                                .border(.brightBlue)
                            }
                        } else if globalOutputLinesToShow > 10 && totalLines > 10 {
                            Button("Show Less") {
                                globalOutputLinesToShow = 10
                            }
                            .border(.brightBlue)
                        }

                        Text("(\(totalLines) lines total)")
                            .foregroundColor(.gray)
                            .padding(.top, 0)
                    }
                }
            }
            .padding(1)
            .border(Color.cyan)
            .padding(.bottom, 1)
        }
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

    // Global button functions
    private func toggleGlobalButton(_ buttonConfig: CustomButtonConfig) {
        if expandedGlobalButton == buttonConfig.title {
            // Cancel - collapse the form
            expandedGlobalButton = nil
            globalButtonInputs[buttonConfig.title] = nil
        } else {
            // Expand the form
            if let arguments = buttonConfig.arguments, !arguments.isEmpty {
                // Has arguments - show input form
                expandedGlobalButton = buttonConfig.title
                globalButtonInputs[buttonConfig.title] = [:]
            } else {
                // No arguments - execute immediately
                executeGlobalButton(buttonConfig)
            }
        }
    }

    private func updateGlobalButtonInput(buttonTitle: String, argName: String, value: String) {
        if globalButtonInputs[buttonTitle] == nil {
            globalButtonInputs[buttonTitle] = [:]
        }
        globalButtonInputs[buttonTitle]?[argName] = value
    }

    private func executeGlobalButton(_ buttonConfig: CustomButtonConfig) {
        // Gather argument values
        var arguments: [String: String] = [:]
        if let configArgs = buttonConfig.arguments {
            for arg in configArgs {
                if let value = globalButtonInputs[buttonConfig.title]?[arg.name] {
                    arguments[arg.name] = value
                } else {
                    arguments[arg.name] = ""
                }
            }
        }

        // Execute the command (without timer path for global buttons)
        let result = executeCustomButtonCommand(
            command: buttonConfig.command,
            timerPath: "",  // No timer path for global buttons
            arguments: arguments
        )

        // Display result
        if result.success {
            if !result.output.isEmpty {
                globalButtonOutput = result.output
                globalButtonOutputExpanded = true
                globalOutputLinesToShow = 10
                newTimerMessage = "Command executed successfully."
            } else {
                globalButtonOutput = nil
                globalButtonOutputExpanded = false
                newTimerMessage = "Command executed (no output)."
            }
        } else {
            globalButtonOutput = result.output
            globalButtonOutputExpanded = true
            globalOutputLinesToShow = 10
            newTimerMessage = "Command failed (exit code: \(result.exitCode))."
        }

        // Clean up
        expandedGlobalButton = nil
        globalButtonInputs[buttonConfig.title] = nil
    }
}
