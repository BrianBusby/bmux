import BmuxFoundation
import BmuxGit
import BmuxSettings
import BmuxSidebar
import BmuxSidebarGit
import BmuxSwiftRender
import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite(.serialized)
struct SidebarGitPullRequestRuntimeCompositionTests {
    @Test func currentXCTestProcessDisablesSidebarGitPullRequestObservationByDefault() throws {
        let homeDirectory = try Self.temporaryDirectory(named: "default-disabled")
        let harness = SidebarGitPullRequestRuntimeTestHarness()
        let configuration = BmuxAppRuntimeConfiguration.currentProcess(
            environment: [
                "XCTestConfigurationFilePath": "/tmp/bmux.xctestconfiguration",
                "HOME": homeDirectory.path,
            ],
            fileManager: .default
        )
        let services = Self.runtimeServices(
            homeDirectory: homeDirectory,
            configuration: configuration,
            harness: harness
        )
        let manager = TabManager(
            sidebarGitPullRequestObservation: services.tabManagerSidebarGitPullRequestObservationServices()
        )

        services.start(tabManager: manager)

        #expect(configuration.processKind == BmuxAppRuntimeProcessKind.xctestHost)
        #expect(!configuration.enables(BmuxAppRuntimeCapability.sidebarGitPullRequestObservation))
        #expect(services.sidebarGitPullRequestObservationLifecycleState == .disabled(reason: "disabled by composition"))
        #expect(services.startCount(for: BmuxAppRuntimeCapability.sidebarGitPullRequestObservation) == 0)
        #expect(harness.validateRequiredRuntimeCount == 0)
        #expect(harness.makeHostServicesCount == 0)
        #expect(!FileManager.default.fileExists(atPath: Self.databaseURL(in: homeDirectory).path))
    }

    @Test func productionProcessEnablesSidebarGitPullRequestObservationCapability() throws {
        let homeDirectory = try Self.temporaryDirectory(named: "production-capability")
        let configuration = BmuxAppRuntimeConfiguration.currentProcess(
            environment: ["HOME": homeDirectory.path],
            fileManager: .default
        )

        #expect(configuration.processKind == BmuxAppRuntimeProcessKind.productionApp)
        #expect(configuration.enables(BmuxAppRuntimeCapability.sidebarGitPullRequestObservation))
        #expect(configuration.enables(BmuxAppRuntimeCapability.browserAndDevTools))
        #expect(configuration.enables(BmuxAppRuntimeCapability.mobileHostAndPresence))
        #expect(configuration.enables(BmuxAppRuntimeCapability.workProvenanceObservation))
    }

    @Test func explicitTestCompositionStartsInjectedObservationAndReachesReadinessWithoutSleeping() throws {
        let homeDirectory = try Self.temporaryDirectory(named: "opt-in")
        let harness = SidebarGitPullRequestRuntimeTestHarness()
        let services = Self.runtimeServices(homeDirectory: homeDirectory, harness: harness)
        let manager = TabManager(
            sidebarGitPullRequestObservation: services.tabManagerSidebarGitPullRequestObservationServices()
        )
        let workspace = try #require(manager.selectedWorkspace)
        let panelId = try #require(workspace.focusedPanelId)

        services.start(tabManager: manager)
        services.start(tabManager: manager)
        services.attachSidebarGitPullRequestObservation(tabManager: manager)

        let service = try #require(harness.services.first)
        #expect(services.sidebarGitPullRequestObservationLifecycleState == .ready)
        #expect(services.sidebarGitPullRequestObservationLifecycleState.canAcceptWorkspaceEvents)
        #expect(services.startCount(for: BmuxAppRuntimeCapability.sidebarGitPullRequestObservation) == 1)
        #expect(harness.validateRequiredRuntimeCount == 1)
        #expect(harness.makeHostServicesCount == 1)
        #expect(service.attachCount == 2)
        #expect(service.initialGitRefreshes == [RecordedInitialGitRefresh(workspaceId: workspace.id, panelId: panelId, reason: "runtimeStart")])
        #expect(service.pullRequestRefreshReasons == ["runtimeStart"])
    }

    @Test func initialWorkspaceObservationPublishesOneFactSetToSidebarCustomSocketAndWorkspaceDisplay() throws {
        let homeDirectory = try Self.temporaryDirectory(named: "consumer-consistency")
        let harness = SidebarGitPullRequestRuntimeTestHarness(
            publishObservedFactsOnInitialRefresh: true
        )
        let services = Self.runtimeServices(homeDirectory: homeDirectory, harness: harness)
        let manager = TabManager(
            sidebarGitPullRequestObservation: services.tabManagerSidebarGitPullRequestObservationServices()
        )
        let workspace = try #require(manager.selectedWorkspace)
        let panelId = try #require(workspace.focusedPanelId)

        services.start(tabManager: manager)

        let branch = try #require(workspace.panelGitBranches[panelId])
        let pullRequest = try #require(workspace.panelPullRequests[panelId])
        let sidebarRows = SidebarWorkspaceSnapshotBuilder.pullRequestDisplays(
            livePullRequests: workspace.sidebarPullRequestsInDisplayOrder(),
            provenancePullRequest: nil,
            provenanceCurrentDirectory: nil,
            provenanceBranch: nil,
            latestSubmittedMessage: workspace.latestSubmittedMessage,
            latestConversationMessage: workspace.latestConversationMessage,
            label: "PR"
        )
        let customSnapshot = workspace.customSidebarWorkspaceSnapshot(
            index: 0,
            selectedId: workspace.id,
            unreadCount: 0
        )
        let customPRFields = try #require(Self.firstCustomPullRequestFields(customSnapshot.pullRequestValues))
        let previousActiveManager = TerminalController.shared.activeTabManagerForCallerNotification()
        TerminalController.shared.setActiveTabManager(manager)
        defer { TerminalController.shared.setActiveTabManager(previousActiveManager) }
        let socketSnapshot = try #require(TerminalController.shared.controlSidebarStateSnapshot(tabArg: workspace.id.uuidString))
        let workspaceDisplaySnapshot = WorkProvenanceWorkspaceSnapshot(workspace: workspace)

        #expect(branch.branch == "feature/pr-5314-runtime")
        #expect(branch.isDirty)
        #expect(pullRequest.number == 5314)
        #expect(pullRequest.ownerLogin == "octocat")
        #expect(sidebarRows.first?.number == pullRequest.number)
        #expect(sidebarRows.first?.branch == branch.branch)
        #expect(customSnapshot.gitBranch == branch.branch)
        #expect(customSnapshot.gitIsDirty)
        #expect(customPRFields["number"] == .int(pullRequest.number))
        #expect(customPRFields["owner"] == .string("octocat"))
        #expect(socketSnapshot.gitBranch?.branch == branch.branch)
        #expect(socketSnapshot.gitBranch?.isDirty == true)
        #expect(socketSnapshot.firstPullRequest?.number == pullRequest.number)
        #expect(socketSnapshot.firstPullRequest?.ownerLogin == "octocat")
        #expect(workspaceDisplaySnapshot.branch == branch.branch)
        #expect(workspaceDisplaySnapshot.pullRequest?.number == pullRequest.number)
        #expect(workspaceDisplaySnapshot.pullRequest?.ownerLogin == "octocat")
    }

    @Test func oneWorkspaceGitFailureDoesNotDestroyUnrelatedWorkspaceState() throws {
        let homeDirectory = try Self.temporaryDirectory(named: "partial-failure")
        let failedWorkspaceIds = SidebarGitPullRequestRuntimeFailureSet()
        let harness = SidebarGitPullRequestRuntimeTestHarness(
            publishObservedFactsOnInitialRefresh: true,
            shouldFailWorkspace: { failedWorkspaceIds.contains($0) }
        )
        let services = Self.runtimeServices(homeDirectory: homeDirectory, harness: harness)
        let manager = TabManager(
            sidebarGitPullRequestObservation: services.tabManagerSidebarGitPullRequestObservationServices()
        )
        let failedWorkspace = try #require(manager.selectedWorkspace)
        let healthyWorkspace = manager.addWorkspace(title: "Healthy PR workspace", select: false)
        failedWorkspaceIds.insert(failedWorkspace.id)

        services.start(tabManager: manager)

        #expect(failedWorkspace.gitBranch == nil)
        #expect(failedWorkspace.pullRequest == nil)
        #expect(healthyWorkspace.gitBranch?.branch == "feature/pr-5314-runtime")
        #expect(healthyWorkspace.pullRequest?.number == 5314)
        #expect(services.sidebarGitPullRequestObservationLifecycleState == .ready)
    }

    @Test func degradedAndFailedStartupStatesAreObservableAndLocalToTheRuntime() throws {
        let degradedHomeDirectory = try Self.temporaryDirectory(named: "degraded")
        let degradedHarness = SidebarGitPullRequestRuntimeTestHarness(
            validateRequiredRuntimeResult: .degraded(reason: "gh unavailable or unauthenticated")
        )
        let degradedServices = Self.runtimeServices(homeDirectory: degradedHomeDirectory, harness: degradedHarness)
        let degradedManager = TabManager(
            sidebarGitPullRequestObservation: degradedServices.tabManagerSidebarGitPullRequestObservationServices()
        )

        degradedServices.start(tabManager: degradedManager)

        #expect(degradedServices.sidebarGitPullRequestObservationLifecycleState == .degraded(reason: "gh unavailable or unauthenticated"))
        #expect(degradedServices.sidebarGitPullRequestObservationLifecycleState.canAcceptWorkspaceEvents)
        #expect(degradedHarness.validateRequiredRuntimeCount == 1)
        #expect(degradedHarness.makeHostServicesCount == 1)

        let failedHomeDirectory = try Self.temporaryDirectory(named: "failed")
        let failedHarness = SidebarGitPullRequestRuntimeTestHarness(
            validateRequiredRuntimeResult: .failed(reason: "sidebar git observation unavailable")
        )
        let failedServices = Self.runtimeServices(homeDirectory: failedHomeDirectory, harness: failedHarness)
        let failedManager = TabManager(
            sidebarGitPullRequestObservation: failedServices.tabManagerSidebarGitPullRequestObservationServices()
        )

        failedServices.start(tabManager: failedManager)

        #expect(failedServices.sidebarGitPullRequestObservationLifecycleState == .failed(reason: "sidebar git observation unavailable"))
        #expect(!failedServices.sidebarGitPullRequestObservationLifecycleState.canAcceptWorkspaceEvents)
        #expect(failedServices.startCount(for: BmuxAppRuntimeCapability.sidebarGitPullRequestObservation) == 1)
        #expect(failedHarness.validateRequiredRuntimeCount == 1)
        #expect(failedHarness.makeHostServicesCount == 0)

        failedServices.stop()

        #expect(failedServices.sidebarGitPullRequestObservationLifecycleState == .stopped)
    }

    @Test func duplicateEventsWorkspaceRemovalShutdownAndRestartDoNotCreateSecondOwners() throws {
        let homeDirectory = try Self.temporaryDirectory(named: "lifecycle")
        let harness = SidebarGitPullRequestRuntimeTestHarness()
        let services = Self.runtimeServices(homeDirectory: homeDirectory, harness: harness)
        let manager = TabManager(
            sidebarGitPullRequestObservation: services.tabManagerSidebarGitPullRequestObservationServices()
        )
        let firstWorkspace = try #require(manager.selectedWorkspace)
        let firstPanelId = try #require(firstWorkspace.focusedPanelId)

        services.start(tabManager: manager)
        services.attachSidebarGitPullRequestObservation(tabManager: manager)

        let firstService = try #require(harness.services.first)
        #expect(harness.makeHostServicesCount == 1)
        #expect(firstService.initialGitRefreshes == [RecordedInitialGitRefresh(workspaceId: firstWorkspace.id, panelId: firstPanelId, reason: "runtimeStart")])

        let secondWorkspace = manager.addWorkspace(title: "Second", select: false)
        let secondPanelId = try #require(secondWorkspace.focusedPanelId)
        services.attachSidebarGitPullRequestObservation(tabManager: manager)
        manager.closeWorkspace(secondWorkspace, recordHistory: false)

        #expect(harness.makeHostServicesCount == 1)
        #expect(firstService.initialGitRefreshes.contains(RecordedInitialGitRefresh(workspaceId: secondWorkspace.id, panelId: secondPanelId, reason: "initial")))
        #expect(firstService.clearedGitWorkspaceIds.contains(secondWorkspace.id))
        #expect(firstService.clearedPullRequestWorkspaceIds.contains(secondWorkspace.id))

        services.stop()
        services.stop()

        #expect(services.sidebarGitPullRequestObservationLifecycleState == .stopped)
        #expect(!services.sidebarGitPullRequestObservationRuntimeService.hasActiveLifecycleWork)
        #expect(firstService.stopSidebarGitObservationCount == 1)
        #expect(firstService.stopPullRequestObservationCount == 1)

        services.start(tabManager: manager)
        let secondService = try #require(harness.services.dropFirst().first)
        services.stop()

        #expect(services.startCount(for: BmuxAppRuntimeCapability.sidebarGitPullRequestObservation) == 2)
        #expect(harness.makeHostServicesCount == 2)
        #expect(secondService.stopSidebarGitObservationCount == 1)
        #expect(secondService.stopPullRequestObservationCount == 1)
    }

    @Test func newerPromptMentionRefreshCannotBeOverwrittenByOlderResult() async throws {
        let homeDirectory = try Self.temporaryDirectory(named: "prompt-stale-result")
        let promptRunner = PromptMentionCommandRunner()
        let harness = SidebarGitPullRequestRuntimeTestHarness(promptMentionCommandRunner: promptRunner)
        let services = Self.runtimeServices(homeDirectory: homeDirectory, harness: harness)
        let manager = TabManager(
            sidebarGitPullRequestObservation: services.tabManagerSidebarGitPullRequestObservationServices()
        )
        let workspace = try #require(manager.selectedWorkspace)
        let panelId = try #require(workspace.focusedPanelId)
        let message = "Review https://github.com/manaflow-ai/bmux/pull/5314"
        let record = workspace.recordSubmittedPullRequestMention(message, surfaceId: panelId)

        services.start(tabManager: manager)
        manager.refreshSubmittedPullRequestMentionIfNeeded(workspaceId: workspace.id, record: record)
        await promptRunner.waitForRequest(url: "https://github.com/manaflow-ai/bmux/pull/5314", invocation: 1)
        manager.refreshSubmittedPullRequestMentionIfNeeded(workspaceId: workspace.id, record: record)
        await promptRunner.waitForRequest(url: "https://github.com/manaflow-ai/bmux/pull/5314", invocation: 2)

        await promptRunner.release(
            url: "https://github.com/manaflow-ai/bmux/pull/5314",
            invocation: 2,
            result: .successJSON(Self.promptMentionPayload(title: "Newer title", owner: "new-owner"))
        )
        await promptRunner.release(
            url: "https://github.com/manaflow-ai/bmux/pull/5314",
            invocation: 1,
            result: .successJSON(Self.promptMentionPayload(title: "Older title", owner: "old-owner"))
        )
        await services.sidebarGitPullRequestObservationRuntimeService.waitForSubmittedPullRequestMentionRefreshesForTesting()

        let pullRequest = try #require(workspace.panelPullRequests[panelId])
        #expect(pullRequest.number == 5314)
        #expect(pullRequest.title == "Newer title")
        #expect(pullRequest.ownerLogin == "new-owner")
        #expect(pullRequest.ownerURL?.absoluteString == "https://github.com/new-owner")
    }

    private static func temporaryDirectory(named name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-sidebar-git-pr-runtime-tests-\(UUID().uuidString)")
            .appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func databaseURL(in homeDirectory: URL) -> URL {
        WorkProvenanceStorageLocation(homeDirectory: homeDirectory).databaseURL
    }

    private static func runtimeServices(
        homeDirectory: URL,
        configuration: BmuxAppRuntimeConfiguration? = nil,
        harness: SidebarGitPullRequestRuntimeTestHarness
    ) -> BmuxAppRuntimeServices {
        let configuration = configuration ?? .test(
            enabledCapabilities: [BmuxAppRuntimeCapability.sidebarGitPullRequestObservation],
            workProvenanceHomeDirectory: homeDirectory
        )
        let composition = BmuxAppRuntimeComposition(
            configFileURL: homeDirectory.appendingPathComponent("bmux.json"),
            secretBaseDirectory: homeDirectory.appendingPathComponent("secrets"),
            bundleIdentifier: "com.example.bmux-sidebar-git-pr-runtime-tests",
            runtimeConfiguration: configuration,
            sidebarGitPullRequestObservationRuntimeDependencies: harness.dependencies()
        )
        let runtime = composition.makeWorkProvenanceRuntime(catalog: SettingCatalog())
        return composition.makeRuntimeServices(workProvenanceRuntime: runtime)
    }

    private static func firstCustomPullRequestFields(_ values: [SwiftValue]) -> [String: SwiftValue]? {
        guard case let .object(fields)? = values.first else { return nil }
        return fields
    }

    private static func promptMentionPayload(title: String, owner: String) -> String {
        """
        {"number":5314,"state":"OPEN","title":"\(title)","url":"https://github.com/manaflow-ai/bmux/pull/5314","author":{"login":"\(owner)","url":"https://github.com/\(owner)"}}
        """
    }
}

private struct RecordedInitialGitRefresh: Equatable {
    let workspaceId: UUID
    let panelId: UUID
    let reason: String
}

@MainActor
private final class SidebarGitPullRequestRuntimeTestHarness {
    var validateRequiredRuntimeResult: SidebarGitPullRequestObservationRuntimeOperationResult
    var validateRequiredRuntimeCount = 0
    var makeHostServicesCount = 0
    var services: [RecordingSidebarGitPullRequestObservationService] = []
    private let publishObservedFactsOnInitialRefresh: Bool
    private let shouldFailWorkspace: (UUID) -> Bool
    private let promptMentionCommandRunner: any CommandRunning

    init(
        validateRequiredRuntimeResult: SidebarGitPullRequestObservationRuntimeOperationResult = .ready,
        publishObservedFactsOnInitialRefresh: Bool = false,
        shouldFailWorkspace: @escaping (UUID) -> Bool = { _ in false },
        promptMentionCommandRunner: any CommandRunning = NoopCommandRunner()
    ) {
        self.validateRequiredRuntimeResult = validateRequiredRuntimeResult
        self.publishObservedFactsOnInitialRefresh = publishObservedFactsOnInitialRefresh
        self.shouldFailWorkspace = shouldFailWorkspace
        self.promptMentionCommandRunner = promptMentionCommandRunner
    }

    func dependencies() -> SidebarGitPullRequestObservationRuntimeServiceDependencies {
        SidebarGitPullRequestObservationRuntimeServiceDependencies(
            validateRequiredRuntime: {
                self.validateRequiredRuntimeCount += 1
                return self.validateRequiredRuntimeResult
            },
            makeHostServices: {
                self.makeHostServicesCount += 1
                let service = RecordingSidebarGitPullRequestObservationService(
                    publishObservedFactsOnInitialRefresh: self.publishObservedFactsOnInitialRefresh,
                    shouldFailWorkspace: self.shouldFailWorkspace
                )
                self.services.append(service)
                return SidebarGitPullRequestObservationHostServices(
                    sidebarGitMetadataService: service,
                    pullRequestProbing: service
                )
            },
            promptMentionProbeService: PullRequestProbeService(
                commandRunner: promptMentionCommandRunner,
                debugLog: { _ in }
            )
        )
    }
}

@MainActor
private final class RecordingSidebarGitPullRequestObservationService: SidebarGitMetadataServing, PullRequestProbing {
    private weak var host: (any SidebarGitHosting)?
    private let publishObservedFactsOnInitialRefresh: Bool
    private let shouldFailWorkspace: (UUID) -> Bool
    var attachCount = 0
    var initialGitRefreshes: [RecordedInitialGitRefresh] = []
    var pullRequestRefreshReasons: [String] = []
    var scheduledPullRequestRefreshes: [RecordedInitialGitRefresh] = []
    var clearedGitWorkspaceIds: [UUID] = []
    var clearedPullRequestWorkspaceIds: [UUID] = []
    var stopSidebarGitObservationCount = 0
    var stopPullRequestObservationCount = 0
    private var trackedPullRequestPanelIdsByWorkspaceId: [UUID: Set<UUID>] = [:]

    init(
        publishObservedFactsOnInitialRefresh: Bool,
        shouldFailWorkspace: @escaping (UUID) -> Bool
    ) {
        self.publishObservedFactsOnInitialRefresh = publishObservedFactsOnInitialRefresh
        self.shouldFailWorkspace = shouldFailWorkspace
    }

    func attach(host: any SidebarGitHosting) {
        attachCount += 1
        self.host = host
    }

    func scheduleInitialWorkspaceGitMetadataRefreshIfPossible(workspaceId: UUID, panelId: UUID, reason: String) {
        initialGitRefreshes.append(RecordedInitialGitRefresh(workspaceId: workspaceId, panelId: panelId, reason: reason))
        guard publishObservedFactsOnInitialRefresh, !shouldFailWorkspace(workspaceId), let host else { return }
        host.updatePanelGitBranch(
            workspaceId: workspaceId,
            panelId: panelId,
            branch: "feature/pr-5314-runtime",
            isDirty: true
        )
        host.updatePanelPullRequest(
            workspaceId: workspaceId,
            panelId: panelId,
            badge: SidebarPullRequestBadge(
                number: 5314,
                title: "Runtime migration",
                label: "PR",
                url: URL(string: "https://github.com/manaflow-ai/bmux/pull/5314")!,
                ownerLogin: "octocat",
                ownerURL: URL(string: "https://github.com/octocat"),
                status: .open,
                branch: "feature/pr-5314-runtime",
                isStale: false
            )
        )
        trackedPullRequestPanelIdsByWorkspaceId[workspaceId, default: []].insert(panelId)
    }

    func updateSurfaceDirectory(workspaceId: UUID, panelId: UUID, directory: String, displayLabel: String?) {
        _ = host?.updatePanelDirectory(workspaceId: workspaceId, panelId: panelId, directory: directory, displayLabel: displayLabel)
    }

    func updateRemoteSurfaceDirectory(workspaceId: UUID, panelId: UUID, directory: String, displayLabel: String?) {
        _ = host?.updateRemotePanelDirectory(workspaceId: workspaceId, panelId: panelId, directory: directory, displayLabel: displayLabel)
    }

    func updateSurfaceGitBranch(workspaceId: UUID, panelId: UUID, branch: String, isDirty: Bool?) {
        host?.updatePanelGitBranch(workspaceId: workspaceId, panelId: panelId, branch: branch, isDirty: isDirty ?? false)
    }

    func clearSurfaceGitBranch(workspaceId: UUID, panelId: UUID) {
        host?.clearPanelGitBranch(workspaceId: workspaceId, panelId: panelId)
    }

    func refreshTrackedWorkspaceGitMetadata(reason: String) {}

    func sidebarGitMetadataWatchSettingsDidChange() {}

    func stopSidebarGitMetadataObservation() {
        stopSidebarGitObservationCount += 1
        host = nil
    }

    func clearWorkspaceGitProbes(workspaceId: UUID) {
        clearedGitWorkspaceIds.append(workspaceId)
    }

    func resetAllWorkspaceGitProbeTracking() {
        clearedGitWorkspaceIds.removeAll()
        trackedPullRequestPanelIdsByWorkspaceId.removeAll()
    }

    func trackedWorkspaceGitMetadataPollCandidatePanelIds(workspaceId: UUID) -> Set<UUID> { [] }

    func activeWorkspaceGitProbePanelIds(workspaceId: UUID) -> Set<UUID> { [] }

    func scheduleWorkspacePullRequestRefresh(workspaceId: UUID, panelId: UUID, reason: String) {
        scheduledPullRequestRefreshes.append(RecordedInitialGitRefresh(workspaceId: workspaceId, panelId: panelId, reason: reason))
        trackedPullRequestPanelIdsByWorkspaceId[workspaceId, default: []].insert(panelId)
    }

    func refreshTrackedWorkspacePullRequestsIfNeeded(reason: String) {
        pullRequestRefreshReasons.append(reason)
    }

    func sidebarPullRequestPollingSettingsDidChange() {}

    func stopWorkspacePullRequestObservation() {
        stopPullRequestObservationCount += 1
        host = nil
    }

    func handleWorkspacePullRequestCommandHint(workspaceId: UUID, panelId: UUID, action: String, target: String?) {}

    func clearWorkspacePullRequestTracking(workspaceId: UUID, panelId: UUID) {
        trackedPullRequestPanelIdsByWorkspaceId[workspaceId]?.remove(panelId)
    }

    func clearWorkspacePullRequestMetadata(workspaceId: UUID, panelId: UUID) {
        host?.clearPanelPullRequest(workspaceId: workspaceId, panelId: panelId)
        trackedPullRequestPanelIdsByWorkspaceId[workspaceId]?.remove(panelId)
    }

    func clearWorkspacePullRequestTracking(workspaceId: UUID) {
        clearedPullRequestWorkspaceIds.append(workspaceId)
        trackedPullRequestPanelIdsByWorkspaceId.removeValue(forKey: workspaceId)
    }

    func resetWorkspacePullRequestRefreshState() {
        trackedPullRequestPanelIdsByWorkspaceId.removeAll()
    }

    func workspacePullRequestTrackedPanelIds(workspaceId: UUID) -> Set<UUID> {
        trackedPullRequestPanelIdsByWorkspaceId[workspaceId] ?? []
    }
}

private final class SidebarGitPullRequestRuntimeFailureSet: @unchecked Sendable {
    private let lock = NSLock()
    private var workspaceIds: Set<UUID> = []

    func insert(_ workspaceId: UUID) {
        lock.lock()
        workspaceIds.insert(workspaceId)
        lock.unlock()
    }

    func contains(_ workspaceId: UUID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return workspaceIds.contains(workspaceId)
    }
}

private struct NoopCommandRunner: CommandRunning {
    func run(directory: String, executable: String, arguments: [String], timeout: TimeInterval?) async -> CommandResult {
        CommandResult(stdout: nil, stderr: "disabled", exitStatus: 127, timedOut: false, executionError: nil)
    }
}

private final class PromptMentionCommandRunner: CommandRunning, @unchecked Sendable {
    private let state = PromptMentionCommandRunnerState()

    func run(directory: String, executable: String, arguments: [String], timeout: TimeInterval?) async -> CommandResult {
        let url = arguments.dropFirst(2).first ?? ""
        return await state.waitForRelease(url: url)
    }

    func waitForRequest(url: String, invocation: Int) async {
        await state.waitForRequest(url: url, invocation: invocation)
    }

    func release(url: String, invocation: Int, result: CommandResult) async {
        await state.release(url: url, invocation: invocation, result: result)
    }
}

private actor PromptMentionCommandRunnerState {
    private struct RequestKey: Hashable {
        let url: String
        let invocation: Int
    }

    private var invocationCountsByURL: [String: Int] = [:]
    private var seenRequests: Set<RequestKey> = []
    private var requestWaiters: [RequestKey: [CheckedContinuation<Void, Never>]] = [:]
    private var pendingResults: [RequestKey: CheckedContinuation<CommandResult, Never>] = [:]
    private var releasedResults: [RequestKey: CommandResult] = [:]

    func waitForRelease(url: String) async -> CommandResult {
        let invocation = (invocationCountsByURL[url] ?? 0) + 1
        invocationCountsByURL[url] = invocation
        let key = RequestKey(url: url, invocation: invocation)
        seenRequests.insert(key)
        if let waiters = requestWaiters.removeValue(forKey: key) {
            for waiter in waiters {
                waiter.resume()
            }
        }
        if let result = releasedResults.removeValue(forKey: key) {
            return result
        }
        return await withCheckedContinuation { continuation in
            pendingResults[key] = continuation
        }
    }

    func waitForRequest(url: String, invocation: Int) async {
        let key = RequestKey(url: url, invocation: invocation)
        guard !seenRequests.contains(key) else { return }
        await withCheckedContinuation { continuation in
            requestWaiters[key, default: []].append(continuation)
        }
    }

    func release(url: String, invocation: Int, result: CommandResult) {
        let key = RequestKey(url: url, invocation: invocation)
        if let continuation = pendingResults.removeValue(forKey: key) {
            continuation.resume(returning: result)
        } else {
            releasedResults[key] = result
        }
    }
}

private extension CommandResult {
    static func successJSON(_ stdout: String) -> CommandResult {
        CommandResult(stdout: stdout, stderr: "", exitStatus: 0, timedOut: false, executionError: nil)
    }
}
