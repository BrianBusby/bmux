import Foundation

/// One operational observability record for a provenance pipeline attempt.
struct ProvenancePipelineRunRecord: Codable, Equatable, Sendable {
    let pipelineRunID: String
    let pipelineKind: String
    let triggerSource: String
    let parentSessionID: String?
    let childSessionID: String?
    let lifecycleEventID: String?
    let relationshipSessionID: String?
    let externalIdentityID: String?
    let status: String
    let startedAt: Date
    let endedAt: Date
    let inputCount: Int
    let outputCount: Int
    let errorCount: Int
    let errorSummary: String?
    let implementationVersion: String

    var durationMilliseconds: Double {
        max(0, endedAt.timeIntervalSince(startedAt) * 1_000)
    }
}
