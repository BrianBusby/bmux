import Foundation

/// A strongly-typed handle to a secret string persisted in the macOS Keychain.
///
/// `KeychainSecretKey` is for app-owned credentials that should not be written
/// to `bmux.json` or a plain file. The matching store is
/// ``KeychainSecretStore``. A key contributes only the logical setting id and
/// account name; the store supplies the Keychain service so hosts can namespace
/// secrets by bundle identifier.
public struct KeychainSecretKey: Sendable, Equatable {
    /// The dotted identifier (matches the convention used by other key flavors).
    public let id: String

    /// The Keychain account under the store's service.
    public let account: String

    /// The value returned when no non-empty Keychain item exists.
    public let defaultValue: String

    /// Creates a Keychain-backed secret key.
    ///
    /// - Parameters:
    ///   - id: The dotted identifier.
    ///   - account: The Keychain generic-password account name.
    ///   - defaultValue: The fallback when the item is missing or empty; defaults to `""`.
    public init(id: String, account: String, defaultValue: String = "") {
        precondition(!id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "KeychainSecretKey.id must not be blank")
        precondition(!account.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "KeychainSecretKey.account must not be blank")
        self.id = id
        self.account = account
        self.defaultValue = defaultValue
    }
}
