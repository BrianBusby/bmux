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

    func publishSemanticInference(_ request: ProvenanceSemanticInferencePublishRequest) async throws
        -> ProvenanceSemanticInferencePublishResponse {
        try publishSemanticInferenceRecord(request)
    }

    func semanticInferences(_ request: ProvenanceSemanticInferenceQueryRequest) async throws
        -> ProvenanceSemanticInferenceQueryResponse {
        try semanticInferenceRecords(request)
    }
}
