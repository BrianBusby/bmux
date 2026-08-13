import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

@Suite
struct WorkspaceDisplayCurrentStateProjectionTests {
    @Test
    func partialLaterWorkspaceDisplayEventPreservesKnownWorkItemFacts() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let baseTime = Date(timeIntervalSince1970: 1_810_000_000)

        try await Self.appendWorkspaceDisplay(
            eventID: "event-workspace-display-full",
            timestamp: baseTime,
            display: Self.workspaceDisplay(
                branch: "feature/cc-1842-upload-retries",
                pullRequestNumber: 9182,
                pullRequestURL: "https://github.com/example/repo/pull/9182",
                pullRequestOwnerLogin: "brian",
                pullRequestOwnerURL: "https://github.com/brian",
                pullRequestStatus: "open",
                pullRequestBranch: "feature/cc-1842-upload-retries",
                ticketIDs: ["CC-1842"],
                ticketLinks: [
                    ProvenanceWorkspaceDisplayTicketLinkRecord(
                        id: "CC-1842",
                        system: "linear",
                        title: "Fix upload retry behavior",
                        url: "https://linear.app/company/issue/CC-1842"
                    )
                ],
                observedAt: baseTime
            ),
            into: repository
        )

        try await Self.appendWorkspaceDisplay(
            eventID: "event-workspace-display-branch-only",
            timestamp: baseTime.addingTimeInterval(1),
            display: Self.workspaceDisplay(
                branch: "feature/cc-1842-upload-retries",
                observedAt: baseTime.addingTimeInterval(1)
            ),
            into: repository
        )

        let response = try await repository.workspaceDisplay(
            ProvenanceWorkspaceDisplayRequest(workspaceID: Self.workspaceID)
        )
        let display = try #require(response.display)

        #expect(display.branch == "feature/cc-1842-upload-retries")
        #expect(display.pullRequestNumber == 9182)
        #expect(display.pullRequestURL == "https://github.com/example/repo/pull/9182")
        #expect(display.pullRequestOwnerLogin == "brian")
        #expect(display.pullRequestOwnerURL == "https://github.com/brian")
        #expect(display.pullRequestStatus == "open")
        #expect(display.pullRequestBranch == "feature/cc-1842-upload-retries")
        #expect(display.ticketIDs == ["CC-1842"])
        #expect(display.ticketLinks.first?.title == "Fix upload retry behavior")
        #expect(display.latestEventID == "event-workspace-display-branch-only")
    }

    @Test
    func failedPullRequestRefreshMarksStaleWithoutClearingKnownPullRequest() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let baseTime = Date(timeIntervalSince1970: 1_810_000_100)

        try await Self.appendWorkspaceDisplay(
            eventID: "event-workspace-display-pr-open",
            timestamp: baseTime,
            display: Self.workspaceDisplay(
                pullRequestNumber: 42,
                pullRequestURL: "https://github.com/example/repo/pull/42",
                pullRequestStatus: "open",
                pullRequestBranch: "feature/pr-42",
                observedAt: baseTime
            ),
            into: repository
        )

        try await Self.appendWorkspaceDisplay(
            eventID: "event-workspace-display-pr-refresh-failed",
            timestamp: baseTime.addingTimeInterval(1),
            display: Self.workspaceDisplay(
                pullRequestIsStale: true,
                observedAt: baseTime.addingTimeInterval(1)
            ),
            into: repository
        )

        let response = try await repository.workspaceDisplay(
            ProvenanceWorkspaceDisplayRequest(workspaceID: Self.workspaceID)
        )
        let display = try #require(response.display)

        #expect(display.pullRequestNumber == 42)
        #expect(display.pullRequestURL == "https://github.com/example/repo/pull/42")
        #expect(display.pullRequestStatus == "open")
        #expect(display.pullRequestBranch == "feature/pr-42")
        #expect(display.pullRequestIsStale)
        #expect(display.latestEventID == "event-workspace-display-pr-refresh-failed")
    }

    private static let workspaceID = "00000000-0000-0000-0000-000000001842"

    private static func appendWorkspaceDisplay(
        eventID: String,
        timestamp: Date,
        display: ProvenanceWorkspaceDisplayRecord,
        into repository: ProvenanceSQLiteRepository
    ) async throws {
        try await repository.appendEvent(
            ProvenanceEvent(
                id: eventID,
                eventType: .workspaceDisplayObserved,
                timestamp: timestamp,
                repositoryID: display.repositoryID,
                worktreeID: display.worktreeID,
                source: .observed,
                evidenceOrigin: ProvenanceEvidenceOrigin(rawValue: "workspace-display-projection-tests"),
                evidenceScope: ProvenanceEvidenceScope(level: .personal, id: "local-test"),
                confidence: .high,
                payload: ProvenanceEventPayload(workspaceDisplay: display)
            )
        )
    }

    private static func workspaceDisplay(
        branch: String? = nil,
        pullRequestNumber: Int? = nil,
        pullRequestURL: String? = nil,
        pullRequestOwnerLogin: String? = nil,
        pullRequestOwnerURL: String? = nil,
        pullRequestStatus: String? = nil,
        pullRequestBranch: String? = nil,
        pullRequestIsStale: Bool = false,
        ticketIDs: [String] = [],
        ticketLinks: [ProvenanceWorkspaceDisplayTicketLinkRecord] = [],
        observedAt: Date
    ) -> ProvenanceWorkspaceDisplayRecord {
        ProvenanceWorkspaceDisplayRecord(
            id: "workspace-display-\(Self.workspaceID)",
            workspaceID: Self.workspaceID,
            repositoryID: "repository-workspace-display-tests",
            worktreeID: "worktree-workspace-display-tests",
            currentDirectory: "/repos/example",
            title: "Example Workspace",
            titleSource: "user",
            branch: branch,
            pullRequestNumber: pullRequestNumber,
            pullRequestURL: pullRequestURL,
            pullRequestOwnerLogin: pullRequestOwnerLogin,
            pullRequestOwnerURL: pullRequestOwnerURL,
            pullRequestStatus: pullRequestStatus,
            pullRequestBranch: pullRequestBranch,
            pullRequestIsStale: pullRequestIsStale,
            isDirty: false,
            ticketIDs: ticketIDs,
            ticketLinks: ticketLinks,
            observedAt: observedAt,
            updatedAt: observedAt
        )
    }

    private static func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("provenance-engine-workspace-display-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("provenance.sqlite")
    }

    private static func removeTemporaryDatabaseDirectory(for url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}

