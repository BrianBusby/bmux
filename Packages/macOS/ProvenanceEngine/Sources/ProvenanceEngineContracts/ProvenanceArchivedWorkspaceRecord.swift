import Foundation

/// Last-known workspace identity and display facts retained after closure.
///
/// Archive records are keyed by the restart-stable workspace ID. Restoring a
/// workspace does not delete its record or change its identity. The snapshot
/// is separately clearable and is not appended to the immutable PE ledger.
public struct ProvenanceArchivedWorkspaceRecord: Codable, Equatable, Sendable, Identifiable {
    /// Restart-stable workspace ID, also used by workspace display Current State.
    public let id: String
    /// Workspace title recorded when it closed.
    public let title: String
    /// First creation time when known; nil for legacy captures.
    public let createdAt: Date?
    /// Most recent close time for this logical workspace.
    public let closedAt: Date
    /// Last accepted meaningful work event, independent of metadata refreshes.
    public let lastActivityAt: Date?
    /// Last-known display facts frozen at close, when available.
    public let displayAtClose: ProvenanceWorkspaceDisplayRecord?
    /// Workspace identity color recorded at close, when available.
    public let colorHex: String?
    /// Stable capture-limitation code for a client to localize, when known.
    public let coverageCode: String?

    /// Creates the last-known record for a closed logical workspace.
    ///
    /// The caller supplies `lastActivityAt` only from a meaningful work event.
    public init(
        id: String,
        title: String,
        createdAt: Date?,
        closedAt: Date,
        lastActivityAt: Date?,
        displayAtClose: ProvenanceWorkspaceDisplayRecord?,
        colorHex: String?,
        coverageCode: String?
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.closedAt = closedAt
        self.lastActivityAt = lastActivityAt
        self.displayAtClose = displayAtClose
        self.colorHex = colorHex
        self.coverageCode = coverageCode
    }
}
