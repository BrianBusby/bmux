import Foundation

/// Identifies the evidence class behind a provenance claim.
public enum ProvenanceSource: String, Codable, CaseIterable, Sendable {
    /// The claim came from Git, the filesystem, process state, or another observed fact.
    case observed

    /// The claim was declared by an agent or integration.
    case declared

    /// The claim was inferred from available evidence.
    case inferred

    /// The claim reconciles observed and declared evidence.
    case reconciled

    /// The claim explicitly has no attributable source.
    case unattributed
}
