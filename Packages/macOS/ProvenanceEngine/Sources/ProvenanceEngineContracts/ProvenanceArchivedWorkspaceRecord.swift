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
    /// Opaque client status code captured at this close, when known.
    public let lastRecordedStatusCode: String?

    /// Creates the last-known record for a closed logical workspace.
    ///
    /// The caller supplies `lastActivityAt` only from a meaningful work event.
    /// - Parameter id: Restart-stable logical workspace ID.
    /// - Parameter title: Workspace title at close.
    /// - Parameter createdAt: First creation time, when known.
    /// - Parameter closedAt: Time of this close.
    /// - Parameter lastActivityAt: Most recent meaningful work event, when known.
    /// - Parameter displayAtClose: Display facts frozen at close, when available.
    /// - Parameter colorHex: Identity color at close, when available.
    /// - Parameter coverageCode: Stable capture limitation code, when known.
    /// - Parameter lastRecordedStatusCode: Opaque client status at this close, when known.
    public init(
        id: String,
        title: String,
        createdAt: Date?,
        closedAt: Date,
        lastActivityAt: Date?,
        displayAtClose: ProvenanceWorkspaceDisplayRecord?,
        colorHex: String?,
        coverageCode: String?,
        lastRecordedStatusCode: String? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.closedAt = closedAt
        self.lastActivityAt = lastActivityAt
        self.displayAtClose = displayAtClose
        self.colorHex = colorHex
        self.coverageCode = coverageCode
        self.lastRecordedStatusCode = lastRecordedStatusCode
    }
}
