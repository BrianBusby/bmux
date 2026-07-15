public import Foundation

/// Compact thread metadata read from Codex's local state database.
///
/// This type intentionally stores metadata fields only. Rollout JSONL evidence
/// remains in its original file and is referenced by path during import.
public struct CodexStateThreadMetadata: Codable, Equatable, Sendable, Identifiable {
    /// External Codex thread identifier.
    public var id: String
    /// Stable bmux context-efficiency thread identifier.
    public var normalizedThreadID: String
    /// Rollout JSONL path recorded by Codex, when present.
    public var rolloutPath: String?
    /// Working directory recorded for the thread.
    public var cwd: String?
    /// User-visible title recorded by Codex, when present.
    public var title: String?
    /// Preview text recorded by Codex, when present.
    public var preview: String?
    /// First user message recorded by Codex, when present.
    public var firstUserMessage: String?
    /// Model provider recorded by Codex, when present.
    public var modelProvider: String?
    /// Model recorded by Codex, when present.
    public var model: String?
    /// Reasoning effort recorded by Codex, when present.
    public var reasoningEffort: String?
    /// Approval mode recorded by Codex, when present.
    public var approvalMode: String?
    /// Sandbox policy type decoded from Codex metadata, when present.
    public var sandboxPolicyType: String?
    /// Git branch recorded by Codex, when present.
    public var gitBranch: String?
    /// Git origin URL recorded by Codex, when present.
    public var gitOriginURL: String?
    /// Codex CLI version recorded by Codex, when present.
    public var cliVersion: String?
    /// Lifetime token total recorded by Codex metadata, when present.
    public var tokensUsed: Int64?
    /// Codex source label, when present.
    public var source: String?
    /// Thread creation timestamp, when present.
    public var createdAt: Date?
    /// Thread update timestamp, when present.
    public var updatedAt: Date?

    /// Creates a compact Codex state thread metadata row.
    public init(
        id: String,
        normalizedThreadID: String,
        rolloutPath: String?,
        cwd: String?,
        title: String?,
        preview: String?,
        firstUserMessage: String?,
        modelProvider: String?,
        model: String?,
        reasoningEffort: String?,
        approvalMode: String?,
        sandboxPolicyType: String?,
        gitBranch: String?,
        gitOriginURL: String?,
        cliVersion: String?,
        tokensUsed: Int64?,
        source: String?,
        createdAt: Date?,
        updatedAt: Date?
    ) {
        self.id = id
        self.normalizedThreadID = normalizedThreadID
        self.rolloutPath = rolloutPath
        self.cwd = cwd
        self.title = title
        self.preview = preview
        self.firstUserMessage = firstUserMessage
        self.modelProvider = modelProvider
        self.model = model
        self.reasoningEffort = reasoningEffort
        self.approvalMode = approvalMode
        self.sandboxPolicyType = sandboxPolicyType
        self.gitBranch = gitBranch
        self.gitOriginURL = gitOriginURL
        self.cliVersion = cliVersion
        self.tokensUsed = tokensUsed
        self.source = source
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
