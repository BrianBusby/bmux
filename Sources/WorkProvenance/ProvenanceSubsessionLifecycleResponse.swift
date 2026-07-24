import Foundation

/// Response for a normalized child-session lifecycle record request.
struct ProvenanceSubsessionLifecycleResponse: Codable, Equatable, Sendable {
    /// Schema version for this response shape.
    let schemaVersion: Int

    /// Whether authoritative provenance accepted the lifecycle event.
    let accepted: Bool

    /// Identifier of the lifecycle event that was built.
    let eventID: String?

    /// Identifier of the child session projection.
    let childSessionID: String?

    /// Identifier of the projected relationship row.
    let relationshipSessionID: String?

    /// Identifier of the projected external identity row.
    let externalIdentityID: String?

    /// Bounded error summary when persistence failed.
    let errorDescription: String?

    /// Creates a lifecycle response.
    init(
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
