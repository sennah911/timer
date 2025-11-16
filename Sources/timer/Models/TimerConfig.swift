import Foundation

/// Configuration settings for the timer application.
///
/// Configuration is stored in `~/.timer/config.json` and controls:
/// - Where timer files are stored
/// - Default custom properties for new timers
/// - Placeholder notes template
///
/// ## Example Configuration File
/// ```json
/// {
///     "timersDirectory": "~/Documents/timers",
///     "custom_properties": ["project: Client", "billable: true"],
///     "placeholder_notes": "## Notes\n- Fill in details"
/// }
/// ```
struct TimerConfig: Codable {
    /// The directory where timer Markdown files are stored.
    ///
    /// This path can be absolute or relative to the user's home directory.
    /// Tilde expansion is supported (e.g., `~/Documents/timers`).
    /// If not specified, defaults to `~/.timer`.
    var timersDirectory: String?

    /// Template text appended to new timer files as placeholder notes.
    ///
    /// This appears after the YAML frontmatter in newly created timer files.
    /// Useful for providing a consistent notes template.
    var placeholderNotes: String?

    /// Custom property lines to include in the YAML frontmatter of new timers.
    ///
    /// These appear after the standard fields (start_time, end_time, tags).
    /// Can be used for project-specific metadata like billable status, client names, etc.
    var customProperties: [String]?

    /// Coding keys for JSON serialization with snake_case mapping.
    enum CodingKeys: String, CodingKey {
        case timersDirectory
        case placeholderNotes = "placeholder_notes"
        case customProperties = "custom_properties"
    }

    init(timersDirectory: String? = nil,
         placeholderNotes: String? = nil,
         customProperties: [String]? = nil) {
        self.timersDirectory = timersDirectory
        self.placeholderNotes = TimerConfig.normalizePlaceholder(placeholderNotes)
        if let customProperties {
            self.customProperties = TimerConfig.normalizeCustomPropertiesArray(customProperties)
        } else {
            self.customProperties = nil
        }
    }

    init(from decoder: Decoder) throws {
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
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(timersDirectory, forKey: .timersDirectory)
        try container.encodeIfPresent(placeholderNotes, forKey: .placeholderNotes)
        if let customProperties {
            try container.encode(customProperties, forKey: .customProperties)
        }
    }

    /// Loads the timer configuration from `~/.timer/config.json`.
    ///
    /// - Parameter fileManager: The file manager to use. Defaults to `.default`.
    /// - Returns: A `TimerConfig` instance if the file exists and is valid JSON, otherwise `nil`.
    static func load(fileManager: FileManager = .default) -> TimerConfig? {
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
    func resolvedTimersDirectory(fileManager: FileManager = .default) -> URL? {
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
    func customPropertyLines() -> [String] {
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
func resolveDirectoryPath(_ path: String, relativeTo base: URL) -> URL {
    let expanded = (path as NSString).expandingTildeInPath
    if expanded.hasPrefix("/") {
        return URL(fileURLWithPath: expanded, isDirectory: true).standardizedFileURL
    } else {
        return URL(fileURLWithPath: expanded, isDirectory: true, relativeTo: base).standardizedFileURL
    }
}
