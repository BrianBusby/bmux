import AppKit
import BmuxAuthRuntime
import Foundation

@MainActor
final class BmuxAppRuntimeServices {
    private let configuration: BmuxAppRuntimeConfiguration
    private var startedCapabilities: Set<BmuxAppRuntimeCapability> = []
    private var startCountsByCapability: [BmuxAppRuntimeCapability: Int] = [:]
    let workProvenanceRuntime: WorkProvenanceRuntime
    let mobileHostRuntimeService: MobileHostRuntimeService
    let browserDevToolsRuntimeService: BrowserDevToolsRuntimeService
    let sidebarGitPullRequestObservationRuntimeService: SidebarGitPullRequestObservationRuntimeService

    init(
        configuration: BmuxAppRuntimeConfiguration,
        workProvenanceRuntime: WorkProvenanceRuntime,
        mobileHostRuntimeService: MobileHostRuntimeService,
        browserDevToolsRuntimeService: BrowserDevToolsRuntimeService,
        sidebarGitPullRequestObservationRuntimeService: SidebarGitPullRequestObservationRuntimeService
    ) {
        self.configuration = configuration
        self.workProvenanceRuntime = workProvenanceRuntime
        self.mobileHostRuntimeService = mobileHostRuntimeService
        self.browserDevToolsRuntimeService = browserDevToolsRuntimeService
        self.sidebarGitPullRequestObservationRuntimeService = sidebarGitPullRequestObservationRuntimeService
    }

    func start(tabManager: TabManager) {
        startWorkProvenanceObservation(tabManager: tabManager)
        attachSidebarGitPullRequestObservation(tabManager: tabManager)
    }

    private func startWorkProvenanceObservation(tabManager: TabManager) {
        guard configuration.enables(.workProvenanceObservation) else { return }
        guard !startedCapabilities.contains(.workProvenanceObservation) else { return }
        startedCapabilities.insert(.workProvenanceObservation)
        startCountsByCapability[.workProvenanceObservation, default: 0] += 1
        workProvenanceRuntime.start(tabManager: tabManager)
    }

    func stop() {
        browserDevToolsRuntimeService.stop()
        mobileHostRuntimeService.stop()
        sidebarGitPullRequestObservationRuntimeService.stop()
        workProvenanceRuntime.stop()
        startedCapabilities.removeAll()
    }

    func tabManagerSidebarGitPullRequestObservationServices() -> TabManagerSidebarGitPullRequestObservationServices {
        guard configuration.enables(.sidebarGitPullRequestObservation) else {
            return .compatibilityReporter()
        }
        return sidebarGitPullRequestObservationRuntimeService.tabManagerObservationServices()
    }

    func attachSidebarGitPullRequestObservation(tabManager: TabManager) {
        guard configuration.enables(.sidebarGitPullRequestObservation) else { return }
        let shouldCountStart = sidebarGitPullRequestObservationRuntimeService.start(host: tabManager)
        guard shouldCountStart else { return }
        startedCapabilities.insert(.sidebarGitPullRequestObservation)
        startCountsByCapability[.sidebarGitPullRequestObservation, default: 0] += 1
    }

    func removeSidebarGitPullRequestObservationIfUnused(
        tabManager: TabManager,
        isStillUsed: Bool
    ) {
        guard configuration.enables(.sidebarGitPullRequestObservation) else { return }
        sidebarGitPullRequestObservationRuntimeService.detach(host: tabManager, isStillUsed: isStillUsed)
    }

    func startMobileHostAndPresence(
        auth: AuthCoordinator?,
        tabManager: TabManager?,
        notificationStore: TerminalNotificationStore?
    ) {
        guard configuration.enables(.mobileHostAndPresence) else { return }
        let wasStarted = startedCapabilities.contains(.mobileHostAndPresence)
        mobileHostRuntimeService.start(
            auth: auth,
            tabManager: tabManager,
            notificationStore: notificationStore
        )
        guard !wasStarted else { return }
        startedCapabilities.insert(.mobileHostAndPresence)
        startCountsByCapability[.mobileHostAndPresence, default: 0] += 1
    }

    func syncMobileHostAndPresenceToSettings() {
        guard configuration.enables(.mobileHostAndPresence) else { return }
        mobileHostRuntimeService.syncToSettings()
    }

    func attachMobileHostWorkspaceListObserver(
        tabManager: TabManager,
        notificationStore: TerminalNotificationStore?
    ) {
        guard configuration.enables(.mobileHostAndPresence) else { return }
        mobileHostRuntimeService.attachWorkspaceListObserver(
            tabManager: tabManager,
            notificationStore: notificationStore
        )
    }

    func removeMobileHostWorkspaceListObserverIfUnused(
        tabManager: TabManager,
        isStillUsed: Bool
    ) {
        guard configuration.enables(.mobileHostAndPresence) else { return }
        mobileHostRuntimeService.removeWorkspaceListObserverIfUnused(
            tabManager: tabManager,
            isStillUsed: isStillUsed
        )
    }

    func stopMobileHostAndPresenceForAppTermination() {
        guard configuration.enables(.mobileHostAndPresence) else { return }
        mobileHostRuntimeService.stopForAppTermination()
        startedCapabilities.remove(.mobileHostAndPresence)
    }

    func startBrowserAndDevTools(
        handlers: BrowserDevToolsRuntimeEventHandlers = .noop
    ) {
        guard configuration.enables(.browserAndDevTools) else { return }
        let wasStarted = startedCapabilities.contains(.browserAndDevTools)
        browserDevToolsRuntimeService.start(handlers: handlers)
        guard !wasStarted else { return }
        startedCapabilities.insert(.browserAndDevTools)
        startCountsByCapability[.browserAndDevTools, default: 0] += 1
    }

    func stopBrowserAndDevToolsForAppTermination() {
        guard configuration.enables(.browserAndDevTools) else { return }
        browserDevToolsRuntimeService.stopForAppTermination()
        startedCapabilities.remove(.browserAndDevTools)
    }

    @discardableResult
    func closeBrowserWebInspectorsForAppTeardown() -> Int {
        guard configuration.enables(.browserAndDevTools) else { return 0 }
        return browserDevToolsRuntimeService.closeAllWebInspectorsForAppTeardown()
    }

    @discardableResult
    func closeBrowserWebInspectors(in window: NSWindow) -> Int {
        guard configuration.enables(.browserAndDevTools) else { return 0 }
        return browserDevToolsRuntimeService.closeWebInspectors(in: window)
    }

    var mobileHostLifecycleState: MobileHostRuntimeLifecycleState {
        mobileHostRuntimeService.lifecycleState
    }

    var browserDevToolsLifecycleState: BrowserDevToolsRuntimeLifecycleState {
        browserDevToolsRuntimeService.lifecycleState
    }

    var sidebarGitPullRequestObservationLifecycleState: SidebarGitPullRequestObservationRuntimeLifecycleState {
        sidebarGitPullRequestObservationRuntimeService.lifecycleState
    }

    var focusedBrowserAddressBarPanelId: UUID? {
        browserDevToolsRuntimeService.focusedAddressBarPanelId
    }

    func setFocusedBrowserAddressBarPanelId(_ panelId: UUID?) {
        browserDevToolsRuntimeService.setFocusedAddressBarPanelId(panelId)
    }

    @discardableResult
    func clearFocusedBrowserAddressBarPanelId(_ panelId: UUID) -> Bool {
        browserDevToolsRuntimeService.clearFocusedAddressBarPanelId(panelId)
    }

    func startAgentChatExecutionTelemetryProjection(
        agentChatURL: URL,
        sidecarStatusHandler: @escaping (ExecutionTelemetryProjectionSidecarStatus) -> Void = { _ in }
    ) {
        guard configuration.enables(.agentChatExecutionTelemetryProjection) else { return }
        startCountsByCapability[.agentChatExecutionTelemetryProjection, default: 0] += 1
        workProvenanceRuntime.startExecutionTelemetryProjection(
            agentChatURL: agentChatURL,
            sidecarStatusHandler: sidecarStatusHandler
        )
    }

    func startCount(for capability: BmuxAppRuntimeCapability) -> Int {
        startCountsByCapability[capability, default: 0]
    }
}
