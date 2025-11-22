import Foundation
import SwiftTUI
import TimerCore

func runDashboard(directoryOverride: URL?) -> Never {
    let manager = TimerManager(directoryOverride: directoryOverride)
    let viewModel = TimerViewModel(manager: manager)
    let view = TimerDashboardView(timerVM: viewModel, manager: manager, directoryPath: manager.timersDirectory.path)
    Application(rootView: view).start()
    exit(0)
}

func printUsage() {
    print("""
    Timer - A command-line timer tool

    Usage:
        timer [--directory <path>] start <name>               Start a timer
        timer [--directory <path>] stop <name>                Stop a running timer
        timer [--directory <path>] split <name> [new_name]    Stop one timer and start another
        timer [--directory <path>] tag <name> <tag>           Add a tag to a timer
        timer [--directory <path>] remove-tag <name> <tag>    Remove a tag from a timer
        timer [--directory <path>] rename <old> <new>         Rename a timer file
        timer [--directory <path>] set-start <name> <ISO8601> Set the start time
        timer [--directory <path>] set-stop <name> <ISO8601>  Set the stop time
        timer [--directory <path>] show <name>                Show timer details
        timer [--directory <path>] list                       List all timers
        timer [--directory <path>] archive <name>             Archive a timer
        timer help                                            Show this help message

    Global options:
        -d, --directory <path>            Override the timers directory for this command
        -r, --running                     Use the first running timer (stop, split, tag)
        -p, --timer-path <path>           Specify timer by file path instead of name

    Config:
        Default directory is ~/.timer unless overridden in ~/.timer/config.json
        Supported keys:
            "timersDirectory"     Override the timers directory
            "custom_properties"   Array or newline string inserted after tags
            "placeholder_notes"   Notes appended after metadata for new timers
        Example config:
        {
            "timersDirectory": "/path/to/timers",
            "custom_properties": ["project: Client", "billable: true"],
            "placeholder_notes": "## Notes\\n- Fill in details"
        }

    Examples:
        timer start work
        timer stop work
        timer split work
        timer tag work client-project
        timer remove-tag work client-project
        timer set-start work 2025-11-04T09:00:00Z
        timer set-stop work 2025-11-04T17:00:00Z
        timer archive work
        timer stop --timer-path ~/Documents/timers/work.md
        timer show -p ./relative/path/timer.md

    Timers are stored as Markdown files in ~/.timer/
    Archived timers are moved to ~/.timer/archived/
    """)
}

/// Resolves the timer name from either a path override, running timer flag, or arguments
func resolveTimerName(timerPathOverride: String?, useRunningTimer: Bool, arguments: [String], manager: TimerManager) -> String? {
    // Check for conflicting flags
    if timerPathOverride != nil && useRunningTimer {
        print("❌ Cannot use both --running and --timer-path together")
        exit(1)
    }

    // Use timer path override if provided
    if let pathOverride = timerPathOverride {
        let resolvedPath = resolveTimerPath(pathOverride)

        // Validate path is within timers directory
        if !manager.validateTimerPath(resolvedPath) {
            print("❌ Timer path must be within the timers directory: \(manager.timersDirectory.path)")
            exit(1)
        }

        // Extract name from path
        guard let name = extractTimerName(from: pathOverride) else {
            print("❌ Invalid timer path: \(pathOverride)")
            exit(1)
        }

        return name
    }

    // Use running timer if flag is set
    if useRunningTimer {
        return manager.firstRunningTimerName()
    }

    // Use first argument as name
    return arguments.first
}

func routeCommand(command: String, arguments: [String], manager: TimerManager, useRunningTimer: Bool, timerPathOverride: String?) {
    switch command {
    case "start":
        guard let name = arguments.first else {
            print("❌ Usage: timer [--directory <path>] start <name>")
            exit(1)
        }
        startTimer(name: name, manager: manager)

    case "stop":
        guard let name = resolveTimerName(timerPathOverride: timerPathOverride, useRunningTimer: useRunningTimer, arguments: arguments, manager: manager) else {
            if useRunningTimer {
                print("⚠️  No running timers found.")
            } else {
                print("❌ Usage: timer [--directory <path>] [-p <path>] [-r] stop [<name>]")
            }
            exit(1)
        }
        stopTimer(name: name, manager: manager)

    case "split":
        guard let name = resolveTimerName(timerPathOverride: timerPathOverride, useRunningTimer: useRunningTimer, arguments: arguments, manager: manager) else {
            if useRunningTimer {
                print("⚠️  No running timers found.")
            } else {
                print("❌ Usage: timer [--directory <path>] [-p <path>] [-r] split [<name>] [new_name]")
            }
            exit(1)
        }

        // Determine new name from remaining arguments
        let newName: String?
        if timerPathOverride != nil || useRunningTimer {
            newName = arguments.first
        } else {
            newName = arguments.count >= 2 ? arguments[1] : nil
        }

        splitTimer(name: name, newName: newName, manager: manager)

    case "tag":
        guard let name = resolveTimerName(timerPathOverride: timerPathOverride, useRunningTimer: useRunningTimer, arguments: arguments, manager: manager) else {
            if useRunningTimer {
                print("⚠️  No running timers found.")
            } else {
                print("❌ Usage: timer [--directory <path>] [-p <path>] [-r] tag [<name>] <tag>")
            }
            exit(1)
        }

        // Determine tag from remaining arguments
        let tag: String
        if timerPathOverride != nil || useRunningTimer {
            guard let firstArg = arguments.first else {
                print("❌ Tag argument required")
                exit(1)
            }
            tag = firstArg
        } else {
            guard arguments.count >= 2 else {
                print("❌ Usage: timer [--directory <path>] [-p <path>] [-r] tag [<name>] <tag>")
                exit(1)
            }
            tag = arguments[1]
        }

        tagTimer(name: name, tag: tag, manager: manager)

    case "remove-tag":
        guard let name = resolveTimerName(timerPathOverride: timerPathOverride, useRunningTimer: useRunningTimer, arguments: arguments, manager: manager) else {
            print("❌ Usage: timer [--directory <path>] [-p <path>] remove-tag [<name>] <tag>")
            exit(1)
        }

        // Determine tag from remaining arguments
        let tag: String
        if timerPathOverride != nil {
            guard let firstArg = arguments.first else {
                print("❌ Tag argument required")
                exit(1)
            }
            tag = firstArg
        } else {
            guard arguments.count >= 2 else {
                print("❌ Usage: timer [--directory <path>] [-p <path>] remove-tag [<name>] <tag>")
                exit(1)
            }
            tag = arguments[1]
        }

        removeTag(name: name, tag: tag, manager: manager)

    case "set-start":
        guard let name = resolveTimerName(timerPathOverride: timerPathOverride, useRunningTimer: useRunningTimer, arguments: arguments, manager: manager) else {
            print("❌ Usage: timer [--directory <path>] [-p <path>] set-start [<name>] <ISO8601-datetime>")
            exit(1)
        }

        // Determine datetime from remaining arguments
        let dateString: String
        if timerPathOverride != nil {
            guard let firstArg = arguments.first else {
                print("❌ Datetime argument required")
                exit(1)
            }
            dateString = firstArg
        } else {
            guard arguments.count >= 2 else {
                print("❌ Usage: timer [--directory <path>] [-p <path>] set-start [<name>] <ISO8601-datetime>")
                exit(1)
            }
            dateString = arguments[1]
        }

        setStart(name: name, dateString: dateString, manager: manager)

    case "set-stop":
        guard let name = resolveTimerName(timerPathOverride: timerPathOverride, useRunningTimer: useRunningTimer, arguments: arguments, manager: manager) else {
            print("❌ Usage: timer [--directory <path>] [-p <path>] set-stop [<name>] <ISO8601-datetime>")
            exit(1)
        }

        // Determine datetime from remaining arguments
        let dateString: String
        if timerPathOverride != nil {
            guard let firstArg = arguments.first else {
                print("❌ Datetime argument required")
                exit(1)
            }
            dateString = firstArg
        } else {
            guard arguments.count >= 2 else {
                print("❌ Usage: timer [--directory <path>] [-p <path>] set-stop [<name>] <ISO8601-datetime>")
                exit(1)
            }
            dateString = arguments[1]
        }

        setStop(name: name, dateString: dateString, manager: manager)

    case "rename":
        guard let name = resolveTimerName(timerPathOverride: timerPathOverride, useRunningTimer: useRunningTimer, arguments: arguments, manager: manager) else {
            print("❌ Usage: timer [--directory <path>] [-p <path>] rename [<old_name>] <new_name>")
            exit(1)
        }

        // Determine new name from remaining arguments
        let newName: String
        if timerPathOverride != nil {
            guard let firstArg = arguments.first else {
                print("❌ New name argument required")
                exit(1)
            }
            newName = firstArg
        } else {
            guard arguments.count >= 2 else {
                print("❌ Usage: timer [--directory <path>] [-p <path>] rename [<old_name>] <new_name>")
                exit(1)
            }
            newName = arguments[1]
        }

        renameTimer(name: name, newName: newName, manager: manager)

    case "show":
        guard let name = resolveTimerName(timerPathOverride: timerPathOverride, useRunningTimer: useRunningTimer, arguments: arguments, manager: manager) else {
            print("❌ Usage: timer [--directory <path>] [-p <path>] show [<name>]")
            exit(1)
        }
        showTimer(name: name, manager: manager)

    case "list":
        listTimers(manager: manager)

    case "archive":
        guard let name = resolveTimerName(timerPathOverride: timerPathOverride, useRunningTimer: useRunningTimer, arguments: arguments, manager: manager) else {
            print("❌ Usage: timer [--directory <path>] [-p <path>] archive [<name>]")
            exit(1)
        }
        archiveTimer(name: name, manager: manager)

    case "help", "--help", "-h":
        printUsage()

    default:
        print("❌ Unknown command: \(command)")
        printUsage()
        exit(1)
    }
}
