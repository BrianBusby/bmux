extension TabManager {
    var terminalChatReader: (any TerminalChatReading)? {
        get { sessionPresentation.terminalChatReader }
        set { sessionPresentation.terminalChatReader = newValue }
    }

    var workProvenanceRuntime: WorkProvenanceRuntime? {
        get { sessionPresentation.workProvenanceRuntime }
        set { sessionPresentation.workProvenanceRuntime = newValue }
    }
}
