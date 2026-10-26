import BmuxWorkBrief
import SwiftUI

/// One immutable external card with source evidence and validated local navigation.
public struct WorkBriefExternalRow: View {
    /// Provider-backed facts to display.
    public let item: WorkBriefExternalItem
    /// Workspaces related through exact accepted source links.
    public let relatedWorkspaces: [WorkBriefLocalWorkspace]
    /// Bmux-inferred exact-link relationships keyed by stable workspace ID.
    public let relationshipEvidenceByWorkspaceID: [UUID: WorkBriefEvidence]
    /// Health of the latest provider refresh.
    public let health: WorkBriefSourceHealth
    /// Whether accepted PE status conflicts with the provider's open PR result.
    public let hasConflict: Bool
    /// Selects a still-live workspace on a user click.
    public let jump: @MainActor (UUID, UUID) -> Bool
    /// Opens a provider URL on a user click.
    public let openURL: @MainActor (URL) -> Void

    @State private var targetMissing = false

    /// Creates a source card from immutable snapshot values and typed actions.
    /// - Parameters:
    ///   - item: The provider-backed work item.
    ///   - relatedWorkspaces: Exactly related local workspace snapshots.
    ///   - relationshipEvidenceByWorkspaceID: The inferred exact-link basis for each Jump target.
    ///   - health: Latest health of the item's provider.
    ///   - hasConflict: Whether local PE and provider PR status disagree.
    ///   - jump: Host-validated workspace selection on user click.
    ///   - openURL: Source URL opening on user click.
    public init(item: WorkBriefExternalItem, relatedWorkspaces: [WorkBriefLocalWorkspace],
                relationshipEvidenceByWorkspaceID: [UUID: WorkBriefEvidence],
                health: WorkBriefSourceHealth, hasConflict: Bool,
                jump: @escaping @MainActor (UUID, UUID) -> Bool,
                openURL: @escaping @MainActor (URL) -> Void) {
        self.item = item
        self.relatedWorkspaces = Array(relatedWorkspaces.prefix(3))
        self.relationshipEvidenceByWorkspaceID = relationshipEvidenceByWorkspaceID
        self.health = health
        self.hasConflict = hasConflict
        self.jump = jump
        self.openURL = openURL
    }

    /// Renders provider facts, source links, and user-invoked navigation.
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.title).font(.headline)
                Spacer()
                Text(item.source.displayName).font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Text(item.reference)
                Text(statusLabel)
                if let repository = item.repository { Text(repository) }
            }
            .font(.caption).foregroundStyle(.secondary)
            if let owner = item.owner {
                Text(String(localized: "workBrief.owner", defaultValue: "Owner") + ": " + owner)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Button(String(localized: "workBrief.openSource", defaultValue: "Open source")) {
                openURL(item.url)
            }
            .buttonStyle(.bordered)
            ForEach(relatedWorkspaces) { workspace in
                if let relationship = relationshipEvidenceByWorkspaceID[workspace.id] {
                    HStack(spacing: 8) {
                        Button(String(localized: "workBrief.jump", defaultValue: "Jump to workspace") +
                               " · " + workspace.title) {
                            targetMissing = !jump(workspace.id, workspace.runtimeID)
                        }
                        .buttonStyle(.bordered)
                        Text(String(localized: "workBrief.inferred", defaultValue: "Inferred") +
                             " · " + relationshipLabel(relationship.field))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if targetMissing {
                Text(String(localized: "workBrief.targetMissing", defaultValue:
                    "That workspace or surface is no longer available. Refresh the brief."))
                    .font(.caption).foregroundStyle(.orange)
            }
            DisclosureGroup(String(localized: "workBrief.whyHere", defaultValue: "Why is this here?")) {
                ForEach(relatedWorkspaces) { workspace in
                    if let relationship = relationshipEvidenceByWorkspaceID[workspace.id] {
                        HStack {
                            Text(workspace.title + " · " + relationshipLabel(relationship.field))
                            Text(String(localized: "workBrief.inferred", defaultValue: "Inferred"))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(relationship.checkedAt, style: .relative)
                        }
                        .font(.caption)
                        if let referenceID = relationship.referenceID {
                            Text(String(localized: "workBrief.eventID", defaultValue: "Evidence event") +
                                 " " + referenceID)
                                .font(.caption2).textSelection(.enabled)
                        }
                        if let url = relationship.url {
                            Button(String(localized: "workBrief.openSource", defaultValue: "Open source")) {
                                openURL(url)
                            }
                            .font(.caption)
                        }
                    }
                }
                ForEach(item.evidence) { evidence in
                    HStack {
                        Text(evidenceLabel(evidence.field))
                        Text(evidence.isObserved
                             ? String(localized: "workBrief.observed", defaultValue: "Observed")
                             : String(localized: "workBrief.inferred", defaultValue: "Inferred"))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(evidence.checkedAt, style: .relative)
                    }
                    .font(.caption)
                    if let url = evidence.url {
                        Button(String(localized: "workBrief.openSource", defaultValue: "Open source")) {
                            openURL(url)
                        }
                        .font(.caption)
                    }
                }
            }
            .font(.caption)
            if hasConflict {
                Text(String(localized: "workBrief.sourceConflict", defaultValue:
                    "Local provenance and GitHub disagree on this pull request's status."))
                    .font(.caption).foregroundStyle(.orange)
            }
            if health.state != .available {
                Text(String(localized: "workBrief.sourceStale", defaultValue:
                    "Source refresh was incomplete; this item may be stale."))
                    .font(.caption).foregroundStyle(.orange)
            }
            HStack(spacing: 4) {
                Text(String(localized: "workBrief.checked", defaultValue: "Checked"))
                Text(item.checkedAt, style: .relative)
            }
            .font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
    }

    private var statusLabel: String {
        if item.source == .github {
            switch item.status {
            case "open": return String(localized: "workBrief.githubOpen", defaultValue: "Open")
            case "review_requested":
                return String(localized: "workBrief.awaitingReview", defaultValue: "Awaiting review")
            default: break
            }
        }
        return item.status
    }

    private func relationshipLabel(_ field: String) -> String {
        switch field {
        case "ticketLinkMatch":
            String(localized: "workBrief.ticketLinkMatch", defaultValue: "Matching ticket ID")
        case "pullRequestURLMatch":
            String(localized: "workBrief.pullRequestURLMatch", defaultValue: "Matching pull request URL")
        default:
            String(localized: "workBrief.evidenceOther", defaultValue: "Source fact")
        }
    }

    private func evidenceLabel(_ field: String) -> String {
        switch field {
        case "assignedIssue":
            String(localized: "workBrief.assignedIssue", defaultValue: "Assigned to you in Linear")
        case "reviewRequested":
            String(localized: "workBrief.reviewRequested", defaultValue: "Your review was requested")
        case "authored":
            String(localized: "workBrief.authoredPR", defaultValue: "You authored this pull request")
        case "awaitingReview":
            String(localized: "workBrief.reviewersRequested", defaultValue: "Reviewers were requested")
        default:
            String(localized: "workBrief.evidenceOther", defaultValue: "Source fact")
        }
    }
}
