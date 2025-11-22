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

    // Custom button state
    @State private var expandedCustomButton: String? = nil  // Title of currently expanded button
    @State private var customButtonInputs: [String: [String: String]] = [:]  // [buttonTitle: [argName: value]]
    @State private var customButtonOutput: String? = nil  // Output from last executed custom button
    @State private var customButtonOutputExpanded = false  // Whether output section is shown
    @State private var outputLinesToShow: Int = 10  // Number of output lines to display

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
                    .border(.brightBlue)

                    Button(isSplitExpanded ? "Cancel Split" : "Split") {
                        toggleSplit()
                    }
                    .border(.brightBlue)
                } else {
                    Button("Archive") {
                        archiveTimer(name: timer.name, manager: manager, silent: true)
                        rowMessage = "Archived timer."
                        onAction()
                    }
                    .border(.brightBlue)
                }
                
                Button(isAddingTag ? "Cancel Tag" : "Add Tag") {
                    toggleAddTag()
                }
                .border(.brightBlue)

                Button(isRenaming ? "Cancel Rename" : "Rename") {
                    toggleRename()
                }
                .border(.brightBlue)

                // Custom buttons from config (filtered by placement)
                if let customButtons = manager.config.customButtons {
                    let filteredButtons = customButtons.filter { button in
                        let placement = button.placement ?? .running
                        if timer.isRunning {
                            return placement == .running
                        } else {
                            return placement == .stopped
                        }
                    }

                    ForEach(filteredButtons, id: \.title) { buttonConfig in
                        Button(expandedCustomButton == buttonConfig.title ? "Cancel" : buttonConfig.title) {
                            toggleCustomButton(buttonConfig)
                        }
                        .border(.brightBlue)
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
                        .border(.brightBlue)

                        TextField(placeholder: "Or type a name, then Enter") { value in
                            performSplit(named: value)
                        }
                        .border(Color.gray)
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
                        .border(.brightBlue)
                        TextField(placeholder: "Or type a new name, then Enter") { value in
                            confirmRename(named: value)
                        }
                        .border(Color.gray)
                    }
                }
            }
            
            if isAddingTag {
                HStack(spacing: 1) {
                    TextField(placeholder: "Enter tag, then Enter") { value in
                        confirmAddTag(value)
                    }
                    .border(Color.gray)
                }
            }

            // Custom button argument input section
            if let expandedButton = expandedCustomButton,
               let customButtons = manager.config.customButtons,
               let buttonConfig = customButtons.first(where: { $0.title == expandedButton }),
               let arguments = buttonConfig.arguments,
               !arguments.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(arguments, id: \.name) { argument in
                        HStack(spacing: 1) {
                            Text("\(argument.label)")
                                .foregroundColor(.gray)
                            TextField(placeholder: argument.label) { value in
                                updateCustomButtonInput(buttonTitle: expandedButton, argName: argument.name, value: value)
                            }
                            .border(Color.gray)
                        }
                    }
                    Button("Execute") {
                        executeCustomButton(buttonConfig)
                    }
                    .border(.brightBlue)
                }
            }

            // Custom button output section
            if customButtonOutputExpanded, let output = customButtonOutput {
                VStack(alignment: .leading, spacing: 0) {
                    Button("Hide Output") {
                        customButtonOutputExpanded = false
                        outputLinesToShow = 10  // Reset to default
                    }
                    .border(.brightBlue)

                    let lines = output.components(separatedBy: .newlines)
                    let totalLines = lines.count
                    let linesToDisplay = min(outputLinesToShow, totalLines)

                    ForEach(0..<linesToDisplay, id: \.self) { index in
                        Text(lines[index])
                            .foregroundColor(.gray)
                    }

                    if totalLines > outputLinesToShow {
                        HStack(spacing: 1) {
                            Button("Show More (\(totalLines - outputLinesToShow) more lines)") {
                                outputLinesToShow += 10
                            }
                            .border(.brightBlue)

                            Button("Show All") {
                                outputLinesToShow = totalLines
                            }
                            .border(.brightBlue)
                        }
                    } else if outputLinesToShow > 10 && totalLines > 10 {
                        Button("Show Less") {
                            outputLinesToShow = 10
                        }
                        .border(.brightBlue)
                    }

                    Text("(\(totalLines) lines total)")
                        .foregroundColor(.gray)
                        .padding(.top, 0)
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

    // Custom button functions
    private func toggleCustomButton(_ buttonConfig: CustomButtonConfig) {
        if expandedCustomButton == buttonConfig.title {
            // Cancel - collapse the form
            expandedCustomButton = nil
            customButtonInputs[buttonConfig.title] = nil
            rowMessage = nil
        } else {
            // Expand the form
            if let arguments = buttonConfig.arguments, !arguments.isEmpty {
                // Has arguments - show input form
                expandedCustomButton = buttonConfig.title
                customButtonInputs[buttonConfig.title] = [:]
            } else {
                // No arguments - execute immediately
                executeCustomButton(buttonConfig)
            }
        }
    }

    private func updateCustomButtonInput(buttonTitle: String, argName: String, value: String) {
        if customButtonInputs[buttonTitle] == nil {
            customButtonInputs[buttonTitle] = [:]
        }
        customButtonInputs[buttonTitle]?[argName] = value
    }

    private func executeCustomButton(_ buttonConfig: CustomButtonConfig) {
        let timerPath = manager.timerPath(name: timer.name).path

        // Gather argument values
        var arguments: [String: String] = [:]
        if let configArgs = buttonConfig.arguments {
            for arg in configArgs {
                if let value = customButtonInputs[buttonConfig.title]?[arg.name] {
                    arguments[arg.name] = value
                } else {
                    arguments[arg.name] = ""
                }
            }
        }

        // Execute the command
        let result = executeCustomButtonCommand(
            command: buttonConfig.command,
            timerPath: timerPath,
            arguments: arguments
        )

        // Display result
        if result.success {
            if !result.output.isEmpty {
                customButtonOutput = result.output
                customButtonOutputExpanded = true
                outputLinesToShow = 10  // Reset to default for new output
                rowMessage = "Command executed successfully."
            } else {
                customButtonOutput = nil
                customButtonOutputExpanded = false
                rowMessage = "Command executed (no output)."
            }
        } else {
            customButtonOutput = result.output
            customButtonOutputExpanded = true
            outputLinesToShow = 10  // Reset to default for new output
            rowMessage = "Command failed (exit code: \(result.exitCode))."
        }

        // Clean up
        expandedCustomButton = nil
        customButtonInputs[buttonConfig.title] = nil
    }

    private var formattedTags: String {
        if timer.tags.isEmpty { return "[]" }
        return "[\(timer.tags.joined(separator: ", "))]"
    }
}
