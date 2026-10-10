import Foundation

extension TerminalSurface {
    /// Whether a configured startup command retains its output after the child exits.
    public var retainsConfiguredCommandOutput: Bool {
        let inheritedCommand = configTemplate?.command?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasCommand = initialCommand != nil || tmuxStartCommand != nil || inheritedCommand?.isEmpty == false
        return hasCommand && (configTemplate?.waitAfterCommand ?? false)
    }

    /// Returns the underlying Ghostty wait policy, including inherited configuration.
    public func debugWaitAfterCommand() -> Bool { configTemplate?.waitAfterCommand ?? false }
}
