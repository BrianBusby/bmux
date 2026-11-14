import ProvenanceEngineContracts

extension AgentSessionSmartSessionSnapshot {
    struct CrossSessionAwareness: Equatable, Sendable {
        let status: String
        let relatedReadStatus: String
        let collisionReadStatus: String
        let relatedSessions: [RelatedSession]
        let collisions: [Collision]
        let relatedOmittedCount: Int
        let collisionOmittedCount: Int

        static let unavailable = CrossSessionAwareness(related: nil, collisions: nil)

        init(related: ProvenanceRelatedSessionResponse?, collisions: ProvenanceArtifactCollisionResponse?) {
            let relatedProjection = related?.projection
            let collisionProjection = collisions?.projection
            self.status = relatedProjection == nil && collisionProjection == nil ? "unavailable" : "available"
            self.relatedReadStatus = relatedProjection == nil ? "unavailable" : "available"
            self.collisionReadStatus = collisionProjection == nil ? "unavailable" : "available"
            self.relatedSessions = (relatedProjection?.relatedSessions ?? []).map(RelatedSession.init)
            self.collisions = (collisionProjection?.candidates ?? []).map(Collision.init)
            self.relatedOmittedCount = relatedProjection?.excludedCandidates.count ?? 0
            self.collisionOmittedCount = collisionProjection?.excludedCandidates.count ?? 0
        }

        var bridgePayload: [String: Any] {
            [
                "status": status,
                "relatedReadStatus": relatedReadStatus,
                "collisionReadStatus": collisionReadStatus,
                "relatedSessions": relatedSessions.map(\.bridgePayload),
                "collisions": collisions.map(\.bridgePayload),
                "relatedOmittedCount": relatedOmittedCount,
                "collisionOmittedCount": collisionOmittedCount
            ]
        }
    }
}
