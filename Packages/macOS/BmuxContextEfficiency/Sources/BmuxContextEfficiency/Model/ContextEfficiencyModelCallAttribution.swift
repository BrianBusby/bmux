/// Candidate link from a command output to a later model call.
public struct ContextEfficiencyModelCallAttribution: Codable, Equatable, Sendable {
    /// Model-call record that may have consumed the command output.
    public var modelCallID: String
    /// Confidence for the model-call attribution.
    public var confidence: ContextEfficiencyAttributionConfidence
    /// Source evidence for the attributed model call.
    public var modelCallSourceReference: ContextEfficiencySourceReference

    /// Creates a model-call attribution.
    ///
    /// - Parameters:
    ///   - modelCallID: Model-call record that may have consumed the command output.
    ///   - confidence: Confidence for the attribution.
    ///   - modelCallSourceReference: Source evidence for the attributed model call.
    public init(
        modelCallID: String,
        confidence: ContextEfficiencyAttributionConfidence,
        modelCallSourceReference: ContextEfficiencySourceReference
    ) {
        self.modelCallID = modelCallID
        self.confidence = confidence
        self.modelCallSourceReference = modelCallSourceReference
    }
}
