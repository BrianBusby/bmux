import BmuxWorkBrief
import SwiftUI

/// One immutable local work card with explicit navigation actions.
public struct WorkBriefWorkspaceRow: View {
    /// Source-backed workspace facts.
    public let item: WorkBriefLocalWorkspace
    /// Selects the live workspace after the host validates it.
    public let jump: @MainActor (UUID, UUID) -> Bool
    /// Highlights an explicitly associated live surface after host validation.
    public let highlight: @MainActor (UUID, UUID, String) -> Bool
    /// Opens an explicit source URL on a user click.
    public let openURL: @MainActor (URL) -> Void

    @State private var targetMissing = false

    /// Creates a work card with typed actions.
    public init(item: WorkBriefLocalWorkspace,
                jump: @escaping @MainActor (UUID, UUID) -> Bool,
                highlight: @escaping @MainActor (UUID, UUID, String) -> Bool,
                openURL: @escaping @MainActor (URL) -> Void) {
        self.item = item
        self.jump = jump
        self.highlight = highlight
        self.openURL = openURL
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.title).font(.headline)
                Spacer()
                Text(statusLabel).font(.caption).foregroundStyle(.secondary)
            }
            if let repository = item.repository {
                Text(repository).font(.subheadline).foregroundStyle(.secondary)
            }
            if let branch = item.branch {
                Text(branch).font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Button(String(localized: "workBrief.jump", defaultValue: "Jump to workspace")) {
                    targetMissing = !jump(item.id, item.runtimeID)
                }
                if let surfaceID = item.surfaceID {
                    Button(String(localized: "workBrief.highlight", defaultValue: "Highlight surface")) {
                        targetMissing = !highlight(item.id, item.runtimeID, surfaceID)
                    }
                }
            }
            .buttonStyle(.bordered)
            if targetMissing {
                Text(String(localized: "workBrief.targetMissing", defaultValue:
                    "That workspace or surface is no longer available. Refresh the brief."))
                    .font(.caption).foregroundStyle(.orange)
            }
            ForEach(item.tickets) { ticket in
                Button(ticket.label) { openURL(ticket.url) }
                    .buttonStyle(.link)
            }
            if let pullRequest = item.pullRequest {
                Button(pullRequest.label) { openURL(pullRequest.url) }
                    .buttonStyle(.link)
            }
            DisclosureGroup(String(localized: "workBrief.whyHere", defaultValue: "Why is this here?")) {
                ForEach(item.evidence) { evidence in
                    HStack {
                        Text(evidenceLabel(evidence.field))
                        Text(evidenceSourceLabel(evidence.source))
                            .foregroundStyle(.secondary)
                        Text(evidence.isObserved
                             ? String(localized: "workBrief.observed", defaultValue: "Observed")
                             : String(localized: "workBrief.suggested", defaultValue: "Suggested"))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(evidence.checkedAt, style: .relative)
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                    if let referenceID = evidence.referenceID {
                        Text(String(localized: "workBrief.eventID", defaultValue: "Evidence event") +
                             " " + referenceID)
                            .font(.caption2).textSelection(.enabled)
                    }
                    if let url = evidence.url {
                        Button(String(localized: "workBrief.openSource", defaultValue: "Open source")) {
                            openURL(url)
                        }
                        .font(.caption)
                    }
                }
            }
            .font(.caption)
            Text(String(localized: "workBrief.sourceLocal", defaultValue: "bmux · Provenance Engine"))
                .font(.caption2).foregroundStyle(.tertiary)
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
        switch item.status {
        case .needsInput: String(localized: "workBrief.needsInput", defaultValue: "Needs input")
        case .error: String(localized: "workBrief.error", defaultValue: "Error")
        case .running: String(localized: "workBrief.running", defaultValue: "Working")
        case .idle: String(localized: "workBrief.idle", defaultValue: "Idle")
        case .disconnected: String(localized: "workBrief.unknownStatus", defaultValue: "Status unknown")
        }
    }

    private func evidenceSourceLabel(_ source: WorkBriefSource) -> String {
        switch source {
        case .bmux: "bmux"
        case .provenanceEngine: "Provenance Engine"
        case .linear: "Linear"
        case .github: "GitHub"
        case .slack: "Slack"
        }
    }

    private func evidenceLabel(_ field: String) -> String {
        switch field {
        case "workspace": String(localized: "workBrief.evidenceWorkspace", defaultValue: "Open workspace")
        case "repository": String(localized: "workBrief.evidenceRepository", defaultValue: "Repository")
        case "branch": String(localized: "workBrief.evidenceBranch", defaultValue: "Branch")
        case "ticket": String(localized: "workBrief.evidenceTicket", defaultValue: "Ticket link")
        case "pullRequest": String(localized: "workBrief.evidencePR", defaultValue: "Pull request link")
        case "surface": String(localized: "workBrief.evidenceSurface", defaultValue: "Agent surface")
        default: String(localized: "workBrief.evidenceOther", defaultValue: "Source fact")
        }
    }
}
