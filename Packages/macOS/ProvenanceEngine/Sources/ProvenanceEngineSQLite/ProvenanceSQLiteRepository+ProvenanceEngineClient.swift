import Foundation
import ProvenanceEngineContracts

extension ProvenanceSQLiteRepository: ProvenanceEngineClient {
    private static let engineVersion = "0.1.0"

    func health() async throws -> ProvenanceEngineHealth {
        _ = try schemaVersion()
        return ProvenanceEngineHealth(
            status: .available,
            version: Self.engineVersion,
            capabilities: ProvenanceEngineCapability.allCases
        )
    }

    func appendEvent(_ request: ProvenanceAppendEventRequest) async throws -> ProvenanceAppendEventResponse {
        try appendEvent(request.event)
        return ProvenanceAppendEventResponse(
            eventID: request.event.id,
            eventType: request.event.eventType.rawValue
        )
    }

    func turnOutcome(_ request: ProvenanceTurnOutcomeRequest) async throws
        -> ProvenanceTurnOutcomeResponse {
        try turnOutcomeRecord(request)
    }

    func sessionOutcome(_ request: ProvenanceSessionOutcomeRequest) async throws
        -> ProvenanceSessionOutcomeResponse {
        try sessionOutcomeRecord(request)
    }

    func relatedSessions(_ request: ProvenanceRelatedSessionRequest) async throws
        -> ProvenanceRelatedSessionResponse {
        try relatedSessionRecord(request)
    }

    func artifactCollisions(_ request: ProvenanceArtifactCollisionRequest) async throws
        -> ProvenanceArtifactCollisionResponse {
        try artifactCollisionRecord(request)
    }

    func publishSemanticInference(_ request: ProvenanceSemanticInferencePublishRequest) async throws
        -> ProvenanceSemanticInferencePublishResponse {
        try publishSemanticInferenceRecord(request)
    }

    func semanticInferences(_ request: ProvenanceSemanticInferenceQueryRequest) async throws
        -> ProvenanceSemanticInferenceQueryResponse {
        try semanticInferenceRecords(request)
    }

    func publishSemanticMessage(_ request: ProvenanceSemanticMessagePublishRequest) async throws
        -> ProvenanceSemanticMessagePublishResponse {
        try publishSemanticMessageRecord(request)
    }

    func semanticMessages(_ request: ProvenanceSemanticMessageQueryRequest) async throws
        -> ProvenanceSemanticMessageQueryResponse {
        try semanticMessageRecords(request)
    }

    func sessionWorkModel(_ request: ProvenanceSessionWorkModelRequest) async throws
        -> ProvenanceSessionWorkModelResponse {
        try sessionWorkModelSnapshot(request)
    }
}
