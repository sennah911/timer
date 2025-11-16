import Foundation

// Parse command-line arguments
let rawArgs = CommandLine.arguments
let arguments = Array(rawArgs.dropFirst())

let parsed = parseArguments(arguments)

// If no command provided, run the dashboard
if parsed.commandArguments.isEmpty {
    runDashboard(directoryOverride: parsed.directoryOverride)
}

// Get the command and remaining arguments
guard let commandRaw = parsed.commandArguments.first else {
    printUsage()
    exit(0)
}

let command = commandRaw.lowercased()
let remainingArguments = Array(parsed.commandArguments.dropFirst())

// Create the timer manager
let manager = TimerManager(directoryOverride: parsed.directoryOverride)

// Route to the appropriate command
routeCommand(command: command, arguments: remainingArguments, manager: manager, useRunningTimer: parsed.useRunningTimer)
