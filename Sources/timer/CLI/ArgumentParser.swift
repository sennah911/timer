import Foundation
import TimerCore

struct ParsedArguments {
    var directoryOverride: URL?
    var useRunningTimer: Bool
    var timerPathOverride: String?
    var commandArguments: [String]
}

func parseArguments(_ rawArgs: [String]) -> ParsedArguments {
    let workingDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    var directoryOverride: URL?
    var cleanedArguments: [String] = []
    var useRunningTimer = false
    var timerPathOverride: String?

    var index = 0
    while index < rawArgs.count {
        let argument = rawArgs[index]
        if argument == "--directory" || argument == "-d" {
            let valueIndex = index + 1
            guard valueIndex < rawArgs.count else {
                print("❌ --directory requires a path argument")
                exit(1)
            }

            let path = rawArgs[valueIndex]
            directoryOverride = resolveDirectoryPath(path, relativeTo: workingDirectory)
            index += 2
            continue
        }

        if argument == "--running" || argument == "-r" {
            useRunningTimer = true
            index += 1
            continue
        }

        if argument == "--timer-path" || argument == "-p" {
            let valueIndex = index + 1
            guard valueIndex < rawArgs.count else {
                print("❌ --timer-path requires a file path argument")
                exit(1)
            }

            timerPathOverride = rawArgs[valueIndex]
            index += 2
            continue
        }

        cleanedArguments.append(argument)
        index += 1
    }

    return ParsedArguments(
        directoryOverride: directoryOverride,
        useRunningTimer: useRunningTimer,
        timerPathOverride: timerPathOverride,
        commandArguments: cleanedArguments
    )
}

/// Extracts the timer name from a file path by taking the last component and removing .md extension
func extractTimerName(from path: String) -> String? {
    let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    var filename = url.lastPathComponent

    // Remove .md extension if present
    if filename.hasSuffix(".md") {
        filename = String(filename.dropLast(3))
    }

    // Validate the name is not empty
    guard !filename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return nil
    }

    return filename
}

/// Resolves a timer path string to an absolute URL
func resolveTimerPath(_ path: String) -> URL {
    let expanded = (path as NSString).expandingTildeInPath
    if expanded.hasPrefix("/") {
        return URL(fileURLWithPath: expanded).standardizedFileURL
    } else {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        return URL(fileURLWithPath: expanded, relativeTo: cwd).standardizedFileURL
    }
}
