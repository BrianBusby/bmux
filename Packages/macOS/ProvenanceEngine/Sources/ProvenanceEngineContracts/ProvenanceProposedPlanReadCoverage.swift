/// Coverage of this bounded ledger read, not of upstream provider emission.
public struct ProvenanceProposedPlanReadCoverage: Codable, Equatable, Sendable {
    /// Whether the ledger scan window was truncated.
    public let scanWindowTruncated: Bool
    /// Whether matching observations were omitted from the result.
    public let omittedObservations: Bool

    /// Creates a description of the bounded ledger read.
    /// - Parameters:
    ///   - scanWindowTruncated: Whether the ledger scan window was truncated.
    ///   - omittedObservations: Whether matching observations were omitted.
    public init(scanWindowTruncated: Bool, omittedObservations: Bool) {
        self.scanWindowTruncated = scanWindowTruncated
        self.omittedObservations = omittedObservations
    }
}
