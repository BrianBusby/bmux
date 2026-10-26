import BmuxWorkBrief
import SwiftUI

/// On-demand questions over the same immutable source facts shown in the brief.
public struct WorkBriefAskView: View {
    /// Current bounded source snapshot.
    public let snapshot: WorkBriefSnapshot
    /// Validated user-clicked local navigation.
    public let jump: @MainActor (UUID, UUID) -> Bool
    /// Validated user-clicked surface highlight.
    public let highlight: @MainActor (UUID, UUID, String) -> Bool
    /// Explicit source URL opening.
    public let openURL: @MainActor (URL) -> Void

    @State private var question = ""
    @State private var answer: WorkBriefAnswer?

    /// Creates an on-demand fact question view without retaining question history.
    public init(snapshot: WorkBriefSnapshot, jump: @escaping @MainActor (UUID, UUID) -> Bool,
                highlight: @escaping @MainActor (UUID, UUID, String) -> Bool,
                openURL: @escaping @MainActor (URL) -> Void) {
        self.snapshot = snapshot
        self.jump = jump
        self.highlight = highlight
        self.openURL = openURL
    }

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
                        health: item.source == .linear ? snapshot.linearHealth : snapshot.githubHealth,
                        hasConflict: projection.conflictingExternalIDs.contains(item.id),
                        jump: jump, openURL: openURL)
                }
            }
        }
        .onChange(of: snapshot) { _, updated in
            if answer != nil { answer = WorkBriefQuestionAnswerer().answer(question, snapshot: updated) }
        }
    }

    private func ask() {
        answer = WorkBriefQuestionAnswerer().answer(question, snapshot: snapshot)
    }

    private func answerLabel(_ answer: WorkBriefAnswer) -> String {
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
        case .ticketPullRequest:
            String(localized: "workBrief.askTicketPR", defaultValue:
                "This pull request is linked to the ticket by accepted local provenance.")
        case .noEvidence:
            String(localized: "workBrief.askNoEvidence", defaultValue:
                "No explicit ticket-to-PR link was found. Include the ticket ID and refresh the brief.")
        case .unsupported:
            String(localized: "workBrief.askUnsupported", defaultValue:
                "Try asking about attention, work in progress, waiting, or a ticket's PR.")
        }
    }
}
