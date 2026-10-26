import Foundation

/// Source-backed current items changed since a prior viewed brief.
public struct WorkBriefChanges: Equatable, Sendable {
    /// Time the previous brief was captured.
    public let since: Date
    /// Stable IDs for changed local workspaces.
    public let localIDs: [UUID]
    /// Provider-qualified IDs for changed external items.
    public let externalIDs: [String]
}
