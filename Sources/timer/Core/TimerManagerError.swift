import Foundation

/// Errors that can occur during timer management operations.
public enum TimerManagerError: Error {
    /// The specified timer file does not exist.
    ///
    /// - Parameter String: The name of the timer that was not found.
    case timerNotFound(String)

    /// A timer with the specified name already exists.
    ///
    /// - Parameter String: The name of the conflicting timer.
    case timerAlreadyExists(String)

    /// The provided timer name is invalid (e.g., empty or whitespace-only).
    ///
    /// - Parameter String: The invalid name that was provided.
    case invalidName(String)
}
