import BMUXAgentLaunch
import BmuxAgentChat
import BmuxFoundation
import BmuxGit
import Combine
import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite(.serialized)
struct ConnectedPromptResourceProjectionTests {
    @Test func transcriptPromptEnrichesPRTicketAndCardWithoutChangingStoredPromptOrTitle() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        await fixture.ingest("Review https://github.com/CompanyCam/companycam-mobile/pull/11713")
        let request = try #require(fixture.workspace.panelPullRequests[fixture.panelID])
        #expect(request.number == 11713)
        await fixture.prRuntime.waitForSubmittedPullRequestMentionRefreshesForTesting()
        #expect(fixture.workspace.panelPullRequests[fixture.panelID]?.title == "INP-2431 Follow-up controls")
        #expect(fixture.workspace.panelPullRequests[fixture.panelID]?.ownerLogin == "BrianBusby")
        fixture.runtime.observeWorkspaces([fixture.workspace])
        await fixture.runtime.waitForBackgroundTasks()
        let display = try #require(try await fixture.client.workspaceDisplay(.init(
            workspaceID: fixture.workspace.stableId.uuidString
        )).display)
        let snapshot = try #require(WorkspaceDisplayCurrentStateSnapshot(display))
        let card = WorkspaceReferenceCardSnapshot(
            workspace: fixture.workspace, provenance: snapshot, workspaceTitle: "CompanyCam mobile"
        )
        #expect(card.ticketID == "INP-2431")
        #expect(card.title == "Follow-up controls")
        #expect(card.summary == "CompanyCam mobile")
        #expect(card.pullRequestURL?.absoluteString == "https://github.com/CompanyCam/companycam-mobile/pull/11713")
        #expect(display.pullRequestOwnerLogin == "BrianBusby")
        #expect(card.projectTitle == "Mobile workflows")
        #expect(card.prompt == "Review https://github.com/CompanyCam/companycam-mobile/pull/11713")
        #expect(card.branch == nil)
        #expect(fixture.workspace.latestSubmittedMessage == nil)
        #expect(fixture.workspace.customDescription == nil)
        #expect(fixture.workspace.customTitle == fixture.originalTitle)
    }

    @Test func replayAndOlderBackfillDoNotRepeatLookupOrReplaceNewerPrompt() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let first = "Review https://github.com/CompanyCam/companycam-mobile/pull/11713"
        let second = "Review https://github.com/CompanyCam/companycam-mobile/pull/11714"
        await fixture.ingest(first, offset: 1)
        _ = try #require(fixture.workspace.panelPullRequests[fixture.panelID])
        await fixture.prRuntime.waitForSubmittedPullRequestMentionRefreshesForTesting()
        await fixture.ingest(first, offset: 1)
        await fixture.ingest(second, offset: 2)
        await fixture.prRuntime.waitForSubmittedPullRequestMentionRefreshesForTesting()
        await fixture.ingest(first, offset: 1)
        await fixture.prRuntime.waitForSubmittedPullRequestMentionRefreshesForTesting()
        #expect(fixture.workspace.panelPullRequests[fixture.panelID]?.number == 11714)
        #expect(await fixture.runner.count == 2)
    }

    @Test func replacedSessionOnSamePanelRejectsDelayedOldPrompt() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        await fixture.recorderGit.holdNextSnapshot()
        fixture.pendingText = "Review https://github.com/CompanyCam/companycam-mobile/pull/11713"
        await fixture.service.start().value
        await fixture.service.waitForPromptEvidenceTasks()
        await fixture.recorderGit.waitUntilHeld()
        fixture.registry.noteResumeInitiated(
            sessionID: "replacement-session", source: "codex", surfaceID: fixture.panelID.uuidString,
            workspaceID: fixture.workspace.id.uuidString, workingDirectory: fixture.root.path
        )
        await fixture.recorderGit.release()
        await fixture.runtime.waitForBackgroundTasks()
        #expect(fixture.workspace.panelPullRequests[fixture.panelID] == nil)
        #expect(await fixture.runner.count == 0)
    }

    @Test(arguments: [false, true])
    func ambiguousLiveSessionsCannotUseRecencyToAuthorizeResources(lowercaseSurface: Bool) async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        fixture.registry.noteResumeInitiated(
            sessionID: "sibling-session", source: "codex",
            surfaceID: lowercaseSurface ? fixture.panelID.uuidString.lowercased() : fixture.panelID.uuidString,
            workspaceID: fixture.workspace.id.uuidString, workingDirectory: fixture.root.path
        )
        // Make the original indexed session newest while retaining the ambiguity.
        fixture.registry.update(sessionID: fixture.record.sessionID) { $0.lastActivityAt = Date().addingTimeInterval(1) }
        await fixture.ingest("Review https://github.com/CompanyCam/companycam-mobile/pull/11713")
        #expect(fixture.workspace.panelPullRequests.isEmpty)
        #expect(await fixture.runner.count == 0)
    }

    @Test func overlappingOlderPersistenceCannotReplaceNewerResources() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        await fixture.recorderGit.holdNextSnapshot()
        fixture.pendingText = "Review https://github.com/CompanyCam/companycam-mobile/pull/11713"
        await fixture.service.start().value
        await fixture.service.waitForPromptEvidenceTasks()
        await fixture.recorderGit.waitUntilHeld()
        fixture.pendingText = "Review https://github.com/CompanyCam/companycam-mobile/pull/11714"
        fixture.offset = 2
        await fixture.service.start().value
        await fixture.service.waitForPromptEvidenceTasks()
        await fixture.runner.waitForInvocation()
        await fixture.prRuntime.waitForSubmittedPullRequestMentionRefreshesForTesting()
        await fixture.recorderGit.release()
        await fixture.runtime.waitForBackgroundTasks()
        await fixture.prRuntime.waitForSubmittedPullRequestMentionRefreshesForTesting()
        #expect(fixture.workspace.panelPullRequests[fixture.panelID]?.number == 11714)
        #expect(await fixture.runner.count == 1)
    }

    @Test func missingRecordedPanelNeverFallsBackToFocusedSibling() async throws {
        let fixture = try Fixture(recordedPanelID: UUID())
        defer { fixture.remove() }
        await fixture.ingest("Review https://github.com/CompanyCam/companycam-mobile/pull/11713")
        #expect(fixture.workspace.panelPullRequests.isEmpty)
        #expect(await fixture.runner.count == 0)
    }

    @Test func stopWhilePersistenceIsPendingPreventsMetadataReplay() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        await fixture.recorderGit.holdNextSnapshot()
        fixture.pendingText = "Review https://github.com/CompanyCam/companycam-mobile/pull/11713"
        await fixture.service.start().value
        await fixture.service.waitForPromptEvidenceTasks()
        await fixture.recorderGit.waitUntilHeld()
        // Enter the draining operation before stop removes the runtime's task handles.
        var pendingCompletion: Task<Void, Never>?
        await withCheckedContinuation { started in
            pendingCompletion = Task { @MainActor in
                started.resume()
                await fixture.runtime.waitForBackgroundTasks()
            }
        }
        fixture.runtime.stop()
        await fixture.recorderGit.release()
        await pendingCompletion?.value
        #expect(fixture.workspace.panelPullRequests.isEmpty)
        #expect(await fixture.runner.count == 0)
    }

    @Test func unseenOlderBatchCannotUseANewerAcceptedPEPrompt() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try await fixture.recordDirectly("Review https://github.com/CompanyCam/companycam-mobile/pull/11714", offset: 2)
        await fixture.ingest("Review https://github.com/CompanyCam/companycam-mobile/pull/11713", offset: 1)
        #expect(fixture.workspace.panelPullRequests.isEmpty)
        #expect(await fixture.runner.count == 0)
    }

    @Test func failedFreshReadCannotReplayCachedPromptAndRetryCan() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let prompt = "Review https://github.com/CompanyCam/companycam-mobile/pull/11713"
        try await fixture.recordDirectly(prompt, offset: 1)
        _ = await fixture.displayStore.refreshedSnapshot(stableWorkspaceID: fixture.workspace.stableId)
        await fixture.recorderClient.setRejectsRead(true)
        await fixture.ingest(prompt)
        #expect(fixture.workspace.panelPullRequests.isEmpty)
        #expect(await fixture.runner.count == 0)
        await fixture.recorderClient.setRejectsRead(false)
        await fixture.ingest(prompt)
        #expect(fixture.workspace.panelPullRequests[fixture.panelID]?.number == 11713)
    }

    @Test func failedPersistenceCannotAuthorizeResourcesAndRetryCan() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        await fixture.recorderClient.setRejectsAppend(true)
        await fixture.ingest("Review https://github.com/CompanyCam/companycam-mobile/pull/11713")
        #expect(fixture.workspace.panelPullRequests.isEmpty)
        #expect(await fixture.runner.count == 0)
        await fixture.recorderClient.setRejectsAppend(false)
        await fixture.ingest("Review https://github.com/CompanyCam/companycam-mobile/pull/11713")
        #expect(fixture.workspace.panelPullRequests[fixture.panelID]?.number == 11713)
    }

    @Test func authorizationReadLeavesPromptPublicationAndNotificationToRefresh() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        // This store has no pending startup refresh, so the authorization read wins deterministically.
        let store = WorkspaceDisplayCurrentStateStore(client: fixture.client)
        defer { store.cancelRefreshes() }
        _ = await store.refreshedSnapshot(stableWorkspaceID: fixture.workspace.stableId)
        let prompt = "Compare the new gutter photos"
        try await fixture.recordDirectly(prompt, offset: 1)
        let fresh = try await store.freshSnapshot(stableWorkspaceID: fixture.workspace.stableId)
        #expect(fresh?.lastSubmittedPrompt == prompt)
        try #require(store.snapshot(stableWorkspaceID: fixture.workspace.stableId)?.lastSubmittedPrompt == nil)

        var observationCount = 0
        var publishedPrompt: String?
        var publication: CheckedContinuation<Void, Never>?
        var isPublishing = false
        let cancellable = fixture.workspace.sidebarImmediateObservationChangeSubject.sink {
            // Other runtime refreshes use this subject; observe this store's synchronous publication.
            guard isPublishing else { return }
            observationCount += 1
            publishedPrompt = store.snapshot(stableWorkspaceID: fixture.workspace.stableId)?.lastSubmittedPrompt
            publication?.resume()
            publication = nil
        }
        defer { cancellable.cancel() }
        await withCheckedContinuation { continuation in
            publication = continuation
            store.refresh(stableWorkspaceID: fixture.workspace.stableId) { stableWorkspaceID in
                isPublishing = true
                #expect(WorkProvenanceRuntime.notifyWorkspaceDisplayCurrentStateDidChange(
                    stableWorkspaceID: stableWorkspaceID, in: [fixture.manager]
                ))
                isPublishing = false
            }
        }
        #expect(observationCount == 1)
        #expect(publishedPrompt == prompt)
        #expect(fixture.workspace.panelPullRequests.isEmpty)
    }

    @MainActor
    private final class Fixture {
        let root: URL
        let client: any ProvenanceEngineContracts.ProvenanceEngineClient
        let recorderClient: PromptClient
        let displayStore: WorkspaceDisplayCurrentStateStore
        let recorderGit = GatedGitInspector()
        let registry: AgentChatSessionRegistry
        let runner = MetadataRunner()
        let prRuntime: SidebarGitPullRequestObservationRuntimeService
        let manager: TabManager
        let workspace: Workspace
        let panelID: UUID
        let originalTitle: String
        let runtime: WorkProvenanceRuntime
        let record: AgentChatSessionRecord
        let baseDate = Date(timeIntervalSinceReferenceDate: (812345678.1234567).nextUp)
        var pendingText = ""
        var offset: TimeInterval = 1

        lazy var service: AgentChatTranscriptService = {
            let service = AgentChatTranscriptService(
                registry: registry,
                resolver: AgentChatTranscriptResolver(homeDirectory: root, environment: ["CODEX_HOME": root.path]),
                hasEventSubscribers: { false }, emitEventPayload: { _ in },
                promptEvidenceSeeder: { [weak self] _, _, _, recordPrompts in
                    Task { @MainActor in
                        guard let self else { return }
                        recordPrompts(self.record, [ChatMessage(
                            id: "prompt-\(self.offset)", seq: 1, role: .user,
                            timestamp: self.baseDate.addingTimeInterval(self.offset),
                            kind: .prose(ChatProse(text: self.pendingText))
                        )])
                    }
                },
                recordTaskWorkspaceDirectory: { _, _ in }
            )
            service.recordSessionLifecycleChanges(with: runtime)
            return service
        }()

        init(recordedPanelID: UUID? = nil) throws {
            root = FileManager.default.temporaryDirectory.appendingPathComponent("connected-prompt-\(getpid())-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            recorderClient = PromptClient(
                backing: try ProvenanceEngineClientFactory().sqliteClient(databaseURL: root.appendingPathComponent("provenance.sqlite")),
                root: root
            )
            client = recorderClient
            displayStore = WorkspaceDisplayCurrentStateStore(client: recorderClient)
            let harness = SidebarGitPullRequestRuntimeTestHarness(promptMentionCommandRunner: runner)
            prRuntime = SidebarGitPullRequestObservationRuntimeService(isCapabilityEnabled: true, dependencies: harness.dependencies())
            manager = TabManager(sidebarGitPullRequestObservation: prRuntime.tabManagerObservationServices())
            workspace = try #require(manager.selectedWorkspace)
            panelID = try #require(workspace.focusedPanelId)
            workspace.setCustomTitle("CompanyCam mobile")
            originalTitle = workspace.customTitle ?? workspace.title
            workspace.currentDirectory = root.path
            registry = AgentChatSessionRegistry(hookStore: AgentChatHookSessionStore(homeDirectory: root))
            registry.noteResumeInitiated(
                sessionID: "connected-session", source: "codex", surfaceID: (recordedPanelID ?? panelID).uuidString,
                workspaceID: workspace.id.uuidString, workingDirectory: root.path
            )
            record = try #require(registry.record(sessionID: "connected-session"))
            runtime = WorkProvenanceRuntime(
                observationService: WorkProvenanceObservationService(
                    client: client, gitInspector: EmptyGitInspector(),
                    ticketLinkResolver: WorkProvenanceLinearTicketLinkResolver(
                        authorizationHeader: "fixture-authorization", usesEnvironmentAuthorization: false,
                        dataProvider: { _ in
                            (Data("""
                            {"data":{"issue":{"title":"Follow-up controls","url":"https://linear.app/companycam/issue/INP-2431","project":{"id":"mobile","name":"Mobile workflows","url":"https://linear.app/companycam/project/mobile"}}}}
                            """.utf8), 200)
                        }
                    )
                ),
                workspaceDisplayCurrentStateStore: displayStore,
                codingAgentEvidenceRecorder: WorkProvenanceCodingAgentEvidenceRecorder(client: recorderClient, gitInspector: recorderGit)
            )
            prRuntime.start(host: manager)
            runtime.start(tabManager: manager)
        }

        func ingest(_ text: String, offset: TimeInterval = 1) async {
            pendingText = text
            self.offset = offset
            await service.start().value
            await service.waitForPromptEvidenceTasks()
            await runtime.waitForBackgroundTasks()
        }

        func recordDirectly(_ text: String, offset: TimeInterval) async throws {
            try await WorkProvenanceCodingAgentEvidenceRecorder(client: recorderClient, gitInspector: recorderGit)
                .recordTranscriptUserPrompts(record: record, messages: [ChatMessage(
                    id: "direct-\(offset)", seq: 1, role: .user,
                    timestamp: baseDate.addingTimeInterval(offset), kind: .prose(ChatProse(text: text))
                )], stableWorkspaceID: workspace.stableId)
        }

        func remove() {
            runtime.stop()
            prRuntime.stop()
            // PromptClient releases the underlying SDK client before deleting its root
            // when the final runtime/cache/task reference is gone.
        }
    }

    private struct EmptyGitInspector: WorkProvenanceGitInspecting {
        func snapshot(for directory: String) async -> WorkProvenanceGitSnapshot? { nil }
    }

    private actor GatedGitInspector: WorkProvenanceGitInspecting {
        private var shouldHold = false
        private var continuation: CheckedContinuation<Void, Never>?
        private var heldWaiter: CheckedContinuation<Void, Never>?
        func holdNextSnapshot() { shouldHold = true }
        func waitUntilHeld() async {
            if continuation != nil { return }
            await withCheckedContinuation { heldWaiter = $0 }
        }
        func release() { continuation?.resume(); continuation = nil }
        func snapshot(for directory: String) async -> WorkProvenanceGitSnapshot? {
            if shouldHold {
                shouldHold = false
                await withCheckedContinuation { continuation = $0; heldWaiter?.resume(); heldWaiter = nil }
            }
            return nil
        }
    }

    private actor MetadataRunner: CommandRunning {
        private(set) var count = 0
        private var invocationWaiter: CheckedContinuation<Void, Never>?
        func waitForInvocation() async {
            if count > 0 { return }
            await withCheckedContinuation { invocationWaiter = $0 }
        }
        func run(directory: String, executable: String, arguments: [String], timeout: TimeInterval?) async -> CommandResult {
            count += 1
            invocationWaiter?.resume(); invocationWaiter = nil
            let number = arguments.contains(where: { $0.hasSuffix("11714") }) ? 11714 : 11713
            return .successJSON("""
            {"number":\(number),"state":"OPEN","title":"INP-2431 Follow-up controls","url":"https://github.com/CompanyCam/companycam-mobile/pull/\(number)","author":{"login":"BrianBusby","url":"https://github.com/BrianBusby"}}
            """)
        }
    }

    private actor PromptClient: ProvenanceEngineContracts.ProvenanceEngineClient {
        private var backing: (any ProvenanceEngineContracts.ProvenanceEngineClient)?
        private let root: URL
        private var rejectsAppend = false
        private var rejectsRead = false
        init(backing: any ProvenanceEngineContracts.ProvenanceEngineClient, root: URL) {
            self.backing = backing
            self.root = root
        }
        deinit {
            // This wrapper is the sole owner of the SDK client; deinitializing it closes SQLite.
            backing = nil
            try? FileManager.default.removeItem(at: root)
        }
        func setRejectsAppend(_ value: Bool) { rejectsAppend = value }
        func setRejectsRead(_ value: Bool) { rejectsRead = value }
        func health() async throws -> ProvenanceEngineHealth { try await backing!.health() }
        func appendEvent(_ request: ProvenanceEngineContracts.ProvenanceAppendEventRequest) async throws -> ProvenanceEngineContracts.ProvenanceAppendEventResponse {
            if rejectsAppend && request.event.eventType == .codingAgentPromptSubmitted { throw NSError(domain: "PromptPersistence", code: 1) }
            return try await backing!.appendEvent(request)
        }
        func recordSessionLifecycle(_ request: ProvenanceEngineContracts.ProvenanceSessionLifecycleRequest) async -> ProvenanceEngineContracts.ProvenanceSessionLifecycleResponse {
            await backing!.recordSessionLifecycle(request)
        }
        func sessionTree(_ request: ProvenanceEngineContracts.ProvenanceSessionTreeRequest) async throws -> ProvenanceEngineContracts.ProvenanceSessionTreeResponse { try await backing!.sessionTree(request) }
        func fileExplanation(_ request: ProvenanceEngineContracts.ProvenanceFileExplanationRequest) async throws -> ProvenanceEngineContracts.ProvenanceFileExplanationResponse { try await backing!.fileExplanation(request) }
        func worktrees(_ request: ProvenanceEngineContracts.ProvenanceWorktreeListRequest) async throws -> ProvenanceEngineContracts.ProvenanceWorktreeListResponse { try await backing!.worktrees(request) }
        func currentContext(_ request: ProvenanceEngineContracts.ProvenanceCurrentContextRequest) async throws -> ProvenanceEngineContracts.ProvenanceCurrentContextResponse { try await backing!.currentContext(request) }
        func workspaceDisplay(_ request: ProvenanceEngineContracts.ProvenanceWorkspaceDisplayRequest) async throws -> ProvenanceEngineContracts.ProvenanceWorkspaceDisplayResponse {
            if rejectsRead { throw NSError(domain: "PromptDisplayRead", code: 1) }
            return try await backing!.workspaceDisplay(request)
        }
        func workspaceCodingAgentSessionAssociation(_ request: ProvenanceEngineContracts.ProvenanceWorkspaceCodingAgentSessionAssociationRequest) async throws -> ProvenanceEngineContracts.ProvenanceWorkspaceCodingAgentSessionAssociationResponse {
            try await backing!.workspaceCodingAgentSessionAssociation(request)
        }
        func factualSessionProjection(_ request: ProvenanceEngineContracts.ProvenanceFactualSessionProjectionRequest) async throws -> ProvenanceEngineContracts.ProvenanceFactualSessionProjectionResponse { try await backing!.factualSessionProjection(request) }
    }
}
