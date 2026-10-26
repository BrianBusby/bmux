import BmuxWorkBrief
import SwiftUI

/// One immutable external card with source evidence and validated local navigation.
public struct WorkBriefExternalRow: View {
    /// Provider-backed facts to display.
    public let item: WorkBriefExternalItem
    /// Workspaces related through exact accepted source links.
    public let relatedWorkspaces: [WorkBriefLocalWorkspace]
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
    public init(item: WorkBriefExternalItem, relatedWorkspaces: [WorkBriefLocalWorkspace],
                health: WorkBriefSourceHealth, hasConflict: Bool,
                jump: @escaping @MainActor (UUID, UUID) -> Bool,
                openURL: @escaping @MainActor (URL) -> Void) {
        self.item = item
        self.relatedWorkspaces = Array(relatedWorkspaces.prefix(3))
        self.health = health
        self.hasConflict = hasConflict
        self.jump = jump
        self.openURL = openURL
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.title).font(.headline)
                Spacer()
                Text(sourceLabel).font(.caption).foregroundStyle(.secondary)
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
            HStack {
                Button(String(localized: "workBrief.openSource", defaultValue: "Open source")) {
                    openURL(item.url)
                }
                .buttonStyle(.bordered)
                ForEach(relatedWorkspaces) { workspace in
                    Button(String(localized: "workBrief.jump", defaultValue: "Jump to workspace") +
                           " · " + workspace.title) {
                        targetMissing = !jump(workspace.id, workspace.runtimeID)
                    }
                    .buttonStyle(.bordered)
                }
            }
            if targetMissing {
                Text(String(localized: "workBrief.targetMissing", defaultValue:
                    "That workspace or surface is no longer available. Refresh the brief."))
                    .font(.caption).foregroundStyle(.orange)
            }
            DisclosureGroup(String(localized: "workBrief.whyHere", defaultValue: "Why is this here?")) {
                ForEach(item.evidence) { evidence in
                    HStack {
                        Text(evidenceLabel(evidence.field))
                        Text(String(localized: "workBrief.observed", defaultValue: "Observed"))
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

    private var sourceLabel: String {
        switch item.source {
        case .github: "GitHub"
        case .linear: "Linear"
        case .bmux: "bmux"
        case .provenanceEngine: "Provenance Engine"
        case .slack: "Slack"
        }
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
