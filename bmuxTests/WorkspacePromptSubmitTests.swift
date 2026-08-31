import Foundation
import Testing
import Combine
import BMUXAgentLaunch
import BmuxSidebar

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite(.serialized)
struct WorkspacePromptSubmitTests {
    @Test func testPromptSubmitRecordsMessageAndMovesWorkspaceToTopWhenIMessageModeEnabled() throws {
        let manager = TabManager()
        let first = manager.tabs[0]
        let second = manager.addWorkspace(select: false, placementOverride: .end)
        let third = manager.addWorkspace(select: false, placementOverride: .end)
        manager.selectWorkspace(second)

        let outcome = try #require(
            manager.handlePromptSubmit(
                workspaceId: third.id,
                message: "  implement this\n\nnow  ",
                iMessageModeEnabled: true
            )
        )

        #expect(outcome.messageRecorded)
        #expect(outcome.reordered)
        #expect(outcome.index == 0)
        #expect(manager.tabs.map(\.id) == [third.id, first.id, second.id])
        #expect(manager.selectedTabId == second.id)
        #expect(third.latestConversationMessage == "implement this now")
        #expect(third.latestSubmittedAt != nil)
    }

    @Test func testPromptSubmitReorderPublishesWorkspaceOrderEvent() throws {
        BmuxEventBus.shared.resetForTesting()
        defer { BmuxEventBus.shared.resetForTesting() }

        let manager = TabManager()
        let first = manager.tabs[0]
        let second = manager.addWorkspace(select: false, placementOverride: .end)
        let third = manager.addWorkspace(select: false, placementOverride: .end)
        BmuxEventBus.shared.resetForTesting()

        let outcome = try #require(
            manager.handlePromptSubmit(
                workspaceId: third.id,
                message: "ship it",
                iMessageModeEnabled: true
            )
        )

        #expect(outcome.reordered)
        let events = BmuxEventBus.shared.retainedSnapshot()
        #expect(events.compactMap { $0["name"] as? String } == ["workspace.prompt.submitted", "workspace.reordered"])
        let reorder = try #require(events.last)
        #expect(reorder["workspace_id"] as? String == third.id.uuidString)
        let payload = try #require(reorder["payload"] as? [String: Any])
        #expect(payload["workspace_ids"] as? [String] == [third.id.uuidString, first.id.uuidString, second.id.uuidString])
        #expect(payload["moved_workspace_ids"] as? [String] == [third.id.uuidString])
    }

    @Test func testPromptSubmitRecordsMessageWithoutReorderingWhenIMessageModeDisabled() throws {
        let manager = TabManager()
        let first = manager.tabs[0]
        let second = manager.addWorkspace(select: false, placementOverride: .end)
        let third = manager.addWorkspace(select: false, placementOverride: .end)
        let terminalPanel = try #require(third.focusedTerminalPanel)
        #expect(!terminalPanel.promptNavigationHasBookmarks)

        let outcome = try #require(
            manager.handlePromptSubmit(
                workspaceId: third.id,
                message: "do not show",
                iMessageModeEnabled: false
            )
        )

        #expect(outcome.messageRecorded)
        #expect(!outcome.reordered)
        #expect(outcome.index == 2)
        #expect(manager.tabs.map(\.id) == [first.id, second.id, third.id])
        #expect(third.latestConversationMessage == "do not show")
        #expect(third.latestSubmittedAt != nil)
        #expect(terminalPanel.promptNavigationHasBookmarks)
        #expect(terminalPanel.promptNavigationCanMoveBackward)
        #expect(!terminalPanel.promptNavigationCanMoveForward)

        var scrolledRows: [Int] = []
        #expect(terminalPanel.recordPromptNavigationBookmark(row: 20))
        #expect(terminalPanel.navigatePromptBookmark(delta: -1) { row in
            scrolledRows.append(row)
            return true
        })
        #expect(scrolledRows == [20])
        #expect(terminalPanel.promptNavigationCanMoveForward)

        var scrolledToCurrentPrompt = 0
        let pulseSeedBeforeCurrentPrompt = terminalPanel.promptNavigationTextBoxPulseSeed
        #expect(terminalPanel.navigatePromptBookmark(delta: 1, scrollToCurrentPrompt: {
            scrolledToCurrentPrompt += 1
            return true
        }) { row in
            scrolledRows.append(row)
            return true
        })
        #expect(scrolledRows == [20])
        #expect(scrolledToCurrentPrompt == 1)
        #expect(terminalPanel.isTextBoxActive)
        #expect(terminalPanel.promptNavigationTextBoxPulseSeed == pulseSeedBeforeCurrentPrompt + 1)
        #expect(terminalPanel.promptNavigationCanMoveBackward)
        #expect(!terminalPanel.promptNavigationCanMoveForward)

        #expect(terminalPanel.navigatePromptBookmark(delta: -1) { row in
            scrolledRows.append(row)
            return true
        })
        #expect(scrolledRows == [20, 20])
        #expect(terminalPanel.navigatePromptBookmark(delta: -1) { row in
            scrolledRows.append(row)
            return true
        })
        #expect(scrolledRows == [20, 20, 0])
        #expect(!terminalPanel.promptNavigationCanMoveBackward)
        #expect(terminalPanel.promptNavigationCanMoveForward)
    }

    @Test func testPromptSubmitPostsWorkspaceDisplayMetadataNotification() throws {
        let manager = TabManager()
        let workspace = manager.tabs[0]
        var notificationCount = 0
        let observer = NotificationCenter.default.addObserver(
            forName: .workspaceDisplayMetadataDidChange,
            object: workspace,
            queue: nil
        ) { _ in
            notificationCount += 1
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        let outcome = try #require(manager.handlePromptSubmit(
            workspaceId: workspace.id,
            message: "preserve this prompt in workspace display",
            sessionID: " session-1 ",
            iMessageModeEnabled: false
        ))

        #expect(outcome.messageRecorded)
        #expect(workspace.latestSubmittedPromptSessionID == "session-1")
        #expect(notificationCount == 1)
        #expect(!workspace.workspaceDisplayExplicitClearedFields.contains("last_submitted_prompt"))
        #expect(!workspace.workspaceDisplayExplicitClearedFields.contains("last_submitted_prompt_session_id"))
    }

    @Test func testAssistantFinalMessageRecordsMessageAndMovesWorkspaceToTopWhenIMessageModeEnabled() throws {
        let manager = TabManager()
        let pinned = manager.tabs[0]
        manager.setPinned(pinned, pinned: true)
        let second = manager.addWorkspace(select: false, placementOverride: .end)
        let third = manager.addWorkspace(select: false, placementOverride: .end)
        manager.selectWorkspace(second)

        let outcome = try #require(
            manager.handleAssistantFinalMessage(
                workspaceId: third.id,
                message: "  final\n\nresponse  ",
                iMessageModeEnabled: true
            )
        )

        #expect(outcome.messageRecorded)
        #expect(outcome.reordered)
        #expect(outcome.index == 1)
        #expect(manager.tabs.map(\.id) == [pinned.id, third.id, second.id])
        #expect(manager.selectedTabId == second.id)
        #expect(third.latestConversationMessage == "final response")
    }

    @Test func testAssistantFinalMessageMovesWorkspaceWhenPreviewMatchesExistingMessage() throws {
        let manager = TabManager()
        let pinned = manager.tabs[0]
        manager.setPinned(pinned, pinned: true)
        let second = manager.addWorkspace(select: false, placementOverride: .end)
        let third = manager.addWorkspace(select: false, placementOverride: .end)
        #expect(third.recordConversationMessage("Done."))

        let outcome = try #require(
            manager.handleAssistantFinalMessage(
                workspaceId: third.id,
                message: "Done.",
                iMessageModeEnabled: true
            )
        )

        #expect(!outcome.messageRecorded)
        #expect(outcome.reordered)
        #expect(outcome.index == 1)
        #expect(manager.tabs.map(\.id) == [pinned.id, third.id, second.id])
        #expect(third.latestConversationMessage == "Done.")
    }

    @Test func testBlankAssistantFinalMessageDoesNotMoveWorkspace() throws {
        let manager = TabManager()
        let first = manager.tabs[0]
        let second = manager.addWorkspace(select: false, placementOverride: .end)

        let outcome = try #require(
            manager.handleAssistantFinalMessage(
                workspaceId: second.id,
                message: " \n ",
                iMessageModeEnabled: true
            )
        )

        #expect(!outcome.messageRecorded)
        #expect(!outcome.reordered)
        #expect(outcome.index == 1)
        #expect(manager.tabs.map(\.id) == [first.id, second.id])
        #expect(second.latestConversationMessage == nil)
    }

    @Test func testBlankPromptSubmitDoesNotRecordTimestampOrPublishEvent() throws {
        let manager = TabManager()
        let second = manager.addWorkspace(select: false, placementOverride: .end)
        let sequenceBeforeSubmit = BmuxEventBus.shared.latestSequence

        let outcome = try #require(
            manager.handlePromptSubmit(
                workspaceId: second.id,
                message: " \n ",
                iMessageModeEnabled: false
            )
        )

        #expect(!outcome.messageRecorded)
        #expect(!outcome.reordered)
        #expect(second.latestConversationMessage == nil)
        #expect(second.latestSubmittedAt == nil)
        #expect(BmuxEventBus.shared.latestSequence == sequenceBeforeSubmit)
    }

    @Test func testPromptSubmitRecordsGithubPullRequestMention() throws {
        let manager = TabManager()
        let workspace = manager.tabs[0]
        let panelId = try #require(workspace.focusedPanelId)

        let outcome = try #require(
            manager.handlePromptSubmit(
                workspaceId: workspace.id,
                message: "look at https://github.com/manaflow-ai/bmux/pull/5314 and fix the review notes",
                surfaceId: panelId,
                iMessageModeEnabled: false
            )
        )

        #expect(outcome.messageRecorded)
        let pullRequest = try #require(workspace.panelPullRequests[panelId])
        #expect(pullRequest.number == 5314)
        #expect(pullRequest.label == "PR")
        #expect(pullRequest.url.absoluteString == "https://github.com/manaflow-ai/bmux/pull/5314")
        #expect(pullRequest.branch == nil)
        #expect(workspace.sidebarPullRequestsInDisplayOrder().map(\.number) == [5314])
    }

    @Test func testPromptSubmitPullRequestMentionProjectsPromptWorkContextSource() throws {
        let manager = TabManager()
        let workspace = manager.tabs[0]
        let panelId = try #require(workspace.focusedPanelId)

        let outcome = try #require(
            manager.handlePromptSubmit(
                workspaceId: workspace.id,
                message: "look at https://github.com/manaflow-ai/bmux/pull/5314",
                surfaceId: panelId,
                iMessageModeEnabled: false
            )
        )

        #expect(outcome.messageRecorded)
        #expect(workspace.sidebarMetadata.workContext(panelId: panelId).pullRequest?.number == 5314)
        #expect(workspace.sidebarMetadata.workContext(panelId: panelId).pullRequest?.source == .promptMention)
        #expect(workspace.sidebarMetadata.workContext.pullRequest?.number == 5314)
        #expect(workspace.sidebarMetadata.workContext.pullRequest?.source == .promptMention)
    }

    @Test func testPromptSubmitPublishesLatestPromptWithMatchingPullRequestMention() throws {
        let manager = TabManager()
        let workspace = manager.tabs[0]
        let panelId = try #require(workspace.focusedPanelId)
        workspace.updatePanelPullRequest(
            panelId: panelId,
            number: 25194,
            label: "PR",
            url: try #require(URL(string: "https://github.com/CompanyCam/Company-Cam-API/pull/25194")),
            status: .open
        )

        var observedContexts: [(prompt: String?, pullRequestNumber: Int?)] = []
        let cancellable = workspace.sidebarImmediateObservationPublisher.sink {
            observedContexts.append((
                prompt: workspace.latestSubmittedMessage,
                pullRequestNumber: workspace.sidebarPullRequestsInDisplayOrder().first?.number
            ))
        }
        defer { cancellable.cancel() }
        observedContexts.removeAll()

        let outcome = try #require(
            manager.handlePromptSubmit(
                workspaceId: workspace.id,
                message: "Assessing route parameter comment in https://github.com/CompanyCam/Company-Cam-API/pull/25095",
                surfaceId: panelId,
                iMessageModeEnabled: false
            )
        )

        #expect(outcome.messageRecorded)
        let firstPromptContext = try #require(observedContexts.first { $0.prompt != nil })
        #expect(firstPromptContext.prompt?.contains("25095") == true)
        #expect(firstPromptContext.pullRequestNumber == 25095)
    }

    @Test func testPromptSubmitPullRequestMentionSurvivesBranchRefresh() throws {
        let manager = TabManager()
        let workspace = manager.tabs[0]
        let panelId = try #require(workspace.focusedPanelId)

        workspace.updatePanelGitBranch(panelId: panelId, branch: "main", isDirty: false)
        _ = try #require(
            manager.handlePromptSubmit(
                workspaceId: workspace.id,
                message: "review https://github.com/manaflow-ai/bmux/pull/5314",
                surfaceId: panelId,
                iMessageModeEnabled: false
            )
        )

        workspace.updatePanelGitBranch(panelId: panelId, branch: "feature/review", isDirty: false)

        #expect(workspace.panelPullRequests[panelId]?.number == 5314)
        #expect(workspace.pullRequest?.number == 5314)
        #expect(workspace.sidebarPullRequestsInDisplayOrder().map(\.number) == [5314])
    }

    @Test func testBranchDerivedPullRequestIsSuppressedWithoutExplicitWorkspaceIntent() throws {
        let manager = TabManager()
        let workspace = manager.tabs[0]
        let panelId = try #require(workspace.focusedPanelId)

        workspace.updatePanelGitBranch(panelId: panelId, branch: "codeowners-report-approved-status", isDirty: false)
        workspace.updatePanelPullRequest(
            panelId: panelId,
            number: 26201,
            label: "PR",
            url: try #require(URL(string: "https://github.com/CompanyCam/Company-Cam-API/pull/26201")),
            status: .open,
            branch: "codeowners-report-approved-status",
            source: .pullRequestLookup
        )

        #expect(workspace.panelPullRequests[panelId] == nil)
        #expect(workspace.pullRequest == nil)
        #expect(workspace.sidebarPullRequestsInDisplayOrder().isEmpty)
    }

    @Test func testShortPromptPullRequestIntentAllowsLaterBranchDerivedPullRequest() throws {
        let manager = TabManager()
        let workspace = manager.tabs[0]
        let panelId = try #require(workspace.focusedPanelId)

        _ = try #require(
            manager.handlePromptSubmit(
                workspaceId: workspace.id,
                message: "keep going on pull 26201",
                surfaceId: panelId,
                iMessageModeEnabled: false
            )
        )
        workspace.updatePanelPullRequest(
            panelId: panelId,
            number: 26201,
            label: "PR",
            url: try #require(URL(string: "https://github.com/CompanyCam/Company-Cam-API/pull/26201")),
            status: .open,
            branch: "codeowners-report-approved-status",
            source: .pullRequestLookup
        )

        #expect(workspace.panelPullRequests[panelId]?.number == 26201)
        #expect(workspace.pullRequest?.number == 26201)
        #expect(workspace.sidebarMetadata.workContext(panelId: panelId).pullRequest?.source == .promptMention)
        #expect(workspace.sidebarPullRequestsInDisplayOrder().map(\.number) == [26201])
    }

    @Test func testPromptBranchIntentAllowsLaterBranchDerivedPullRequest() throws {
        let manager = TabManager()
        let workspace = manager.tabs[0]
        let panelId = try #require(workspace.focusedPanelId)

        _ = try #require(
            manager.handlePromptSubmit(
                workspaceId: workspace.id,
                message: "work on branch codeowners-report-approved-status",
                surfaceId: panelId,
                iMessageModeEnabled: false
            )
        )
        workspace.updatePanelGitBranch(panelId: panelId, branch: "codeowners-report-approved-status", isDirty: false)
        workspace.updatePanelPullRequest(
            panelId: panelId,
            number: 26201,
            label: "PR",
            url: try #require(URL(string: "https://github.com/CompanyCam/Company-Cam-API/pull/26201")),
            status: .open,
            branch: "codeowners-report-approved-status",
            source: .pullRequestLookup
        )

        #expect(workspace.panelPullRequests[panelId]?.number == 26201)
        #expect(workspace.pullRequest?.number == 26201)
        #expect(workspace.sidebarPullRequestsInDisplayOrder().map(\.number) == [26201])
    }

    @Test func testPullRequestScopedWorktreeAllowsBranchDerivedPullRequestWithoutPromptIntent() throws {
        let manager = TabManager()
        let workspace = manager.tabs[0]
        let panelId = try #require(workspace.focusedPanelId)
        workspace.currentDirectory = "/private/tmp/companycam-pr-26201"

        workspace.updatePanelPullRequest(
            panelId: panelId,
            number: 26201,
            label: "PR",
            url: try #require(URL(string: "https://github.com/CompanyCam/Company-Cam-API/pull/26201")),
            status: .open,
            branch: "starter-template-auto-slugs",
            source: .pullRequestLookup
        )

        #expect(workspace.panelPullRequests[panelId]?.number == 26201)
        #expect(workspace.pullRequest?.number == 26201)
        #expect(workspace.sidebarPullRequestsInDisplayOrder().map(\.number) == [26201])
    }

    @Test func testPromptPullRequestURLSurvivesConflictingBranchDerivedPullRequest() throws {
        let manager = TabManager()
        let workspace = manager.tabs[0]
        let panelId = try #require(workspace.focusedPanelId)

        _ = try #require(
            manager.handlePromptSubmit(
                workspaceId: workspace.id,
                message: "seeing this on https://github.com/CompanyCam/Company-Cam-API/pull/26196",
                surfaceId: panelId,
                iMessageModeEnabled: false
            )
        )

        workspace.updatePanelPullRequest(
            panelId: panelId,
            number: 26201,
            label: "PR",
            url: try #require(URL(string: "https://github.com/CompanyCam/Company-Cam-API/pull/26201")),
            status: .open,
            branch: "codeowners-report-approved-status",
            source: .pullRequestLookup
        )

        #expect(workspace.panelPullRequests[panelId]?.number == 26196)
        #expect(workspace.pullRequest?.number == 26196)
        #expect(workspace.sidebarPullRequestsInDisplayOrder().map(\.number) == [26196])
    }

    @Test func testShortPromptPullRequestReferenceSurvivesBranchDerivedClear() throws {
        let manager = TabManager()
        let workspace = manager.tabs[0]
        let panelId = try #require(workspace.focusedPanelId)

        _ = try #require(
            manager.handlePromptSubmit(
                workspaceId: workspace.id,
                message: "keep going on pull 26201",
                surfaceId: panelId,
                iMessageModeEnabled: false
            )
        )

        workspace.updatePanelPullRequest(
            panelId: panelId,
            number: 26201,
            label: "PR",
            url: try #require(URL(string: "https://github.com/CompanyCam/Company-Cam-API/pull/26201")),
            status: .open,
            branch: "codeowners-report-approved-status",
            source: .pullRequestLookup
        )

        #expect(workspace.sidebarMetadata.workContext(panelId: panelId).pullRequest?.source == .promptMention)

        workspace.updatePanelPullRequest(
            panelId: panelId,
            number: 26196,
            label: "PR",
            url: try #require(URL(string: "https://github.com/CompanyCam/Company-Cam-API/pull/26196")),
            status: .open,
            branch: "codeowners-report-approved-status",
            source: .pullRequestLookup
        )
        manager.clearPanelPullRequest(workspaceId: workspace.id, panelId: panelId)

        #expect(workspace.panelPullRequests[panelId]?.number == 26201)
        #expect(workspace.pullRequest?.number == 26201)
        #expect(workspace.sidebarPullRequestsInDisplayOrder().map(\.number) == [26201])
    }

    @Test func testPullRequestMentionParserCanMatchSpecificPullRequestNumber() throws {
        let mention = try #require(Workspace.submittedPromptPullRequestMention(
            from: "compare https://github.com/manaflow-ai/bmux/pull/5314 with https://github.com/CompanyCam/Company-Cam-API/pull/26117",
            matchingNumber: 26117
        ))

        #expect(mention.number == 26117)
        #expect(mention.url.absoluteString == "https://github.com/CompanyCam/Company-Cam-API/pull/26117")
    }

    private func pullRequest(
        in workspace: Workspace,
        panelId: UUID,
        matchingTitle expectedTitle: String,
        maxYields: Int = 5_000
    ) async throws -> SidebarPullRequestState {
        for _ in 0..<maxYields {
            if let pullRequest = workspace.panelPullRequests[panelId],
               pullRequest.title == expectedTitle {
                return pullRequest
            }
            await Task.yield()
        }
        return try #require(workspace.panelPullRequests[panelId])
    }

    @Test func testAssistantFinalMessageReplacesStalePullRequestMentionWhenIMessageModeDisabled() throws {
        let manager = TabManager()
        let workspace = manager.tabs[0]
        let panelId = try #require(workspace.focusedPanelId)

        workspace.updatePanelPullRequest(
            panelId: panelId,
            number: 10356,
            label: "PR",
            url: try #require(URL(string: "https://github.com/CompanyCam/companycam-mobile/pull/10356")),
            status: .open,
            branch: "ste-1000-old-work"
        )

        let outcome = try #require(
            manager.handleAssistantFinalMessage(
                workspaceId: workspace.id,
                message: "Created branch ste-1890-rename-checklist-description-mobile and draft PR: https://github.com/CompanyCam/companycam-mobile/pull/10379",
                surfaceId: panelId,
                iMessageModeEnabled: false
            )
        )

        #expect(!outcome.messageRecorded)
        #expect(!outcome.reordered)
        let pullRequest = try #require(workspace.panelPullRequests[panelId])
        #expect(pullRequest.number == 10379)
        #expect(pullRequest.label == "PR")
        #expect(pullRequest.url.absoluteString == "https://github.com/CompanyCam/companycam-mobile/pull/10379")
        #expect(pullRequest.branch == nil)
        #expect(workspace.latestConversationMessage == nil)
        #expect(workspace.sidebarPullRequestsInDisplayOrder().map(\.number) == [10379])
    }

    @Test func testFeedPromptSubmitEventExtractsToolInputMessage() throws {
        let manager = TabManager()
        let first = manager.tabs[0]
        let second = manager.addWorkspace(select: false, placementOverride: .end)

        let event = WorkstreamEvent(
            sessionId: "opencode-session",
            hookEventName: .userPromptSubmit,
            source: "opencode",
            workspaceId: second.id.uuidString,
            toolInputJSON: #"{"prompt":"  shipped from feed\npath  "}"#,
            context: WorkstreamContext(lastUserMessage: "fallback message")
        )

        let outcome = try #require(
            manager.handlePromptSubmit(
                workspaceId: second.id,
                message: event.submittedPromptMessage,
                iMessageModeEnabled: true
            )
        )

        #expect(outcome.messageRecorded)
        #expect(outcome.reordered)
        #expect(manager.tabs.map(\.id) == [second.id, first.id])
        #expect(second.latestConversationMessage == "shipped from feed path")
    }

    @Test func testFeedPromptSubmitEventFallsBackToContextMessage() {
        let event = WorkstreamEvent(
            sessionId: "agent-session",
            hookEventName: .userPromptSubmit,
            source: "codex",
            workspaceId: UUID().uuidString,
            context: WorkstreamContext(lastUserMessage: "from context")
        )

        #expect(event.submittedPromptMessage == "from context")
    }

    @Test func testFeedPromptSubmitSkipsBlankContextBeforeExtraFields() {
        let event = WorkstreamEvent(
            sessionId: "agent-session",
            hookEventName: .userPromptSubmit,
            source: "codex",
            workspaceId: UUID().uuidString,
            context: WorkstreamContext(lastUserMessage: " \n "),
            extraFieldsJSON: #"{"message":"from extra fields"}"#
        )

        #expect(event.submittedPromptMessage == "from extra fields")
    }

    @Test func testFeedStopEventExtractsAssistantFinalMessageFromContext() {
        let event = WorkstreamEvent(
            sessionId: "agent-session",
            hookEventName: .stop,
            source: "codex",
            workspaceId: UUID().uuidString,
            context: WorkstreamContext(assistantPreamble: "  finished\n\nthis  ")
        )

        #expect(event.assistantFinalMessage == "finished this")
    }

    @Test func testFeedStopEventExtractsAssistantFinalMessageFromExtraFields() {
        let event = WorkstreamEvent(
            sessionId: "agent-session",
            hookEventName: .stop,
            source: "codex",
            workspaceId: UUID().uuidString,
            extraFieldsJSON: #"{"last_assistant_message":"  done\nfrom extra fields  "}"#
        )

        #expect(event.assistantFinalMessage == "done from extra fields")
    }

    @Test func testFeedSubagentStopDoesNotExtractParentAssistantFinalMessage() {
        let event = WorkstreamEvent(
            sessionId: "agent-session",
            hookEventName: .subagentStop,
            source: "codex",
            workspaceId: UUID().uuidString,
            context: WorkstreamContext(assistantPreamble: "subagent finished")
        )

        #expect(event.assistantFinalMessage == nil)
    }

    @Test func testBlankSubmittedMessageDoesNotClearRecordedPreview() {
        let workspace = Workspace()

        #expect(workspace.recordSubmittedMessage("keep this preview"))
        #expect(!workspace.recordSubmittedMessage(" \n "))
        #expect(workspace.latestConversationMessage == "keep this preview")
        #expect(workspace.latestSubmittedAt != nil)
    }

    @Test func testIMessageModeUsesManagedSettingsKey() throws {
        let suiteName = "bmux.iMessageMode.test.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(IMessageModeSettings.key == "app.iMessageMode")
        #expect(!IMessageModeSettings.isEnabled(defaults: defaults))
        defaults.set(true, forKey: IMessageModeSettings.key)
        #expect(IMessageModeSettings.isEnabled(defaults: defaults))
    }

    @Test func assistantFinalMessageUsesCodexTranscriptPullRequestMentionWhenHookMessageOmitsIt() throws {
        let manager = TabManager()
        let workspace = manager.tabs[0]
        let panelId = try #require(workspace.focusedPanelId)
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-codex-pr-transcript-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let transcriptURL = tempDir.appendingPathComponent("rollout-session.jsonl")
        let transcript = try Self.codexTranscriptMessageLine(
            role: "assistant",
            text: "I reviewed https://github.com/CompanyCam/companycam-mobile/pull/10379 and found the failing tab update path."
        ) + "\n"
        try transcript.write(to: transcriptURL, atomically: true, encoding: .utf8)
        let event = WorkstreamEvent(
            sessionId: "codex-session",
            hookEventName: .stop,
            source: "codex",
            workspaceId: workspace.id.uuidString,
            surfaceId: panelId.uuidString,
            transcriptPath: transcriptURL.path,
            context: WorkstreamContext(assistantPreamble: "I reviewed the PR and found the issue.")
        )

        let outcome = try #require(
            manager.handleAssistantFinalMessage(
                workspaceId: workspace.id,
                message: event.assistantFinalMessageForWorkspaceSidebar(),
                surfaceId: panelId,
                iMessageModeEnabled: false
            )
        )

        #expect(!outcome.messageRecorded)
        #expect(!outcome.reordered)
        let pullRequest = try #require(workspace.panelPullRequests[panelId])
        #expect(pullRequest.number == 10379)
        #expect(pullRequest.url.absoluteString == "https://github.com/CompanyCam/companycam-mobile/pull/10379")
        #expect(workspace.sidebarPullRequestsInDisplayOrder().map(\.number) == [10379])
    }

    private static func codexTranscriptMessageLine(role: String, text: String) throws -> String {
        let blockType = role == "assistant" ? "output_text" : "input_text"
        return try codexTranscriptLine(
            type: "response_item",
            payload: [
                "type": "message",
                "role": role,
                "content": [
                    ["type": blockType, "text": text],
                ],
            ]
        )
    }

    private static func codexTranscriptLine(
        type: String,
        payload: [String: Any],
        timestamp: String = "2026-06-11T21:38:05.381Z"
    ) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: [
            "timestamp": timestamp,
            "type": type,
            "payload": payload,
        ])
        return String(decoding: data, as: UTF8.self)
    }
}
