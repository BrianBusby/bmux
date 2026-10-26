import Foundation

/// An explicit source link, never synthesized from a branch name.
public struct WorkBriefLink: Equatable, Sendable, Identifiable {
    /// Stable source identifier.
    public let id: String
    /// Source-provided label.
    public let label: String
    /// Source-provided destination.
    public let url: URL
    /// Origin of the link.
    public let source: WorkBriefSource

    /// Creates an explicit source link.
    /// - Parameters:
    ///   - id: The stable source identity.
    ///   - label: A label supplied by the source.
    ///   - url: The explicit source destination.
    ///   - source: The owner of the link.
    public init(id: String, label: String, url: URL, source: WorkBriefSource) {
        self.id = id
        self.label = label
        self.url = url
        self.source = source
    }
}
