/// Per-window dependencies for the three session views. PE availability does
/// not govern either the terminal lifetime or the Chat connection.
@MainActor
final class WindowSessionPresentation {
    var terminalChatReader: (any TerminalChatReading)?
    var workProvenanceRuntime: WorkProvenanceRuntime?
}
