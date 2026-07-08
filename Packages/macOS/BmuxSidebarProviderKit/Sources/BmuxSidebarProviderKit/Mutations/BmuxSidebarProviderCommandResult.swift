import Foundation

/// Result returned after BMUX handles a provider mutation.
public struct BmuxSidebarProviderCommandResult: Codable, Equatable, Sendable {
    /// Whether BMUX accepted and completed the command.
    public var ok: Bool

    /// Creates a command result.
    public init(ok: Bool) {
        self.ok = ok
    }
}
