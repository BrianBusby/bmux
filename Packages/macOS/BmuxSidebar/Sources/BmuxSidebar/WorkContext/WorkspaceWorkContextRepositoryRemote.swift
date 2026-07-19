public import Foundation

/// A repository remote associated with workspace work context.
public struct WorkspaceWorkContextRepositoryRemote: Equatable, Sendable {
    /// The remote slug, such as `owner/repo`, when known.
    public let slug: String?

    /// The remote URL, when known.
    public let url: URL?

    /// Where this remote value came from.
    public let source: WorkspaceWorkContextSource

    /// Whether the remote value may no longer match the active work.
    public let isStale: Bool

    /// Creates a repository remote context.
    /// - Parameters:
    ///   - slug: The remote slug, such as `owner/repo`, when known.
    ///   - url: The remote URL, when known.
    ///   - source: Where this remote value came from.
    ///   - isStale: Whether the remote value may no longer match the active work.
    public init(
        slug: String?,
        url: URL?,
        source: WorkspaceWorkContextSource,
        isStale: Bool = false
    ) {
        self.slug = slug
        self.url = url
        self.source = source
        self.isStale = isStale
    }
}
