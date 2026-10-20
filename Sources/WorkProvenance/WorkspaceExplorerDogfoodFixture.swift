#if DEBUG
import Foundation
import ProvenanceEngineContracts

/// In-memory closed history for visual checks without mutating a user's PE store.
@MainActor
final class WorkspaceExplorerDogfoodFixture {
    private let now = Date()
    private let openID = UUID()
    private let closedID = UUID()
    private let historicalID = UUID()
    private var reopened = false
    private var cleared = false

    func load() -> WorkspaceExplorerHistoryLoadResult {
        let open = WorkspaceExplorerLiveWorkspace(
            stableID: openID, runtimeID: openID, title: "Maple Street Roof Inspection",
            createdAt: now.addingTimeInterval(-3 * 86_400), colorHex: "#3B6FD6",
            display: display(id: openID, projectID: "maple", projectName: "Maple Street Renovation",
                repository: "roof-plans", ticket: "ROOF-218", pr: 4120),
            lastActivityAt: now.addingTimeInterval(-720), liveStatus: .running)
        let archive = cleared ? [] : closedRecords()
        let reopenedLive: [WorkspaceExplorerLiveWorkspace] = reopened ? [WorkspaceExplorerLiveWorkspace(
            stableID: closedID, runtimeID: closedID, title: "Inspect flashing details",
            createdAt: now.addingTimeInterval(-5 * 86_400), colorHex: "#7C5CD6",
            display: display(id: closedID, projectID: "maple", projectName: "Maple Street Renovation",
                repository: "roof-plans", ticket: "ROOF-204", pr: nil),
            lastActivityAt: now.addingTimeInterval(-3_600), liveStatus: .idle)] : []
        let items = WorkspaceExplorerHistoryAdapter().join(live: [open] + reopenedLive,
            archived: archive, eligibilityByID: [closedID: .eligible(recordID: closedID)])
        return WorkspaceExplorerHistoryLoadResult(items: items,
            archiveAvailability: .available, partialLiveActivity: false,
            activeWorkspaceID: openID.uuidString)
    }

    func reopen(_ id: UUID) -> Bool {
        guard id == closedID && !reopened && !cleared else { return false }
        reopened = true
        return true
    }

    func clear() { cleared = true }

    func sessions(_ id: UUID) -> ProvenanceWorkspaceSessionPageResponse {
        let session = ProvenanceSessionRecord(id: "codex-maple-2026", agentKind: "codex",
            workspaceID: id.uuidString, status: "completed",
            startedAt: now.addingTimeInterval(-7_200), updatedAt: now.addingTimeInterval(-3_600))
        return ProvenanceWorkspaceSessionPageResponse(workspaceID: id.uuidString,
            sessions: [ProvenanceWorkspaceSessionSummary(session: session,
                lastActivityAt: now.addingTimeInterval(-3_600))], nextCursor: nil)
    }

    func evidence(_ id: String) -> (
        ProvenanceFactualSessionProjectionResponse, ProvenanceSessionOutcomeResponse
    ) {
        (ProvenanceFactualSessionProjectionResponse(found: false, sessionID: id, snapshot: nil),
         ProvenanceSessionOutcomeResponse(found: false, sessionID: id, outcome: nil))
    }

    private func closedRecords() -> [ProvenanceArchivedWorkspaceRecord] {
        let selected = record(id: closedID, title: "Inspect flashing details", hoursAgo: 2,
            projectID: "maple", projectName: "Maple Street Renovation",
            repository: "roof-plans", ticket: "ROOF-204", color: "#7C5CD6")
        let historical = record(id: historicalID, title: "Review retaining wall drainage", hoursAgo: 15,
            projectID: "ridge", projectName: "North Ridge Retaining Wall",
            repository: "site-plans", ticket: "SITE-81", color: "#2E9E5B")
        let dense = (0..<40).map { index in
            record(id: deterministicID(index), title: "Maple Street roof section \(index + 1)",
                hoursAgo: Double(index + 1), projectID: index.isMultiple(of: 2) ? "maple" : "ridge",
                projectName: index.isMultiple(of: 2) ? "Maple Street Renovation" :
                    "North Ridge Retaining Wall",
                repository: index.isMultiple(of: 3) ? "roof-plans" : "site-plans",
                ticket: index.isMultiple(of: 5) ? nil : "ROOF-\(300 + index)",
                color: index.isMultiple(of: 2) ? "#E07A1F" : "#2A9D8F")
        }
        return [selected, historical] + dense
    }

    private func deterministicID(_ index: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", index + 1)) ?? UUID()
    }

    private func record(id: UUID, title: String, hoursAgo: Double,
                        projectID: String, projectName: String,
                        repository: String, ticket: String?, color: String) -> ProvenanceArchivedWorkspaceRecord {
        let closed = now.addingTimeInterval(-hoursAgo * 3_600)
        return ProvenanceArchivedWorkspaceRecord(id: id.uuidString, title: title,
            createdAt: closed.addingTimeInterval(-2 * 86_400), closedAt: closed,
            lastActivityAt: closed.addingTimeInterval(-900),
            displayAtClose: display(id: id, projectID: projectID, projectName: projectName,
                repository: repository, ticket: ticket, pr: nil),
            colorHex: color, coverageCode: "fixture_partial")
    }

    private func display(id: UUID, projectID: String, projectName: String,
                         repository: String, ticket: String?, pr: Int?) -> ProvenanceWorkspaceDisplayRecord {
        ProvenanceWorkspaceDisplayRecord(id: "display-\(id.uuidString)", workspaceID: id.uuidString,
            repositoryID: repository, branch: "feature/roof-review", pullRequestNumber: pr,
            pullRequestOwnerLogin: pr == nil ? nil : "brianbusby",
            pullRequestStatus: pr == nil ? nil : "In review",
            ticketIDs: ticket.map { [$0] } ?? [],
            projectLinks: [.init(id: projectID, title: projectName)],
            observedAt: now, updatedAt: now)
    }
}
#endif
