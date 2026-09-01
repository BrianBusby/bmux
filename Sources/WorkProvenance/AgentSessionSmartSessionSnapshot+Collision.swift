import ProvenanceEngineContracts

extension AgentSessionSmartSessionSnapshot {
    struct Collision: Equatable, Sendable {
        let id: String
        let path: String
        let state: String
        let participantSessionIDs: [String]

        init(_ candidate: ProvenanceArtifactCollisionCandidate) {
            id = candidate.id
            path = candidate.artifactIdentity.normalizedPath
            state = candidate.state.rawValue
            participantSessionIDs = candidate.participants.map(\.sessionID)
        }

        var bridgePayload: [String: Any] {
            [
                "id": id,
                "path": path,
                "state": state,
                "participantSessionIds": participantSessionIDs
            ]
        }
    }
}
