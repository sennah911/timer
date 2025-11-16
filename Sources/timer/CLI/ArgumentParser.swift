import Foundation

struct ParsedArguments {
    var directoryOverride: URL?
    var useRunningTimer: Bool
    var commandArguments: [String]
}

func parseArguments(_ rawArgs: [String]) -> ParsedArguments {
    let workingDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    var directoryOverride: URL?
    var cleanedArguments: [String] = []
    var useRunningTimer = false

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

        cleanedArguments.append(argument)
        index += 1
    }

    return ParsedArguments(
        directoryOverride: directoryOverride,
        useRunningTimer: useRunningTimer,
        commandArguments: cleanedArguments
    )
}
