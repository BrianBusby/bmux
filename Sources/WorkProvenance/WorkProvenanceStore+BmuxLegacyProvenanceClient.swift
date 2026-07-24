import Foundation

extension WorkProvenanceStore: BmuxLegacyProvenanceClient {
    func appendEvent(_ request: ProvenanceAppendEventRequest) async throws -> ProvenanceAppendEventResponse {
        try append(request.event)
        return ProvenanceAppendEventResponse(
            eventID: request.event.id,
            eventType: request.event.eventType.rawValue
        )
    }

    func currentContext(_ request: ProvenanceCurrentContextRequest) async throws
        -> ProvenanceCurrentContextResponse {
        try currentContext(
            repositoryPath: request.repositoryPath,
            activeSessionLimit: request.activeSessionLimit,
            dirtyFileLimit: request.dirtyFileLimit,
            unattributedChangeLimit: request.unattributedChangeLimit,
            recentCheckpointLimit: request.recentCheckpointLimit,
            validationRunLimit: request.validationRunLimit,
            conflictLimit: request.conflictLimit
        )
    }
}
