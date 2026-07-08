import Foundation

/// The signed-in bmux user, as both apps cache and display it.
///
/// A plain value mirrored from the Stack Auth user record. Codable so the
/// apps can persist it through ``BMUXAuthIdentityStore`` and restore the
/// identity card before the network session validates at launch.
public struct BMUXAuthUser: Codable, Equatable, Sendable {
    /// The Stack Auth user id.
    public let id: String
    /// The user's primary email, if one is set.
    public let primaryEmail: String?
    /// The user's display name, if one is set.
    public let displayName: String?

    /// Creates a user value.
    /// - Parameters:
    ///   - id: The Stack Auth user id.
    ///   - primaryEmail: The user's primary email, if any.
    ///   - displayName: The user's display name, if any.
    public init(id: String, primaryEmail: String?, displayName: String?) {
        self.id = id
        self.primaryEmail = primaryEmail
        self.displayName = displayName
    }
}
