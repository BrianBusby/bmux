import Foundation

/// Response for a normalized child-session lifecycle record request.
public struct ProvenanceSubsessionLifecycleResponse: Codable, Equatable, Sendable {
    /// Schema version for this response shape.
    public let schemaVersion: Int

    /// Whether authoritative provenance accepted the lifecycle event.
    public let accepted: Bool

    /// Identifier of the lifecycle event that was built.
    public let eventID: String?

    /// Identifier of the child session projection.
    public let childSessionID: String?

    /// Identifier of the projected relationship row.
    public let relationshipSessionID: String?

    /// Identifier of the projected external identity row.
    public let externalIdentityID: String?

    /// Bounded error summary when persistence failed.
    public let errorDescription: String?

    /// Creates a lifecycle response.
    public init(
        schemaVersion: Int = 1,
        accepted: Bool,
        eventID: String?,
        childSessionID: String?,
        relationshipSessionID: String?,
        externalIdentityID: String?,
        errorDescription: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.accepted = accepted
        self.eventID = eventID
        self.childSessionID = childSessionID
        self.relationshipSessionID = relationshipSessionID
        self.externalIdentityID = externalIdentityID
        self.errorDescription = errorDescription
    }
}
