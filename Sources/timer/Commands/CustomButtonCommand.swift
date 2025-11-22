import Foundation

/// The result of executing a custom button command.
public struct CustomButtonResult {
    /// Whether the command executed successfully (exit code 0)
    public let success: Bool

    /// The standard output from the command
    public let stdout: String

    /// The standard error from the command
    public let stderr: String

    /// The exit code of the command
    public let exitCode: Int32

    /// Combined output (stdout + stderr if stderr is not empty)
    public var output: String {
        if stderr.isEmpty {
            return stdout
        } else if stdout.isEmpty {
            return stderr
        } else {
            return stdout + "\n\nErrors:\n" + stderr
        }
    }
}

/// Executes a custom button command with placeholder substitution.
///
/// Replaces placeholders in the command string with their corresponding values:
/// - `{{path}}` is replaced with the timer file path
/// - Custom argument placeholders like `{{query}}` are replaced with their values from the arguments dictionary
///
/// The command is executed in a shell environment and both stdout and stderr are captured.
///
/// - Parameters:
///   - command: The command template with placeholders (e.g., "grep {{query}} \"{{path}}\"")
///   - timerPath: The absolute path to the timer file
///   - arguments: A dictionary mapping argument names to their values (e.g., ["query": "search term"])
/// - Returns: A `CustomButtonResult` containing the command output and execution status
public func executeCustomButtonCommand(
    command: String,
    timerPath: String,
    arguments: [String: String] = [:]
) -> CustomButtonResult {
    // Substitute placeholders
    var substitutedCommand = command.replacingOccurrences(of: "{{path}}", with: timerPath)

    // Substitute custom argument placeholders
    for (name, value) in arguments {
        let placeholder = "{{\(name)}}"
        substitutedCommand = substitutedCommand.replacingOccurrences(of: placeholder, with: value)
    }

    // Execute the command
    let process = Process()
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()

    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["bash", "-c", substitutedCommand]
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    do {
        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        let stdout = String(data: stdoutData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return CustomButtonResult(
            success: process.terminationStatus == 0,
            stdout: stdout,
            stderr: stderr,
            exitCode: process.terminationStatus
        )
    } catch {
        return CustomButtonResult(
            success: false,
            stdout: "",
            stderr: "Failed to execute command: \(error.localizedDescription)",
            exitCode: -1
        )
    }
}

/// Validates that a command string is safe to execute.
///
/// This is a basic validation to prevent obviously dangerous commands.
/// Note: This is not a comprehensive security measure and should not be relied upon
/// for untrusted input.
///
/// - Parameter command: The command string to validate
/// - Returns: `true` if the command passes basic safety checks
func isCommandSafe(_ command: String) -> Bool {
    // Basic checks for obviously dangerous patterns
    let dangerousPatterns = [
        "rm -rf /",
        "mkfs",
        "dd if=",
        "> /dev/",
        ":(){ :|:& };:",  // Fork bomb
    ]

    for pattern in dangerousPatterns {
        if command.contains(pattern) {
            return false
        }
    }

    return true
}
