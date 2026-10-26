import Foundation

/// Answers supported work questions from one bounded immutable source snapshot.
public struct WorkBriefQuestionAnswerer: Sendable {
    /// Creates a stateless answerer.
    public init() {}

    /// Returns source-backed item IDs and links; question text is never stored.
    /// - Parameters:
    ///   - question: The user's current question in English or Japanese.
    ///   - snapshot: The bounded source facts visible in the brief.
    /// - Returns: A deterministic answer with no generated canonical facts.
    public func answer(_ question: String, snapshot: WorkBriefSnapshot) -> WorkBriefAnswer {
        let normalized = question.lowercased()
        let tokens = Set(normalized.split {
            !$0.isASCII || (!$0.isLetter && !$0.isNumber && $0 != "-" && $0 != "#")
        }.map(String.init))
        let projection = WorkBriefProjection(snapshot: snapshot)
        let waitingQuestion = normalized.contains("wait") || normalized.contains("block") ||
            normalized.contains("待") || normalized.contains("ブロック")
        if waitingQuestion && (tokens.contains("why") || normalized.contains("なぜ") ||
                               normalized.contains("理由")) {
            let matching = snapshot.externalItems.filter { item in
                tokens.contains(item.reference.lowercased()) ||
                    normalized.contains(item.url.absoluteString.lowercased())
            }
            guard matching.count == 1, let item = matching.first else {
                return WorkBriefAnswer(kind: .needsReference)
            }
            guard item.disposition == .waitingOn,
                  item.evidence.contains(where: { $0.field == "awaitingReview" && $0.isObserved }) else {
                return WorkBriefAnswer(kind: .noWaitEvidence)
            }
            return WorkBriefAnswer(kind: .waitingOn, externalIDs: [item.id])
        }
        if normalized.contains("pull request") || normalized.contains("プルリクエスト") || tokens.contains("pr") {
            let mentionedTicketIDs = snapshot.localWorkspaces.flatMap(\.tickets).map(\.id)
                .filter { tokens.contains($0.lowercased()) }
            let matches = snapshot.localWorkspaces.filter { workspace in
                workspace.tickets.contains { mentionedTicketIDs.contains($0.id) }
            }
            let links = matches.compactMap(\.pullRequest)
            return WorkBriefAnswer(kind: links.isEmpty ? .noEvidence : .ticketPullRequest,
                localIDs: matches.map(\.id), links: links)
        }
        if waitingQuestion {
            return WorkBriefAnswer(kind: .waitingOn,
                externalIDs: projection.externalWaitingOn.map(\.id))
        }
        if normalized.contains("attention") || normalized.contains("need") || normalized.contains("review") ||
           normalized.contains("対応") || normalized.contains("注意") || normalized.contains("レビュー") {
            return WorkBriefAnswer(kind: .needsAttention,
                localIDs: projection.needsAttention.map(\.id),
                externalIDs: projection.externalNeedsAttention.map(\.id))
        }
        if normalized.contains("progress") || normalized.contains("working") || normalized.contains("worked on") ||
           normalized.contains("進行") || normalized.contains("作業中") {
            return WorkBriefAnswer(kind: .inProgress,
                localIDs: projection.inProgress.map(\.id),
                externalIDs: projection.externalInProgress.map(\.id))
        }
        return WorkBriefAnswer(kind: .unsupported)
    }
}
