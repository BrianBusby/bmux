import BmuxWorkBrief
import SwiftUI

/// On-demand questions over the same immutable source facts shown in the brief.
public struct WorkBriefAskView: View {
    /// Current bounded source snapshot.
    public let snapshot: WorkBriefSnapshot
    /// Metadata from the previous viewed brief, when available.
    public let previousBrief: WorkBriefBaseline?
    /// Validated user-clicked local navigation.
    public let jump: @MainActor (UUID, UUID) -> Bool
    /// Validated user-clicked surface highlight.
    public let highlight: @MainActor (UUID, UUID, String) -> Bool
    /// Explicit source URL opening.
    public let openURL: @MainActor (URL) -> Void

    @State private var question = ""
    @State private var submittedQuestion: String?
    @State private var answer: WorkBriefAnswer?

    /// Creates an on-demand fact question view without retaining question history.
    /// - Parameters:
    ///   - snapshot: Bounded source facts visible in the brief.
    ///   - previousBrief: Metadata from the previous viewed brief, if available.
    ///   - jump: Host-validated local workspace selection on user request.
    ///   - highlight: Host-validated surface flash on user request.
    ///   - openURL: Source URL opening on user request.
    public init(snapshot: WorkBriefSnapshot, previousBrief: WorkBriefBaseline? = nil,
                jump: @escaping @MainActor (UUID, UUID) -> Bool,
                highlight: @escaping @MainActor (UUID, UUID, String) -> Bool,
                openURL: @escaping @MainActor (URL) -> Void) {
        self.snapshot = snapshot
        self.previousBrief = previousBrief
        self.jump = jump
        self.highlight = highlight
        self.openURL = openURL
    }

    /// Shows the question field and source-backed answer rows.
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "workBrief.ask", defaultValue: "Ask"))
                .font(.title2.bold())
            HStack {
                TextField(String(localized: "workBrief.askPlaceholder", defaultValue:
                    "What needs my attention?"), text: $question)
                    .onSubmit { ask() }
                Button(String(localized: "workBrief.askButton", defaultValue: "Ask")) { ask() }
                    .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if let answer {
                Text(answerLabel(answer)).font(.subheadline)
                ForEach(answer.links) { link in
                    Button(link.label) { openURL(link.url) }.buttonStyle(.link)
                }
                let local = Set(answer.localIDs)
                ForEach(snapshot.localWorkspaces.filter { local.contains($0.id) }) { item in
                    WorkBriefWorkspaceRow(item: item, jump: jump, highlight: highlight,
                                          openURL: openURL)
                }
                let external = Set(answer.externalIDs)
                let projection = WorkBriefProjection(snapshot: snapshot)
                ForEach(snapshot.externalItems.filter { external.contains($0.id) }) { item in
                    let related = Set(projection.relatedWorkspaceIDs[item.id] ?? [])
                    WorkBriefExternalRow(item: item,
                        relatedWorkspaces: snapshot.localWorkspaces.filter { related.contains($0.id) },
                        relationshipEvidenceByWorkspaceID:
                            projection.relationshipEvidenceByExternalID[item.id] ?? [:],
                        health: item.source == .linear ? snapshot.linearHealth : snapshot.githubHealth,
                        hasConflict: projection.conflictingExternalIDs.contains(item.id),
                        jump: jump, openURL: openURL)
                }
            }
        }
        .onChange(of: snapshot) { _, updated in
            if let submittedQuestion {
                answer = WorkBriefQuestionAnswerer().answer(submittedQuestion, snapshot: updated,
                                                           previousBrief: previousBrief)
            }
        }
    }

    private func ask() {
        let submitted = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !submitted.isEmpty else { return }
        submittedQuestion = submitted
        answer = WorkBriefQuestionAnswerer().answer(submitted, snapshot: snapshot,
                                                   previousBrief: previousBrief)
    }

    private func answerLabel(_ answer: WorkBriefAnswer) -> String {
        if answer.kind == .recentChanges, answer.coverageLimited {
            return String(localized: "workBrief.changesLimited", defaultValue:
                "Only part of the previous brief can be compared. Other changes may be missing.")
        }
        if answer.kind == .recentChanges, answer.localIDs.isEmpty && answer.externalIDs.isEmpty {
            return String(localized: "workBrief.noRecentChanges", defaultValue:
                "No verified changes in the available sources.")
        }
        if answer.localIDs.isEmpty && answer.externalIDs.isEmpty && answer.links.isEmpty,
           answer.kind == .needsAttention || answer.kind == .inProgress || answer.kind == .waitingOn {
            return String(localized: "workBrief.askNoItems", defaultValue:
                "No verified items were found in the available source facts. Check source health above.")
        }
        return switch answer.kind {
        case .needsAttention:
            String(localized: "workBrief.askAttention", defaultValue:
                "These items have verified attention signals in the available sources.")
        case .inProgress:
            String(localized: "workBrief.askInProgress", defaultValue:
                "These items are active in the available sources.")
        case .waitingOn:
            String(localized: "workBrief.askWaiting", defaultValue:
                "These items have an explicit review wait in the available sources.")
        case .recentChanges:
            String(localized: "workBrief.askChanges", defaultValue:
                "These source-backed items changed since your previous brief.")
        case .noPreviousBrief:
            String(localized: "workBrief.changesUnavailable", defaultValue:
                "A previous brief is needed to show changes.")
        case .ticketPullRequest:
            String(localized: "workBrief.askTicketPR", defaultValue:
                "The same workspace has accepted links to this ticket and pull request; their relationship is inferred.")
        case .noEvidence:
            String(localized: "workBrief.askNoEvidence", defaultValue:
                "No accepted workspace contains both this ticket and a pull request. Include the ticket ID and refresh the brief.")
        case .needsReference:
            String(localized: "workBrief.askNeedsReference", defaultValue:
                "Name a visible ticket or pull request, or paste its source URL, to ask why it is waiting.")
        case .noWaitEvidence:
            String(localized: "workBrief.askNoWaitEvidence", defaultValue:
                "No observed waiting reason is available for that item. Open its source for more detail.")
        case .unsupported:
            String(localized: "workBrief.askUnsupported", defaultValue:
                "Try asking about attention, work in progress, waiting, changes, or a ticket's PR.")
        }
    }
}
