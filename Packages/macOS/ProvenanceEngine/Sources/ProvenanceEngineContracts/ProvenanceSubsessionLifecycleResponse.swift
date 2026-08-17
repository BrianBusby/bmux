import Foundation

/// Response for a normalized child-session lifecycle record request.
@available(*, deprecated, renamed: "ProvenanceSessionLifecycleResponse")
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

    /// Creates a deprecated child-session response from the producer-neutral response.
    public init(_ response: ProvenanceSessionLifecycleResponse) {
        self.init(
            schemaVersion: response.schemaVersion,
            accepted: response.accepted,
            eventID: response.eventID,
            childSessionID: response.sessionID,
            relationshipSessionID: response.relationshipSessionID,
            externalIdentityID: response.externalIdentityID,
            errorDescription: response.errorDescription
        )
    }
}

extension ProvenanceSessionLifecycleResponse {
    /// Equivalent deprecated child-session lifecycle response.
    @available(*, deprecated, renamed: "ProvenanceSessionLifecycleResponse")
    public var subsessionLifecycleResponse: ProvenanceSubsessionLifecycleResponse {
        ProvenanceSubsessionLifecycleResponse(self)
    }
}
