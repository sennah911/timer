import Foundation
import SwiftTUI

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
        timer help                                            Show this help message

    Global options:
        -d, --directory <path>            Override the timers directory for this command
        -r, --running                     Use the first running timer (stop, split, tag)

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

    Timers are stored as Markdown files in ~/.timer/
    """)
}

func routeCommand(command: String, arguments: [String], manager: TimerManager, useRunningTimer: Bool) {
    switch command {
    case "start":
        guard let name = arguments.first else {
            print("❌ Usage: timer [--directory <path>] start <name>")
            exit(1)
        }
        startTimer(name: name, manager: manager)

    case "stop":
        if useRunningTimer {
            if !arguments.isEmpty {
                print("❌ Usage: timer [--directory <path>] stop [--running]")
                exit(1)
            }
            guard let runningName = manager.firstRunningTimerName() else {
                print("⚠️  No running timers found.")
                exit(1)
            }
            stopTimer(name: runningName, manager: manager)
        } else {
            guard let name = arguments.first else {
                print("❌ Usage: timer [--directory <path>] stop <name>")
                exit(1)
            }
            stopTimer(name: name, manager: manager)
        }

    case "split":
        if useRunningTimer {
            if arguments.count > 1 {
                print("❌ Usage: timer [--directory <path>] split [--running] [new_name]")
                exit(1)
            }
            guard let runningName = manager.firstRunningTimerName() else {
                print("⚠️  No running timers found.")
                exit(1)
            }
            let newName = arguments.first
            splitTimer(name: runningName, newName: newName, manager: manager)
        } else {
            guard let name = arguments.first else {
                print("❌ Usage: timer [--directory <path>] split <name> [new_name]")
                exit(1)
            }
            if arguments.count > 2 {
                print("❌ Usage: timer [--directory <path>] split <name> [new_name]")
                exit(1)
            }
            let newName = arguments.count == 2 ? arguments[1] : nil
            splitTimer(name: name, newName: newName, manager: manager)
        }

    case "tag":
        if useRunningTimer {
            guard arguments.count == 1 else {
                print("❌ Usage: timer [--directory <path>] tag [--running] <tag>")
                exit(1)
            }
            guard let runningName = manager.firstRunningTimerName() else {
                print("⚠️  No running timers found.")
                exit(1)
            }
            tagTimer(name: runningName, tag: arguments[0], manager: manager)
        } else {
            guard arguments.count >= 2 else {
                print("❌ Usage: timer [--directory <path>] tag <name> <tag>")
                exit(1)
            }
            tagTimer(name: arguments[0], tag: arguments[1], manager: manager)
        }

    case "remove-tag":
        guard arguments.count >= 2 else {
            print("❌ Usage: timer [--directory <path>] remove-tag <name> <tag>")
            exit(1)
        }
        removeTag(name: arguments[0], tag: arguments[1], manager: manager)

    case "set-start":
        guard arguments.count >= 2 else {
            print("❌ Usage: timer [--directory <path>] set-start <name> <ISO8601-datetime>")
            exit(1)
        }
        setStart(name: arguments[0], dateString: arguments[1], manager: manager)

    case "set-stop":
        guard arguments.count >= 2 else {
            print("❌ Usage: timer [--directory <path>] set-stop <name> <ISO8601-datetime>")
            exit(1)
        }
        setStop(name: arguments[0], dateString: arguments[1], manager: manager)

    case "rename":
        guard arguments.count >= 2 else {
            print("❌ Usage: timer [--directory <path>] rename <old_name> <new_name>")
            exit(1)
        }
        renameTimer(name: arguments[0], newName: arguments[1], manager: manager)

    case "show":
        guard let name = arguments.first else {
            print("❌ Usage: timer [--directory <path>] show <name>")
            exit(1)
        }
        showTimer(name: name, manager: manager)

    case "list":
        listTimers(manager: manager)

    case "help", "--help", "-h":
        printUsage()

    default:
        print("❌ Unknown command: \(command)")
        printUsage()
        exit(1)
    }
}
