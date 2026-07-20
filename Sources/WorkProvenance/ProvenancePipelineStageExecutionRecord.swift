import Foundation

/// One bounded observability record for a stage within a provenance pipeline run.
struct ProvenancePipelineStageExecutionRecord: Equatable, Sendable {
    let pipelineRunID: String
    let stageName: String
    let stageVersion: String
    let status: String
    let startedAt: Date
    let endedAt: Date
    let inputCount: Int
    let outputCount: Int
    let errorCount: Int
    let errorSummary: String?

    var stageExecutionID: String {
        "\(pipelineRunID):\(stageName)"
    }

    var durationMilliseconds: Double {
        max(0, endedAt.timeIntervalSince(startedAt) * 1_000)
    }
}
