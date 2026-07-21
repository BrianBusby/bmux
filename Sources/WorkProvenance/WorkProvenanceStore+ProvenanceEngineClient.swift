import Foundation

extension WorkProvenanceStore: ProvenanceEngineClient {
    func appendEvent(_ request: ProvenanceAppendEventRequest) async throws -> ProvenanceAppendEventResponse {
        try append(request.event)
        return ProvenanceAppendEventResponse(
            eventID: request.event.id,
            eventType: request.event.eventType.rawValue
        )
    }

    func sessionTree(_ request: ProvenanceSessionTreeRequest) async throws -> ProvenanceSessionTreeResponse {
        let currentTree = try sessionTree(rootSessionID: request.rootSessionID, limit: request.limit)
        let sessions = currentTree.sessions
        let includedSessionIDs = Set(sessions.map(\.id))
        let relationships = currentTree.relationships
        let identities = try sessions.flatMap { try externalIdentities(sessionID: $0.id) }
        let found = !sessions.isEmpty || !relationships.isEmpty
        return ProvenanceSessionTreeResponse(
            rootSessionID: request.rootSessionID,
            found: found,
            reason: found ? nil : "no_session",
            sessions: sessions,
            relationships: relationships.filter { includedSessionIDs.contains($0.sessionID) },
            externalIdentities: identities
        )
    }

    func fileExplanation(_ request: ProvenanceFileExplanationRequest) async throws -> ProvenanceFileExplanationResponse {
        let explanation = try fileExplanation(worktreeID: request.worktreeID, path: request.path)
        return ProvenanceFileExplanationResponse(
            found: explanation != nil,
            reason: explanation == nil ? "no_file" : nil,
            explanation: explanation
        )
    }

    func worktrees(_ request: ProvenanceWorktreeListRequest) async throws -> ProvenanceWorktreeListResponse {
        let entries = try worktreeList(repositoryID: request.repositoryID, limit: request.limit)
        return ProvenanceWorktreeListResponse(worktrees: entries)
    }
}
