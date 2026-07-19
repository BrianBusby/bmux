/// A compact fact that the same normalized command appeared more than once.
public struct ContextEfficiencyRepeatedCommandFact: Codable, Equatable, Sendable, Identifiable {
    /// Stable fact identifier derived from the thread, kind, and normalized command fingerprint.
    public var id: String
    /// Thread that owns the repeated command fact.
    public var threadID: String
    /// Repetition family for the command.
    public var kind: ContextEfficiencyCommandRepetitionKind
    /// Classified command family shared by the repeated commands.
    public var category: ContextEfficiencyCommandCategory
    /// First executable-like token after leading environment assignments.
    public var normalizedExecutable: String?
    /// Bounded command summary from the first occurrence.
    public var representativeCommandSummary: String
    /// Stable fingerprint of the normalized command text.
    public var normalizedCommandFingerprint: String
    /// Number of matching command executions.
    public var occurrenceCount: Int
    /// First matching command execution identifiers retained as bounded evidence samples.
    public var sampleCommandExecutionIDs: [String]
    /// Source evidence location for the first matching command call.
    public var firstSourceReference: ContextEfficiencySourceReference
    /// Source evidence location for the last matching command call.
    public var lastSourceReference: ContextEfficiencySourceReference

    /// Creates a repeated-command fact.
    ///
    /// - Parameters:
    ///   - id: Stable fact identifier derived from the repeated command group.
    ///   - threadID: Thread that owns the repeated command fact.
    ///   - kind: Repetition family for the command.
    ///   - category: Classified command family shared by the repeated commands.
    ///   - normalizedExecutable: First executable-like token after leading environment assignments.
    ///   - representativeCommandSummary: Bounded command summary from the first occurrence.
    ///   - normalizedCommandFingerprint: Stable fingerprint of the normalized command text.
    ///   - occurrenceCount: Number of matching command executions.
    ///   - sampleCommandExecutionIDs: First matching command execution identifiers retained as bounded evidence samples.
    ///   - firstSourceReference: Source evidence location for the first matching command call.
    ///   - lastSourceReference: Source evidence location for the last matching command call.
    public init(
        id: String,
        threadID: String,
        kind: ContextEfficiencyCommandRepetitionKind,
        category: ContextEfficiencyCommandCategory,
        normalizedExecutable: String?,
        representativeCommandSummary: String,
        normalizedCommandFingerprint: String,
        occurrenceCount: Int,
        sampleCommandExecutionIDs: [String],
        firstSourceReference: ContextEfficiencySourceReference,
        lastSourceReference: ContextEfficiencySourceReference
    ) {
        self.id = id
        self.threadID = threadID
        self.kind = kind
        self.category = category
        self.normalizedExecutable = normalizedExecutable
        self.representativeCommandSummary = representativeCommandSummary
        self.normalizedCommandFingerprint = normalizedCommandFingerprint
        self.occurrenceCount = occurrenceCount
        self.sampleCommandExecutionIDs = sampleCommandExecutionIDs
        self.firstSourceReference = firstSourceReference
        self.lastSourceReference = lastSourceReference
    }
}
