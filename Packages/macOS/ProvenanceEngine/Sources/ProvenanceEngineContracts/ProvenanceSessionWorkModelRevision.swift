import Foundation

/// Revision components for one SessionWorkModel materialization.
public struct ProvenanceSessionWorkModelRevision: Codable, Equatable, Sendable {
    /// Schema version for the materialized model contract.
    public let schemaVersion: Int

    /// Factual projection revision used as input.
    public let factualRevision: Int?

    /// Active semantic inference IDs selected into the model, in stable order.
    public let semanticInferenceIDs: [String]

    /// Creation timestamp of the newest selected semantic inference.
    public let latestSemanticInferenceCreatedAt: Date?

    /// Stable reconciliation key for the current materialized inputs.
    public let modelRevisionKey: String

    /// Creates revision metadata.
    ///
    /// - Parameters:
    ///   - schemaVersion: Schema version for the materialized model contract.
    ///   - factualRevision: Factual projection revision used as input.
    ///   - semanticInferenceIDs: Active semantic inference IDs selected into the model.
    ///   - latestSemanticInferenceCreatedAt: Creation timestamp of the newest selected semantic inference.
    public init(
        schemaVersion: Int = 2,
        factualRevision: Int?,
        semanticInferenceIDs: [String],
        latestSemanticInferenceCreatedAt: Date?
    ) {
        self.schemaVersion = schemaVersion
        self.factualRevision = factualRevision
        self.semanticInferenceIDs = semanticInferenceIDs
        self.latestSemanticInferenceCreatedAt = latestSemanticInferenceCreatedAt
        self.modelRevisionKey = [
            "schema:\(schemaVersion)",
            "factual:\(factualRevision.map(String.init) ?? "unknown")",
            "semantic:\(semanticInferenceIDs.joined(separator: ","))",
            "semanticLatest:\(latestSemanticInferenceCreatedAt.map(Self.isoString(_:)) ?? "none")",
        ].joined(separator: "|")
    }

    private static func isoString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
