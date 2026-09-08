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

    @Test func compatibilityConstructedTabManagerPromotesToRuntimeObservationBeforeAttach() throws {
        let homeDirectory = try Self.temporaryDirectory(named: "late-runtime-install")
        let harness = SidebarGitPullRequestRuntimeTestHarness()
        let services = Self.runtimeServices(homeDirectory: homeDirectory, harness: harness)
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        let panelId = try #require(workspace.focusedPanelId)

        manager.updateSurfaceGitBranch(
            tabId: workspace.id,
            surfaceId: panelId,
            branch: "feature/compatibility-only",
            isDirty: false
        )
        manager.updateSurfaceShellActivity(tabId: workspace.id, surfaceId: panelId, state: .promptIdle)
        #expect(harness.makeHostServicesCount == 0)

        let shouldAttachRuntime = manager.installSidebarGitPullRequestObservationServicesIfCompatibility(
            services.tabManagerSidebarGitPullRequestObservationServices()
        )
        #expect(shouldAttachRuntime)
        services.attachSidebarGitPullRequestObservation(tabManager: manager)
        manager.updateSurfaceGitBranch(
            tabId: workspace.id,
            surfaceId: panelId,
            branch: "feature/runtime-owned",
            isDirty: false
        )
        manager.updateSurfaceShellActivity(tabId: workspace.id, surfaceId: panelId, state: .promptIdle)

        let service = try #require(harness.services.first)
        #expect(harness.makeHostServicesCount == 1)
        #expect(service.initialGitRefreshes == [RecordedInitialGitRefresh(workspaceId: workspace.id, panelId: panelId, reason: "runtimeStart")])
        #expect(service.scheduledPullRequestRefreshes.contains(RecordedInitialGitRefresh(workspaceId: workspace.id, panelId: panelId, reason: "shellPrompt")))
    }

    @Test func explicitHostAttachedObservationServicesAreNotPromotedOrDoubleAttached() throws {
        let homeDirectory = try Self.temporaryDirectory(named: "explicit-services")
        let runtimeHarness = SidebarGitPullRequestRuntimeTestHarness()
        let services = Self.runtimeServices(homeDirectory: homeDirectory, harness: runtimeHarness)
        let explicitService = RecordingSidebarGitPullRequestObservationService(
            publishObservedFactsOnInitialRefresh: false,
            shouldFailWorkspace: { _ in false }
        )
        let manager = TabManager(
            sidebarGitPullRequestObservation: TabManagerSidebarGitPullRequestObservationServices(
                sidebarGitMetadataService: explicitService,
                pullRequestProbing: explicitService,
                attachesHostFromTabManager: true,
                isCompatibilityReporter: false,
                refreshSubmittedPullRequestMention: { _, _, _ in },
                cancelSubmittedPullRequestMentionRefreshes: {}
            )
        )
        let workspace = try #require(manager.selectedWorkspace)
        let panelId = try #require(workspace.focusedPanelId)
        let explicitAttachCountBeforePromotion = explicitService.attachCount

        let shouldAttachRuntime = manager.installSidebarGitPullRequestObservationServicesIfCompatibility(
            services.tabManagerSidebarGitPullRequestObservationServices()
        )
        if shouldAttachRuntime {
            services.attachSidebarGitPullRequestObservation(tabManager: manager)
        }
        manager.updateSurfaceGitBranch(
            tabId: workspace.id,
            surfaceId: panelId,
            branch: "feature/explicit-owner",
            isDirty: false
        )
        manager.updateSurfaceShellActivity(tabId: workspace.id, surfaceId: panelId, state: .promptIdle)

        #expect(!shouldAttachRuntime)
        #expect(runtimeHarness.makeHostServicesCount == 0)
        #expect(explicitService.attachCount == explicitAttachCountBeforePromotion)
        #expect(explicitService.scheduledPullRequestRefreshes.contains(RecordedInitialGitRefresh(workspaceId: workspace.id, panelId: panelId, reason: "shellPrompt")))
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
