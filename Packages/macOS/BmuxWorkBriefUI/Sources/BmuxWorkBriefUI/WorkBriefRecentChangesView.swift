import BmuxWorkBrief
import SwiftUI

/// Current source-backed changes since the last viewed brief.
public struct WorkBriefRecentChangesView: View {
    /// Current immutable source facts.
    public let snapshot: WorkBriefSnapshot
    /// Metadata from the prior viewed brief, if still valid.
    public let previousBrief: WorkBriefBaseline?
    /// User-triggered workspace selection capability.
    public let jump: @MainActor (UUID, UUID) -> Bool
    /// User-triggered surface highlight capability.
    public let highlight: @MainActor (UUID, UUID, String) -> Bool
    /// User-triggered source-link opening capability.
    public let openURL: @MainActor (URL) -> Void

    /// Creates the recent-changes section from current facts and a saved baseline.
    /// - Parameters:
    ///   - snapshot: Current immutable source facts.
    ///   - previousBrief: Metadata from the previous viewed brief.
    ///   - jump: Host-validated workspace selection action.
    ///   - highlight: Host-validated surface highlight action.
    ///   - openURL: Source URL action invoked only by a user click.
    public init(snapshot: WorkBriefSnapshot, previousBrief: WorkBriefBaseline?,
                jump: @escaping @MainActor (UUID, UUID) -> Bool,
                highlight: @escaping @MainActor (UUID, UUID, String) -> Bool,
                openURL: @escaping @MainActor (URL) -> Void) {
        self.snapshot = snapshot
        self.previousBrief = previousBrief
        self.jump = jump
        self.highlight = highlight
        self.openURL = openURL
    }

    /// The source-backed recent-changes section.
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "workBrief.recentChanges", defaultValue: "Recent changes"))
                .font(.title2.bold())
            if let previousBrief {
                let changes = previousBrief.changes(in: snapshot)
                Text(String(localized: "workBrief.changesSince", defaultValue: "Since your previous brief"))
                    .font(.caption).foregroundStyle(.secondary)
                if changes.coverageLimited {
                    Text(String(localized: "workBrief.changesLimited", defaultValue:
                        "Only part of the previous brief can be compared. Other changes may be missing."))
                        .foregroundStyle(.secondary)
                } else if changes.localIDs.isEmpty && changes.externalIDs.isEmpty {
                    Text(String(localized: "workBrief.noRecentChanges", defaultValue:
                        "No verified changes in the available sources."))
                        .foregroundStyle(.secondary)
                }
                let localIDs = Set(changes.localIDs)
                ForEach(snapshot.localWorkspaces.filter { localIDs.contains($0.id) }) { item in
                    WorkBriefWorkspaceRow(item: item, jump: jump, highlight: highlight,
                                          openURL: openURL)
                }
                let externalIDs = Set(changes.externalIDs)
                let projection = WorkBriefProjection(snapshot: snapshot)
                ForEach(snapshot.externalItems.filter { externalIDs.contains($0.id) }) { item in
                    let related = Set(projection.relatedWorkspaceIDs[item.id] ?? [])
                    WorkBriefExternalRow(item: item,
                        relatedWorkspaces: snapshot.localWorkspaces.filter { related.contains($0.id) },
                        relationshipEvidenceByWorkspaceID:
                            projection.relationshipEvidenceByExternalID[item.id] ?? [:],
                        health: item.source == .linear ? snapshot.linearHealth : snapshot.githubHealth,
                        hasConflict: projection.conflictingExternalIDs.contains(item.id),
                        jump: jump, openURL: openURL)
                }
            } else {
                Text(String(localized: "workBrief.changesUnavailable", defaultValue:
                    "A previous brief is needed to show changes."))
                    .foregroundStyle(.secondary)
            }
        }
    }}
