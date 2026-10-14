import Foundation

/// Safe remote PTY failures carried between daemon, app and CLI boundaries.
///
/// Raw values are existing protocol diagnostics, not localized display labels.
/// Classifying a raw value again preserves it, so aggregation cannot erase an
/// already-sanitized failure. Unrecognized detail is never disclosed.
public enum RemotePTYFailure: String, CaseIterable, Sendable {
    /// An unrecognized failure whose underlying details must stay private.
    case operationFailed = "remote PTY operation failed"
    /// The daemon must be updated before persistent sessions can be used.
    case unsupportedDaemon = "remote daemon does not support persistent SSH PTY sessions; reconnect the remote workspace to update bmux"
    /// The requested persistent session has already ended.
    case sessionNotRunning = "persistent SSH PTY session is no longer running"
    /// The remote input queue cannot accept more data yet.
    case inputBackedUp = "remote PTY input is temporarily backed up"
    /// The workspace no longer has an active remote connection.
    case connectionInactive = "remote connection is not active"
    /// The daemon or its tunnel has not become ready.
    case daemonNotReady = "remote daemon is not ready"
    /// A session-list response omitted the workspace identifier.
    case missingWorkspaceID = "missing workspace_id in SSH PTY session list response"
    /// A session-list response omitted the session identifier.
    case missingSessionID = "missing session_id in SSH PTY session list response"
    /// A daemon operation exceeded its deadline.
    case timedOut = "remote daemon did not respond in time"

    /// Classifies raw transport details or an existing safe protocol diagnostic.
    /// - Parameter message: Untrusted transport text; unknown details are discarded.
    public init(sanitizing message: String) {
        let lowered = message.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let canonical = Self.allCases.first(where: { $0.rawValue.lowercased() == lowered }) {
            self = canonical
        } else if lowered.contains("missing required capability") ||
            lowered.contains("pty.session") || lowered.contains("method_not_found") ||
            lowered.contains(Self.unsupportedDaemon.rawValue.lowercased()) {
            self = .unsupportedDaemon
        } else if lowered.contains("pty_session_not_found") ||
            (lowered.contains("persistent ssh pty session") &&
                (lowered.contains("not running") || lowered.contains("no longer running"))) ||
            (lowered.contains("persistent pty session") && lowered.contains("not running")) {
            self = .sessionNotRunning
        } else if lowered.contains("pty_input_queue_full") || lowered.contains("pty input queue is full") ||
            lowered.contains(Self.inputBackedUp.rawValue.lowercased()) {
            self = .inputBackedUp
        } else if lowered.contains("remote connection is not active") {
            self = .connectionInactive
        } else if lowered.contains("remote daemon is not ready") || lowered.contains("remote daemon tunnel is not ready") {
            self = .daemonNotReady
        } else if lowered.contains("missing workspace_id in ssh pty session list response") {
            self = .missingWorkspaceID
        } else if lowered.contains("missing session_id in ssh pty session list response") {
            self = .missingSessionID
        } else if lowered.contains("timed out") || lowered.contains("timeout") ||
            lowered.contains(Self.timedOut.rawValue.lowercased()) {
            self = .timedOut
        } else {
            self = .operationFailed
        }
    }
}
