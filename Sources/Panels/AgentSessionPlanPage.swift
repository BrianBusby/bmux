import Foundation
import ProvenanceEngineContracts

/// A bounded page of one received plan, retaining the original step values.
struct AgentSessionPlanPage {
    private static let pageSize = 8
    let steps: ArraySlice<ProvenanceCodingAgentPlanStepRecord>
    let start: Int
    let end: Int
    let total: Int
    let currentPage: Int
    let previousPage: Int?
    let nextPage: Int?

    init(steps: [ProvenanceCodingAgentPlanStepRecord], requestedPage: Int) {
        let lastPage = steps.isEmpty ? 0 : (steps.count - 1) / Self.pageSize
        let page = min(max(requestedPage, 0), lastPage)
        let start = page * Self.pageSize
        let end = min(start + Self.pageSize, steps.count)
        self.steps = steps[start..<end]
        self.start = start
        self.end = end
        self.total = steps.count
        self.currentPage = page
        self.previousPage = page > 0 ? page - 1 : nil
        self.nextPage = page < lastPage ? page + 1 : nil
    }
}
