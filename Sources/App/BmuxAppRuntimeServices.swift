import BmuxAuthRuntime
import Foundation

@MainActor
final class BmuxAppRuntimeServices {
    private let configuration: BmuxAppRuntimeConfiguration
    private var startedCapabilities: Set<BmuxAppRuntimeCapability> = []
    private var startCountsByCapability: [BmuxAppRuntimeCapability: Int] = [:]
    let workProvenanceRuntime: WorkProvenanceRuntime
    let mobileHostRuntimeService: MobileHostRuntimeService

    init(
        configuration: BmuxAppRuntimeConfiguration,
        workProvenanceRuntime: WorkProvenanceRuntime,
        mobileHostRuntimeService: MobileHostRuntimeService
    ) {
        self.configuration = configuration
        self.workProvenanceRuntime = workProvenanceRuntime
        self.mobileHostRuntimeService = mobileHostRuntimeService
    }

    func start(tabManager: TabManager) {
        guard configuration.enables(.workProvenanceObservation) else { return }
        guard !startedCapabilities.contains(.workProvenanceObservation) else { return }
        startedCapabilities.insert(.workProvenanceObservation)
        startCountsByCapability[.workProvenanceObservation, default: 0] += 1
        workProvenanceRuntime.start(tabManager: tabManager)
    }

    func stop() {
        mobileHostRuntimeService.stop()
        workProvenanceRuntime.stop()
        startedCapabilities.removeAll()
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

    var mobileHostLifecycleState: MobileHostRuntimeLifecycleState {
        mobileHostRuntimeService.lifecycleState
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
