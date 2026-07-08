import Foundation

/// The broad category BMUX assigned to a terminal command output.
public enum CommandOutputKind: String, Sendable, Codable {
    /// Output that did not match a specialized compressor.
    case generic
    /// Git command output such as status, branch, or log.
    case git
    /// Test runner output.
    case tests
    /// TypeScript compiler or checker diagnostics.
    case typescript
    /// Package manager install output.
    case packageInstall = "package_install"
    /// Search or recursive listing output.
    case search
}
