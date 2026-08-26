/// One validation attempt recognized deterministically from command evidence.
public struct ProvenanceTurnOutcomeValidation: Codable, Equatable, Sendable {
    /// Stable validation fact identifier.
    public let id: String

    /// Backing command identifier.
    public let commandID: String

    /// Validation kind.
    public let validationKind: String

    /// Original command text copied from accepted evidence.
    public let command: String

    /// Working directory observed for the validation command, when present.
    public let cwd: String?

    /// Provider command status.
    public let status: String

    /// Process exit code, when observed.
    public let exitCode: Int?

    /// Normalized deterministic result status.
    public let resultStatus: String

    /// Repository/worktree/branch context observed for the validation command.
    public let repositoryBoundary: ProvenanceTurnOutcomeRepositoryBoundary?

    /// Supporting evidence references for this validation attempt.
    public let evidence: [ProvenanceTurnOutcomeEvidenceReference]

    /// Creates a validation-attempt fact.
    public init(
        id: String,
        commandID: String,
        validationKind: String,
        command: String,
        cwd: String?,
        status: String,
        exitCode: Int?,
        resultStatus: String,
        repositoryBoundary: ProvenanceTurnOutcomeRepositoryBoundary?,
        evidence: [ProvenanceTurnOutcomeEvidenceReference]
    ) {
        self.id = id
        self.commandID = commandID
        self.validationKind = validationKind
        self.command = command
        self.cwd = cwd
        self.status = status
        self.exitCode = exitCode
        self.resultStatus = resultStatus
        self.repositoryBoundary = repositoryBoundary
        self.evidence = evidence
    }
}
