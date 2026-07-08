import Foundation

/// Complete render model emitted by an in-process sidebar provider.
public struct BmuxSidebarProviderRenderModel: Codable, Equatable, Sendable {
    /// Provider id that produced this model.
    public var providerId: String
    /// Snapshot sequence this model was rendered from.
    public var snapshotSequence: UInt64
    /// Sidebar sections to display.
    public var sections: [BmuxSidebarProviderSection]
    /// Layout BMUX should use for the sections.
    public var presentation: BmuxSidebarProviderPresentation

    /// Creates a provider render model.
    public init(
        providerId: String,
        snapshotSequence: UInt64,
        sections: [BmuxSidebarProviderSection],
        presentation: BmuxSidebarProviderPresentation = .tree
    ) {
        self.providerId = providerId
        self.snapshotSequence = snapshotSequence
        self.sections = sections
        self.presentation = presentation
    }
}
