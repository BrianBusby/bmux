import ProvenanceEngineContracts

extension AgentSessionSmartSessionSnapshot {
    struct CrossSessionAwareness: Equatable, Sendable {
        let status: String
        let relatedReadStatus: String
        let collisionReadStatus: String
        let relatedAvailability: [[String: String]]
        let collisionAvailability: [[String: String]]
        let relatedSessions: [RelatedSession]
        let collisions: [Collision]
        let relatedOmittedCount: Int
        let collisionOmittedCount: Int

        static let unavailable = CrossSessionAwareness(related: nil, collisions: nil)

        init(related: ProvenanceRelatedSessionResponse?, collisions: ProvenanceArtifactCollisionResponse?) {
            let relatedProjection = related?.projection
            let collisionProjection = collisions?.projection
            self.status = relatedProjection == nil && collisionProjection == nil ? "unavailable" : "available"
            self.relatedReadStatus = relatedProjection.map {
                $0.completeness.status == "complete" && $0.excludedCandidates.isEmpty &&
                    $0.completeness.fields.allSatisfy { $0.status == "observed" } ? "available" : "partial"
            } ?? "unavailable"
            self.collisionReadStatus = collisionProjection.map {
                $0.completeness.status == "complete" && $0.excludedCandidates.isEmpty &&
                    $0.completeness.fields.allSatisfy { $0.status == "observed" } ? "available" : "partial"
            } ?? "unavailable"
            self.relatedAvailability = (relatedProjection?.completeness.fields ?? []).map {
                var item = ["field": $0.field, "status": $0.status]
                item["reason"] = $0.reason
                return item
            }
            self.collisionAvailability = (collisionProjection?.completeness.fields ?? []).map {
                var item = ["field": $0.field, "status": $0.status]
                item["reason"] = $0.reason
                return item
            }
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
                "relatedAvailability": relatedAvailability,
                "collisionAvailability": collisionAvailability,
                "relatedSessions": relatedSessions.map(\.bridgePayload),
                "collisions": collisions.map(\.bridgePayload),
                "relatedOmittedCount": relatedOmittedCount,
                "collisionOmittedCount": collisionOmittedCount
            ]
        }
    }
}
