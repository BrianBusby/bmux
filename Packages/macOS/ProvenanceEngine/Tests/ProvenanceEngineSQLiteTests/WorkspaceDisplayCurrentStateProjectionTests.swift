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
                projectLinks: [
                    ProvenanceWorkspaceDisplayProjectLinkRecord(
                        id: "upload-reliability-20a24",
                        system: "linear",
                        title: "Upload Reliability",
                        url: "https://linear.app/company/project/upload-reliability-20a24"
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
        #expect(display.projectLinks.first?.title == "Upload Reliability")
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

    @Test
    func explicitPullRequestClearRemovesKnownPullRequest() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let baseTime = Date(timeIntervalSince1970: 1_810_000_200)

        try await Self.appendWorkspaceDisplay(
            eventID: "event-workspace-display-pr-known",
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
            eventID: "event-workspace-display-pr-cleared",
            timestamp: baseTime.addingTimeInterval(1),
            display: Self.workspaceDisplay(
                clearedFields: ["pull_request"],
                observedAt: baseTime.addingTimeInterval(1)
            ),
            into: repository
        )

        let display = try #require(try await repository.workspaceDisplay(
            ProvenanceWorkspaceDisplayRequest(workspaceID: Self.workspaceID)
        ).display)
        #expect(display.pullRequestNumber == nil)
        #expect(display.pullRequestURL == nil)
        #expect(display.pullRequestStatus == nil)
        #expect(display.pullRequestBranch == nil)
        #expect(display.pullRequestIsStale == false)
        #expect(display.clearedFields.contains("pull_request"))
        #expect(display.fieldMetadata["pull_request"]?.isExplicitlyCleared == true)
    }

    @Test
    func mergeTransitionKeepsPullRequestDisplayedWithMergedStatus() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let baseTime = Date(timeIntervalSince1970: 1_810_000_300)

        try await Self.appendWorkspaceDisplay(
            eventID: "event-workspace-display-pr-open-transition",
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
            eventID: "event-workspace-display-pr-merged-transition",
            timestamp: baseTime.addingTimeInterval(1),
            display: Self.workspaceDisplay(
                pullRequestStatus: "merged",
                observedAt: baseTime.addingTimeInterval(1)
            ),
            into: repository
        )

        let display = try #require(try await repository.workspaceDisplay(
            ProvenanceWorkspaceDisplayRequest(workspaceID: Self.workspaceID)
        ).display)
        #expect(display.pullRequestNumber == 42)
        #expect(display.pullRequestURL == "https://github.com/example/repo/pull/42")
        #expect(display.pullRequestStatus == "merged")
        #expect(display.pullRequestBranch == "feature/pr-42")
    }

    @Test
    func ticketEnrichmentAccumulatesIDTitleAndOwner() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let baseTime = Date(timeIntervalSince1970: 1_810_000_400)

        try await Self.appendWorkspaceDisplay(
            eventID: "event-workspace-display-ticket-id",
            timestamp: baseTime,
            display: Self.workspaceDisplay(ticketIDs: ["CC-1842"], observedAt: baseTime),
            into: repository
        )
        try await Self.appendWorkspaceDisplay(
            eventID: "event-workspace-display-ticket-title",
            timestamp: baseTime.addingTimeInterval(1),
            display: Self.workspaceDisplay(
                ticketLinks: [
                    ProvenanceWorkspaceDisplayTicketLinkRecord(
                        id: "CC-1842",
                        system: "linear",
                        title: "Fix upload retry behavior",
                        url: "https://linear.app/company/issue/CC-1842"
                    )
                ],
                observedAt: baseTime.addingTimeInterval(1)
            ),
            into: repository
        )
        try await Self.appendWorkspaceDisplay(
            eventID: "event-workspace-display-ticket-owner",
            timestamp: baseTime.addingTimeInterval(2),
            display: Self.workspaceDisplay(
                ticketLinks: [
                    ProvenanceWorkspaceDisplayTicketLinkRecord(
                        id: "CC-1842",
                        ownerName: "Brian",
                        ownerURL: "https://linear.app/company/profiles/brian"
                    )
                ],
                observedAt: baseTime.addingTimeInterval(2)
            ),
            into: repository
        )

        let display = try #require(try await repository.workspaceDisplay(
            ProvenanceWorkspaceDisplayRequest(workspaceID: Self.workspaceID)
        ).display)
        let ticket = try #require(display.ticketLinks.first)
        #expect(display.ticketIDs == ["CC-1842"])
        #expect(ticket.title == "Fix upload retry behavior")
        #expect(ticket.url == "https://linear.app/company/issue/CC-1842")
        #expect(ticket.ownerName == "Brian")
        #expect(ticket.ownerURL == "https://linear.app/company/profiles/brian")
    }

    @Test
    func projectEnrichmentAccumulatesTitleAndURL() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let baseTime = Date(timeIntervalSince1970: 1_810_000_450)

        try await Self.appendWorkspaceDisplay(
            eventID: "event-workspace-display-project-title",
            timestamp: baseTime,
            display: Self.workspaceDisplay(
                projectLinks: [
                    ProvenanceWorkspaceDisplayProjectLinkRecord(
                        id: "upload-reliability-20a24",
                        system: "linear",
                        title: "Upload Reliability"
                    )
                ],
                observedAt: baseTime
            ),
            into: repository
        )
        try await Self.appendWorkspaceDisplay(
            eventID: "event-workspace-display-project-url",
            timestamp: baseTime.addingTimeInterval(1),
            display: Self.workspaceDisplay(
                projectLinks: [
                    ProvenanceWorkspaceDisplayProjectLinkRecord(
                        id: "upload-reliability-20a24",
                        url: "https://linear.app/company/project/upload-reliability-20a24"
                    )
                ],
                observedAt: baseTime.addingTimeInterval(1)
            ),
            into: repository
        )

        let display = try #require(try await repository.workspaceDisplay(
            ProvenanceWorkspaceDisplayRequest(workspaceID: Self.workspaceID)
        ).display)
        let project = try #require(display.projectLinks.first)
        #expect(project.id == "upload-reliability-20a24")
        #expect(project.system == "linear")
        #expect(project.title == "Upload Reliability")
        #expect(project.url == "https://linear.app/company/project/upload-reliability-20a24")
        #expect(display.fieldMetadata["project_links"]?.evidenceEventID == "event-workspace-display-project-url")
    }

    @Test
    func promptSequenceKeepsLastSubmittedPromptUntilNewPromptArrives() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let baseTime = Date(timeIntervalSince1970: 1_810_000_500)

        try await Self.appendWorkspaceDisplay(
            eventID: "event-workspace-display-prompt-a",
            timestamp: baseTime,
            display: Self.workspaceDisplay(
                lastSubmittedPrompt: "prompt A",
                lastSubmittedPromptSubmittedAt: baseTime,
                lastSubmittedPromptSessionID: "session-a",
                observedAt: baseTime
            ),
            into: repository
        )
        try await Self.appendWorkspaceDisplay(
            eventID: "event-workspace-display-prompt-a-without-session",
            timestamp: baseTime.addingTimeInterval(1),
            display: Self.workspaceDisplay(
                branch: "feature/prompt-sequence",
                lastSubmittedPrompt: "prompt A",
                lastSubmittedPromptSubmittedAt: baseTime,
                observedAt: baseTime.addingTimeInterval(1)
            ),
            into: repository
        )
        try await Self.appendWorkspaceDisplay(
            eventID: "event-workspace-display-tool-event",
            timestamp: baseTime.addingTimeInterval(2),
            display: Self.workspaceDisplay(branch: "feature/prompt-sequence", observedAt: baseTime.addingTimeInterval(2)),
            into: repository
        )
        try await Self.appendWorkspaceDisplay(
            eventID: "event-workspace-display-prompt-b",
            timestamp: baseTime.addingTimeInterval(3),
            display: Self.workspaceDisplay(
                lastSubmittedPrompt: "prompt B",
                lastSubmittedPromptSubmittedAt: baseTime.addingTimeInterval(3),
                lastSubmittedPromptSessionID: "session-b",
                observedAt: baseTime.addingTimeInterval(3)
            ),
            into: repository
        )

        let display = try #require(try await repository.workspaceDisplay(
            ProvenanceWorkspaceDisplayRequest(workspaceID: Self.workspaceID)
        ).display)
        #expect(display.lastSubmittedPrompt == "prompt B")
        #expect(display.lastSubmittedPromptSessionID == "session-b")
        #expect(display.fieldMetadata["last_submitted_prompt"]?.evidenceEventID == "event-workspace-display-prompt-b")
    }

    @Test
    func workSummarySequenceSurvivesUnrelatedEventsUntilNewSummaryArrives() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let baseTime = Date(timeIntervalSince1970: 1_810_000_600)

        try await Self.appendWorkspaceDisplay(
            eventID: "event-workspace-display-summary-a",
            timestamp: baseTime,
            display: Self.workspaceDisplay(currentWorkSummary: "summary A", observedAt: baseTime),
            into: repository
        )
        for index in 1...5 {
            try await Self.appendWorkspaceDisplay(
                eventID: "event-workspace-display-unrelated-\(index)",
                timestamp: baseTime.addingTimeInterval(Double(index)),
                display: Self.workspaceDisplay(
                    branch: "feature/summary-sequence",
                    observedAt: baseTime.addingTimeInterval(Double(index))
                ),
                into: repository
            )
        }
        let afterUnrelated = try #require(try await repository.workspaceDisplay(
            ProvenanceWorkspaceDisplayRequest(workspaceID: Self.workspaceID)
        ).display)
        #expect(afterUnrelated.currentWorkSummary == "summary A")

        try await Self.appendWorkspaceDisplay(
            eventID: "event-workspace-display-summary-b",
            timestamp: baseTime.addingTimeInterval(10),
            display: Self.workspaceDisplay(
                currentWorkSummary: "summary B",
                observedAt: baseTime.addingTimeInterval(10)
            ),
            into: repository
        )

        let display = try #require(try await repository.workspaceDisplay(
            ProvenanceWorkspaceDisplayRequest(workspaceID: Self.workspaceID)
        ).display)
        #expect(display.currentWorkSummary == "summary B")
        #expect(display.fieldMetadata["current_work_summary"]?.evidenceEventID == "event-workspace-display-summary-b")
    }

    @Test
    func rebuildFromLedgerReproducesDurableWorkspaceDisplayDetails() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let baseTime = Date(timeIntervalSince1970: 1_810_000_700)

        try await Self.appendWorkspaceDisplay(
            eventID: "event-workspace-display-rebuild-full",
            timestamp: baseTime,
            display: Self.workspaceDisplay(
                branch: "feature/rebuild",
                pullRequestNumber: 77,
                pullRequestURL: "https://github.com/example/repo/pull/77",
                pullRequestOwnerLogin: "brian",
                pullRequestStatus: "merged",
                pullRequestBranch: "feature/rebuild",
                ticketIDs: ["CC-1842"],
                ticketLinks: [
                    ProvenanceWorkspaceDisplayTicketLinkRecord(
                        id: "CC-1842",
                        title: "Fix upload retry behavior",
                        ownerName: "Brian"
                    )
                ],
                projectLinks: [
                    ProvenanceWorkspaceDisplayProjectLinkRecord(
                        id: "upload-reliability-20a24",
                        title: "Upload Reliability"
                    )
                ],
                currentWorkSummary: "summary before restart",
                lastSubmittedPrompt: "prompt before restart",
                lastSubmittedPromptSubmittedAt: baseTime,
                lastSubmittedPromptSessionID: "session-rebuild",
                observedAt: baseTime
            ),
            into: repository
        )

        try Self.deleteWorkspaceDisplayProjectionRows(databaseURL: url)
        #expect(try await repository.workspaceDisplay(
            ProvenanceWorkspaceDisplayRequest(workspaceID: Self.workspaceID)
        ).found == false)
        #expect(try await repository.rebuildProjectionsFromEventLedger(batchSize: 1) == 1)

        let display = try #require(try await repository.workspaceDisplay(
            ProvenanceWorkspaceDisplayRequest(workspaceID: Self.workspaceID)
        ).display)
        #expect(display.branch == "feature/rebuild")
        #expect(display.pullRequestNumber == 77)
        #expect(display.pullRequestStatus == "merged")
        #expect(display.ticketLinks.first?.ownerName == "Brian")
        #expect(display.projectLinks.first?.title == "Upload Reliability")
        #expect(display.currentWorkSummary == "summary before restart")
        #expect(display.lastSubmittedPrompt == "prompt before restart")
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
        projectLinks: [ProvenanceWorkspaceDisplayProjectLinkRecord] = [],
        currentWorkSummary: String? = nil,
        lastSubmittedPrompt: String? = nil,
        lastSubmittedPromptSubmittedAt: Date? = nil,
        lastSubmittedPromptSessionID: String? = nil,
        clearedFields: [String] = [],
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
            projectLinks: projectLinks,
            currentWorkSummary: currentWorkSummary,
            lastSubmittedPrompt: lastSubmittedPrompt,
            lastSubmittedPromptSubmittedAt: lastSubmittedPromptSubmittedAt,
            lastSubmittedPromptSessionID: lastSubmittedPromptSessionID,
            clearedFields: clearedFields,
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

    private static func deleteWorkspaceDisplayProjectionRows(databaseURL: URL) throws {
        let database = try ProvenanceSQLiteDatabase(url: databaseURL)
        try database.execute("DELETE FROM provenance_workspace_display")
    }
}
