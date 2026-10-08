extension TerminalSurface {
    /// Whether this explicitly configured command keeps its terminal output after the child exits.
    public var waitsAfterCommand: Bool {
        configTemplate?.waitAfterCommand ?? false
    }

    /// Returns the command-retention policy for existing diagnostic callers.
    public func debugWaitAfterCommand() -> Bool { waitsAfterCommand }
}
