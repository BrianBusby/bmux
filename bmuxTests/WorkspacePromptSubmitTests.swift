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

    @Test func testReactAgentPromptSubmitAppliesPromptSeedTitleOverAgentSeed() throws {
        let manager = TabManager(initialWorkingDirectory: "/tmp/bmux")
        let workspace = try #require(manager.selectedWorkspace)
        workspace.setCustomTitle("bmux (Codex)", source: .agentSeed)
        let paneId = try #require(workspace.bonsplitController.allPaneIds.first)
        let agentPanel = try #require(
            workspace.newAgentSessionSurface(
                inPane: paneId,
                rendererKind: .react,
                focus: true
            )
        )
        let prompt = "ok let's talk about how we can improve bmux"

        agentPanel.onPromptSubmitted?(prompt)

        #expect(workspace.latestConversationMessage == prompt)
        #expect(workspace.customTitle == prompt)
        #expect(workspace.effectiveCustomTitleSource == .agentSeed)
        #expect(manager.resolvedWorkspaceDisplayTitle(for: workspace) == prompt)
        #expect(workspace.panelTitle(panelId: agentPanel.id) == prompt)
    }

    @Test func testReactAgentPromptSeedDoesNotReplaceSummaryTitle() throws {
        let manager = TabManager(initialWorkingDirectory: "/tmp/bmux")
        let workspace = try #require(manager.selectedWorkspace)
        let paneId = try #require(workspace.bonsplitController.allPaneIds.first)
        let agentPanel = try #require(
            workspace.newAgentSessionSurface(
                inPane: paneId,
                rendererKind: .react,
                focus: true
            )
        )
        workspace.setCustomTitle("Summarized title", source: .autoSummary)
        workspace.setPanelCustomTitle(panelId: agentPanel.id, title: "Summarized title", source: .autoSummary)

        agentPanel.onPromptSubmitted?("replace this with raw prompt text")

        #expect(workspace.latestConversationMessage == "replace this with raw prompt text")
        #expect(workspace.customTitle == "Summarized title")
        #expect(workspace.effectiveCustomTitleSource == .autoSummary)
        #expect(workspace.panelTitle(panelId: agentPanel.id) == "Summarized title")
        #expect(workspace.panelCustomTitleSources[agentPanel.id] == .autoSummary)
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
}
