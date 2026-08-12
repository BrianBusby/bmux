import Foundation

/// Errors emitted by ``KeychainSecretStore`` when a Keychain operation fails.
public enum KeychainSecretStoreError: Error, Equatable, Sendable, CustomStringConvertible {
    /// The Security framework is unavailable on the current platform.
    case unavailable
    /// Reading a Keychain item failed with the given Security status.
    case readFailed(status: Int32)
    /// Writing a Keychain item failed with the given Security status.
    case writeFailed(status: Int32)
    /// Deleting a Keychain item failed with the given Security status.
    case deleteFailed(status: Int32)

    public var description: String {
        switch self {
        case .unavailable:
            return "Keychain is unavailable"
        case .readFailed(let status):
            return "Keychain read failed with status \(status)"
        case .writeFailed(let status):
            return "Keychain write failed with status \(status)"
        case .deleteFailed(let status):
            return "Keychain delete failed with status \(status)"
        }
    }
}
