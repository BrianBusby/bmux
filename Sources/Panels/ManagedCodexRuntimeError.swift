import Foundation

/// Recoverable acquisition failures, safe to show without provider output or credentials.
enum ManagedCodexRuntimeError: LocalizedError, Equatable {
    case downloadFailed
    case invalidPackage
    case invalidInstallation

    var errorDescription: String? {
        switch self {
        case .downloadFailed:
            String(localized: "agentSession.chat.runtimeDownloadFailed", defaultValue: "Could not download bmux’s managed Codex runtime. Check your connection and retry.")
        case .invalidPackage:
            String(localized: "agentSession.chat.runtimePackageInvalid", defaultValue: "The Codex runtime download could not be verified. Retry to download a fresh copy.")
        case .invalidInstallation:
            String(localized: "agentSession.chat.runtimeInstallationInvalid", defaultValue: "bmux’s managed Codex runtime is damaged. Close connected sessions, remove its folder in ~/Library/Application Support/bmux/runtimes/codex, then retry.")
        }
    }
}
