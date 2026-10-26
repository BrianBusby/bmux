import Foundation

/// Answers supported work questions from one bounded immutable source snapshot.
public struct WorkBriefQuestionAnswerer: Sendable {
    /// Creates a stateless answerer.
    public init() {}

    /// Returns source-backed item IDs and links; question text is never stored.
    public func answer(_ question: String, snapshot: WorkBriefSnapshot) -> WorkBriefAnswer {
        let normalized = question.lowercased()
        let projection = WorkBriefProjection(snapshot: snapshot)
        if normalized.contains("pull request") || normalized.contains("pr ") || normalized.contains("pr?") {
            let tokens = Set(normalized.split { !$0.isLetter && !$0.isNumber && $0 != "-" }
                .map(String.init))
            let mentionedTicketIDs = snapshot.localWorkspaces.flatMap(\.tickets).map(\.id)
                .filter { tokens.contains($0.lowercased()) }
            let matches = snapshot.localWorkspaces.filter { workspace in
                workspace.tickets.contains { mentionedTicketIDs.contains($0.id) }
            }
            let links = matches.compactMap(\.pullRequest)
            return WorkBriefAnswer(kind: links.isEmpty ? .noEvidence : .ticketPullRequest,
                localIDs: matches.map(\.id), links: links)
        }
        if normalized.contains("wait") || normalized.contains("block") {
            return WorkBriefAnswer(kind: .waitingOn,
                externalIDs: projection.externalWaitingOn.map(\.id))
        }
        if normalized.contains("attention") || normalized.contains("need") || normalized.contains("review") {
            return WorkBriefAnswer(kind: .needsAttention,
                localIDs: projection.needsAttention.map(\.id),
                externalIDs: projection.externalNeedsAttention.map(\.id))
        }
        if normalized.contains("progress") || normalized.contains("working") || normalized.contains("worked on") {
            return WorkBriefAnswer(kind: .inProgress,
                localIDs: projection.inProgress.map(\.id),
                externalIDs: projection.externalInProgress.map(\.id))
        }
        return WorkBriefAnswer(kind: .unsupported)
    }
}
