/// A bounded token-usage summary from the live execution telemetry projection.
public struct ExecutionTelemetryLiveUsageSummary: Sendable, Equatable, Codable {
    /// Provider turn id the usage belongs to, when the provider exposes one.
    public let turnID: String?

    /// Provider-reported input token count.
    public let inputTokens: Int?

    /// Provider-reported cached input token count.
    public let cachedInputTokens: Int?

    /// Provider-reported output token count.
    public let outputTokens: Int?

    /// Provider-reported reasoning output token count.
    public let reasoningOutputTokens: Int?

    /// Provider-reported total token count.
    public let totalTokens: Int?

    /// Provider-reported model context window size.
    public let contextWindowTokens: Int?

    /// Provider model name associated with the usage observation.
    public let model: String?

    /// Sidecar capture timestamp, in Unix epoch milliseconds, for this usage observation.
    public let observedAtMs: Int

    /// Creates a live usage summary.
    public init(
        turnID: String? = nil,
        inputTokens: Int? = nil,
        cachedInputTokens: Int? = nil,
        outputTokens: Int? = nil,
        reasoningOutputTokens: Int? = nil,
        totalTokens: Int? = nil,
        contextWindowTokens: Int? = nil,
        model: String? = nil,
        observedAtMs: Int
    ) {
        self.turnID = turnID
        self.inputTokens = inputTokens
        self.cachedInputTokens = cachedInputTokens
        self.outputTokens = outputTokens
        self.reasoningOutputTokens = reasoningOutputTokens
        self.totalTokens = totalTokens
        self.contextWindowTokens = contextWindowTokens
        self.model = model
        self.observedAtMs = observedAtMs
    }

    private enum CodingKeys: String, CodingKey {
        case turnID = "turnId"
        case inputTokens
        case cachedInputTokens
        case outputTokens
        case reasoningOutputTokens
        case totalTokens
        case contextWindowTokens
        case model
        case observedAtMs
    }
}
