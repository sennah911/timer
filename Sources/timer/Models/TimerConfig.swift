import Foundation

/// Represents an argument that a custom button command needs.
///
/// Arguments are prompted for via inline text fields in the TUI when the button is clicked.
/// Each argument has a name (used as a placeholder in the command) and a label (shown in the UI).
///
/// ## Example
/// ```json
/// {
///     "name": "query",
///     "label": "Search for:"
/// }
/// ```
public struct ButtonArgument: Codable {
    /// The placeholder name used in the command (e.g., "query" for {{query}})
    public let name: String

    /// The label shown in the UI for the input field
    public let label: String

    public init(name: String, label: String) {
        self.name = name
        self.label = label
    }
}

/// Defines where a custom button should be displayed in the TUI.
public enum ButtonPlacement: String, Codable {
    /// Button appears above all timers (global scope, no timer context)
    case global

    /// Button appears only on running timer rows
    case running

    /// Button appears only on stopped timer rows
    case stopped
}

/// Represents a custom button configuration for the TUI.
///
/// Custom buttons can appear in different locations based on the placement property:
/// - `global`: Above all timers (no timer context, {{path}} not available)
/// - `running`: On running timer rows only
/// - `stopped`: On stopped timer rows only
///
/// Commands can include placeholders like {{path}} for the timer file path
/// and custom {{argument}} placeholders for user inputs.
///
/// ## Example
/// ```json
/// {
///     "title": "Search Timer",
///     "command": "grep -i \"{{query}}\" \"{{path}}\"",
///     "placement": "running",
///     "arguments": [
///         {"name": "query", "label": "Search for:"}
///     ]
/// }
/// ```
public struct CustomButtonConfig: Codable {
    /// The button label shown in the UI
    public let title: String

    /// The shell command to execute. Supports {{path}} and custom {{name}} placeholders.
    public let command: String

    /// Optional arguments that need to be collected from the user before executing
    public let arguments: [ButtonArgument]?

    /// Where the button should be displayed. Defaults to `running` if not specified.
    public let placement: ButtonPlacement?

    public init(title: String, command: String, arguments: [ButtonArgument]? = nil, placement: ButtonPlacement? = nil) {
        self.title = title
        self.command = command
        self.arguments = arguments
        self.placement = placement
    }
}

/// Configuration settings for the timer application.
///
/// Configuration is stored in `~/.timer/config.json` and controls:
/// - Where timer files are stored
/// - Default custom properties for new timers
/// - Placeholder notes template
/// - Custom buttons for the TUI
///
/// ## Example Configuration File
/// ```json
/// {
///     "timersDirectory": "~/Documents/timers",
///     "custom_properties": ["project: Client", "billable: true"],
///     "placeholder_notes": "## Notes\n- Fill in details",
///     "custom_buttons": [
///         {
///             "title": "Open in VS Code",
///             "command": "code \"{{path}}\""
///         }
///     ]
/// }
/// ```
public struct TimerConfig: Codable {
    /// The directory where timer Markdown files are stored.
    ///
    /// This path can be absolute or relative to the user's home directory.
    /// Tilde expansion is supported (e.g., `~/Documents/timers`).
    /// If not specified, defaults to `~/.timer`.
    public var timersDirectory: String?

    /// Template text appended to new timer files as placeholder notes.
    ///
    /// This appears after the YAML frontmatter in newly created timer files.
    /// Useful for providing a consistent notes template.
    public var placeholderNotes: String?

    /// Custom property lines to include in the YAML frontmatter of new timers.
    ///
    /// These appear after the standard fields (start_time, end_time, tags).
    /// Can be used for project-specific metadata like billable status, client names, etc.
    public var customProperties: [String]?

    /// Custom buttons to display in the TUI for each timer.
    ///
    /// These buttons can execute shell commands with placeholders for the timer path
    /// and custom arguments. Buttons appear on every timer row in the dashboard.
    public var customButtons: [CustomButtonConfig]?

    /// Coding keys for JSON serialization with snake_case mapping.
    enum CodingKeys: String, CodingKey {
        case timersDirectory
        case placeholderNotes = "placeholder_notes"
        case customProperties = "custom_properties"
        case customButtons = "custom_buttons"
    }

    public init(timersDirectory: String? = nil,
         placeholderNotes: String? = nil,
         customProperties: [String]? = nil,
         customButtons: [CustomButtonConfig]? = nil) {
        self.timersDirectory = timersDirectory
        self.placeholderNotes = TimerConfig.normalizePlaceholder(placeholderNotes)
        if let customProperties {
            self.customProperties = TimerConfig.normalizeCustomPropertiesArray(customProperties)
        } else {
            self.customProperties = nil
        }
        self.customButtons = customButtons
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timersDirectory = try container.decodeIfPresent(String.self, forKey: .timersDirectory)
        let placeholder = try container.decodeIfPresent(String.self, forKey: .placeholderNotes)
        placeholderNotes = TimerConfig.normalizePlaceholder(placeholder)

        if let propertiesArray = try container.decodeIfPresent([String].self, forKey: .customProperties) {
            customProperties = TimerConfig.normalizeCustomPropertiesArray(propertiesArray)
        } else if let propertiesString = try container.decodeIfPresent(String.self, forKey: .customProperties) {
            customProperties = TimerConfig.normalizeCustomPropertiesString(propertiesString)
        } else {
            customProperties = nil
        }

        customButtons = try container.decodeIfPresent([CustomButtonConfig].self, forKey: .customButtons)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(timersDirectory, forKey: .timersDirectory)
        try container.encodeIfPresent(placeholderNotes, forKey: .placeholderNotes)
        if let customProperties {
            try container.encode(customProperties, forKey: .customProperties)
        }
        try container.encodeIfPresent(customButtons, forKey: .customButtons)
    }

    /// Loads the timer configuration from `~/.timer/config.json`.
    ///
    /// - Parameter fileManager: The file manager to use. Defaults to `.default`.
    /// - Returns: A `TimerConfig` instance if the file exists and is valid JSON, otherwise `nil`.
    public static func load(fileManager: FileManager = .default) -> TimerConfig? {
        let configDirectory = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".timer")
        let configURL = configDirectory.appendingPathComponent("config.json")

        guard fileManager.fileExists(atPath: configURL.path),
              let data = try? Data(contentsOf: configURL) else {
            return nil
        }

        let decoder = JSONDecoder()
        return try? decoder.decode(TimerConfig.self, from: data)
    }

    /// Resolves the timers directory path to an absolute URL.
    ///
    /// Handles tilde expansion and relative paths, resolving them relative
    /// to the user's home directory.
    ///
    /// - Parameter fileManager: The file manager to use. Defaults to `.default`.
    /// - Returns: The resolved directory URL, or `nil` if `timersDirectory` is not set.
    public func resolvedTimersDirectory(fileManager: FileManager = .default) -> URL? {
        guard let rawPath = timersDirectory?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !rawPath.isEmpty else {
            return nil
        }
        let base = fileManager.homeDirectoryForCurrentUser
        return resolveDirectoryPath(rawPath, relativeTo: base)
    }

    /// Returns the custom property lines as an array.
    ///
    /// - Returns: The custom properties array, or an empty array if not set.
    public func customPropertyLines() -> [String] {
        return customProperties ?? []
    }

    private static func normalizePlaceholder(_ value: String?) -> String? {
        guard let value else { return nil }
        let sanitized = value.replacingOccurrences(of: "\r", with: "")
        return sanitized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : sanitized
    }

    private static func normalizeCustomPropertiesArray(_ array: [String]) -> [String]? {
        let sanitized = sanitizeCustomPropertyLines(array)
        let hasContent = sanitized.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return hasContent ? sanitized : nil
    }

    private static func normalizeCustomPropertiesString(_ string: String) -> [String]? {
        let sanitizedString = string.replacingOccurrences(of: "\r", with: "")
        let lines = sanitizedString.components(separatedBy: .newlines)
        return normalizeCustomPropertiesArray(lines)
    }

    private static func sanitizeCustomPropertyLines(_ lines: [String]) -> [String] {
        return lines.map { $0.replacingOccurrences(of: "\r", with: "") }
    }
}

/// Resolves a directory path to an absolute URL.
///
/// Handles both absolute and relative paths:
/// - Tilde (`~`) is expanded to the user's home directory
/// - Absolute paths (starting with `/`) are used as-is
/// - Relative paths are resolved relative to the provided base URL
///
/// - Parameters:
///   - path: The path to resolve. May contain tilde or be relative.
///   - base: The base URL for resolving relative paths.
/// - Returns: The standardized absolute directory URL.
public func resolveDirectoryPath(_ path: String, relativeTo base: URL) -> URL {
    let expanded = (path as NSString).expandingTildeInPath
    if expanded.hasPrefix("/") {
        return URL(fileURLWithPath: expanded, isDirectory: true).standardizedFileURL
    } else {
        return URL(fileURLWithPath: expanded, isDirectory: true, relativeTo: base).standardizedFileURL
    }
}
