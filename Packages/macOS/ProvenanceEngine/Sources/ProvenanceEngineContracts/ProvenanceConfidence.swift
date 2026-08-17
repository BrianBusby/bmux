import Foundation

/// Describes how reliable a provenance claim is.
public enum ProvenanceConfidence: String, Codable, CaseIterable, Sendable {
    /// The claim is strongly supported by observed or confirmed evidence.
    case high

    /// The claim is supported but not fully certain.
    case medium

    /// The claim is plausible but weakly supported.
    case low

    /// No useful confidence level is available yet.
    case unknown
}
