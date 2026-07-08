/// A single command captured from a `Button`'s action closure.
///
/// The interpreter records the call shape; a host runtime executes it. The
/// `bmux` case maps onto bmux's socket command dispatcher (`method` + string
/// arguments), giving interpreted buttons the breadth of the bmux CLI.
public enum ActionCommand: Codable, Sendable, Equatable {
    /// A bmux command: a dispatcher method plus named string params, e.g.
    /// `bmux("workspace.select", workspace_id: w.id)` →
    /// `.bmux("workspace.select", ["workspace_id": "<uuid>"])`. Maps directly
    /// onto the socket command protocol (`{"method","params"}`).
    case bmux(method: String, params: [String: String])
    case log(String)
    /// Opens a URL (host runs it, e.g. via the workspace opener).
    case openURL(String)
}
