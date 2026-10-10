import Foundation
import ProvenanceEngineContracts

/// Presentation of an existing canonical snapshot; no membership or semantic inference.
struct ExpandedTurnPresentation {
    let reference: ProvenanceFactualSessionProjectionTurnReference
    let detail: ProvenanceFactualSessionProjectionTurnSnapshot?
    let request: ExpandedTurnRequest
    let finalOutput: String?
    let summary: String?

    init(reference: ProvenanceFactualSessionProjectionTurnReference, detail: ProvenanceFactualSessionProjectionTurnSnapshot?) {
        self.reference = reference
        self.detail = detail
        request = ExpandedTurnRequest(objective: detail?.submittedPrompt?.text, prompt: detail?.submittedPrompt?.text)
        finalOutput = detail?.assistantMessages.last(where: { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?.text
        let fileSummary = detail?.fileChangeAttributions.compactMap(\.summary).last
        let reasoningSummary = detail?.visibleReasoningSummaries.last?.text
        let candidate = [finalOutput, fileSummary, reasoningSummary].compactMap { $0 }.first {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        summary = ExpandedTurnRequest.visibleSummary(candidate, finalOutput: finalOutput)
    }

    var duration: TimeInterval? {
        guard let start = reference.startedAt, let end = reference.completedAt,
              end >= start else { return nil }
        return end.timeIntervalSince(start)
    }

    /// An empty array from a lifecycle-only provider is not proof of zero telemetry.
    func count(_ recorded: Int?) -> Int? {
        guard let recorded else { return nil }
        return recorded > 0 || reference.provider.lowercased() == "codex" ? recorded : nil
    }
}
