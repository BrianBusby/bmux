import Foundation

@MainActor
final class BmuxAppRuntimeServices {
    private let configuration: BmuxAppRuntimeConfiguration
    private var startedCapabilities: Set<BmuxAppRuntimeCapability> = []
    private var startCountsByCapability: [BmuxAppRuntimeCapability: Int] = [:]
    let workProvenanceRuntime: WorkProvenanceRuntime

    init(
        configuration: BmuxAppRuntimeConfiguration,
        workProvenanceRuntime: WorkProvenanceRuntime
    ) {
        self.configuration = configuration
        self.workProvenanceRuntime = workProvenanceRuntime
    }

    func start(tabManager: TabManager) {
        guard configuration.enables(.workProvenanceObservation) else { return }
        guard !startedCapabilities.contains(.workProvenanceObservation) else { return }
        startedCapabilities.insert(.workProvenanceObservation)
        startCountsByCapability[.workProvenanceObservation, default: 0] += 1
        workProvenanceRuntime.start(tabManager: tabManager)
    }

    func stop() {
        workProvenanceRuntime.stop()
        startedCapabilities.removeAll()
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
