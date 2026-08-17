import Foundation

/// Current-state projection for user-facing workspace display metadata.
public struct ProvenanceWorkspaceDisplayRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable projection identifier.
    public let id: String

    /// Client workspace identifier.
    public let workspaceID: String

    /// Linked repository identifier, when known.
    public let repositoryID: String?

    /// Linked worktree identifier, when known.
    public let worktreeID: String?

    /// Current workspace directory, when accepted from deterministic observation.
    public let currentDirectory: String?

    /// Current display title, when explicitly observed.
    public let title: String?

    /// Source of the current display title, such as `user`, `auto_prompt`, or `auto_summary`.
    public let titleSource: String?

    /// Current branch label shown for the workspace, when known.
    public let branch: String?

    /// Current pull request number, when known.
    public let pullRequestNumber: Int?

    /// Current pull request URL, when known.
    public let pullRequestURL: String?

    /// Pull request author's login, when known.
    public let pullRequestOwnerLogin: String?

    /// Pull request author's profile URL, when known.
    public let pullRequestOwnerURL: String?

    /// Current pull request lifecycle status, such as `open`, `merged`, or `closed`.
    public let pullRequestStatus: String?

    /// Pull request head branch, when known.
    public let pullRequestBranch: String?

    /// Whether pull request metadata is known to be stale.
    public let pullRequestIsStale: Bool

    /// Accepted dirty/clean state for the workspace worktree, when known.
    public let isDirty: Bool?

    /// External ticket identifiers linked to the workspace, such as Linear or Jira keys.
    public let ticketIDs: [String]

    /// External ticket links linked to the workspace.
    public let ticketLinks: [ProvenanceWorkspaceDisplayTicketLinkRecord]

    /// External project links linked to the workspace.
    public let projectLinks: [ProvenanceWorkspaceDisplayProjectLinkRecord]

    /// Durable summary of the current work for workspace display, when accepted.
    public let currentWorkSummary: String?

    /// Bounded display text for the last submitted user prompt, when accepted.
    public let lastSubmittedPrompt: String?

    /// Time the last submitted prompt was accepted by the producer, when known.
    public let lastSubmittedPromptSubmittedAt: Date?

    /// Agent session associated with the last submitted prompt, when known.
    public let lastSubmittedPromptSessionID: String?

    /// Field names whose current state was explicitly cleared by accepted evidence.
    public let clearedFields: [String]

    /// Field-level provenance and freshness metadata keyed by stable field name.
    public let fieldMetadata: [String: ProvenanceWorkspaceDisplayFieldMetadataRecord]

    /// Durable event ID whose payload last updated this projection.
    public let latestEventID: String?

    /// Append-order ledger sequence whose payload last updated this projection.
    public let latestEventSequence: Int?

    /// Time the display facts were observed.
    public let observedAt: Date

    /// Last projection update time.
    public let updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case workspaceID
        case repositoryID
        case worktreeID
        case currentDirectory
        case title
        case titleSource
        case branch
        case pullRequestNumber
        case pullRequestURL
        case pullRequestOwnerLogin
        case pullRequestOwnerURL
        case pullRequestStatus
        case pullRequestBranch
        case pullRequestIsStale
        case isDirty
        case ticketIDs
        case ticketLinks
        case projectLinks
        case currentWorkSummary
        case lastSubmittedPrompt
        case lastSubmittedPromptSubmittedAt
        case lastSubmittedPromptSessionID
        case clearedFields
        case fieldMetadata
        case latestEventID
        case latestEventSequence
        case observedAt
        case updatedAt
    }

    /// Creates a workspace display projection record.
    public init(
        id: String,
        workspaceID: String,
        repositoryID: String? = nil,
        worktreeID: String? = nil,
        currentDirectory: String? = nil,
        title: String? = nil,
        titleSource: String? = nil,
        branch: String? = nil,
        pullRequestNumber: Int? = nil,
        pullRequestURL: String? = nil,
        pullRequestOwnerLogin: String? = nil,
        pullRequestOwnerURL: String? = nil,
        pullRequestStatus: String? = nil,
        pullRequestBranch: String? = nil,
        pullRequestIsStale: Bool = false,
        isDirty: Bool? = nil,
        ticketIDs: [String] = [],
        ticketLinks: [ProvenanceWorkspaceDisplayTicketLinkRecord] = [],
        projectLinks: [ProvenanceWorkspaceDisplayProjectLinkRecord] = [],
        currentWorkSummary: String? = nil,
        lastSubmittedPrompt: String? = nil,
        lastSubmittedPromptSubmittedAt: Date? = nil,
        lastSubmittedPromptSessionID: String? = nil,
        clearedFields: [String] = [],
        fieldMetadata: [String: ProvenanceWorkspaceDisplayFieldMetadataRecord] = [:],
        latestEventID: String? = nil,
        latestEventSequence: Int? = nil,
        observedAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.workspaceID = workspaceID
        self.repositoryID = repositoryID
        self.worktreeID = worktreeID
        self.currentDirectory = currentDirectory
        self.title = title
        self.titleSource = titleSource
        self.branch = branch
        self.pullRequestNumber = pullRequestNumber
        self.pullRequestURL = pullRequestURL
        self.pullRequestOwnerLogin = pullRequestOwnerLogin
        self.pullRequestOwnerURL = pullRequestOwnerURL
        self.pullRequestStatus = pullRequestStatus
        self.pullRequestBranch = pullRequestBranch
        self.pullRequestIsStale = pullRequestIsStale
        self.isDirty = isDirty
        self.ticketIDs = ticketIDs
        self.ticketLinks = ticketLinks
        self.projectLinks = projectLinks
        self.currentWorkSummary = currentWorkSummary
        self.lastSubmittedPrompt = lastSubmittedPrompt
        self.lastSubmittedPromptSubmittedAt = lastSubmittedPromptSubmittedAt
        self.lastSubmittedPromptSessionID = lastSubmittedPromptSessionID
        self.clearedFields = clearedFields
        self.fieldMetadata = fieldMetadata
        self.latestEventID = latestEventID
        self.latestEventSequence = latestEventSequence
        self.observedAt = observedAt
        self.updatedAt = updatedAt
    }

    /// Creates a workspace display projection record from stored JSON.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.workspaceID = try container.decode(String.self, forKey: .workspaceID)
        self.repositoryID = try container.decodeIfPresent(String.self, forKey: .repositoryID)
        self.worktreeID = try container.decodeIfPresent(String.self, forKey: .worktreeID)
        self.currentDirectory = try container.decodeIfPresent(String.self, forKey: .currentDirectory)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.titleSource = try container.decodeIfPresent(String.self, forKey: .titleSource)
        self.branch = try container.decodeIfPresent(String.self, forKey: .branch)
        self.pullRequestNumber = try container.decodeIfPresent(Int.self, forKey: .pullRequestNumber)
        self.pullRequestURL = try container.decodeIfPresent(String.self, forKey: .pullRequestURL)
        self.pullRequestOwnerLogin = try container.decodeIfPresent(String.self, forKey: .pullRequestOwnerLogin)
        self.pullRequestOwnerURL = try container.decodeIfPresent(String.self, forKey: .pullRequestOwnerURL)
        self.pullRequestStatus = try container.decodeIfPresent(String.self, forKey: .pullRequestStatus)
        self.pullRequestBranch = try container.decodeIfPresent(String.self, forKey: .pullRequestBranch)
        self.pullRequestIsStale = try container.decode(Bool.self, forKey: .pullRequestIsStale)
        self.isDirty = try container.decodeIfPresent(Bool.self, forKey: .isDirty)
        self.ticketIDs = try container.decodeIfPresent([String].self, forKey: .ticketIDs) ?? []
        self.ticketLinks = try container.decodeIfPresent(
            [ProvenanceWorkspaceDisplayTicketLinkRecord].self,
            forKey: .ticketLinks
        ) ?? []
        self.projectLinks = try container.decodeIfPresent(
            [ProvenanceWorkspaceDisplayProjectLinkRecord].self,
            forKey: .projectLinks
        ) ?? []
        self.currentWorkSummary = try container.decodeIfPresent(String.self, forKey: .currentWorkSummary)
        self.lastSubmittedPrompt = try container.decodeIfPresent(String.self, forKey: .lastSubmittedPrompt)
        self.lastSubmittedPromptSubmittedAt = try container.decodeIfPresent(
            Date.self,
            forKey: .lastSubmittedPromptSubmittedAt
        )
        self.lastSubmittedPromptSessionID = try container.decodeIfPresent(String.self, forKey: .lastSubmittedPromptSessionID)
        self.clearedFields = try container.decodeIfPresent([String].self, forKey: .clearedFields) ?? []
        self.fieldMetadata = try container.decodeIfPresent(
            [String: ProvenanceWorkspaceDisplayFieldMetadataRecord].self,
            forKey: .fieldMetadata
        ) ?? [:]
        self.latestEventID = try container.decodeIfPresent(String.self, forKey: .latestEventID)
        self.latestEventSequence = try container.decodeIfPresent(Int.self, forKey: .latestEventSequence)
        self.observedAt = try container.decode(Date.self, forKey: .observedAt)
        self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}
