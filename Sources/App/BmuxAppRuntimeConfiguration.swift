import Foundation

struct BmuxAppRuntimeConfiguration: Sendable {
    let processKind: BmuxAppRuntimeProcessKind
    let enabledCapabilities: Set<BmuxAppRuntimeCapability>
    let workProvenanceHomeDirectory: URL

    @MainActor
    static func currentProcess(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> BmuxAppRuntimeConfiguration {
        let processKind: BmuxAppRuntimeProcessKind = AppDelegate.detectRunningUnderXCTest(environment)
            ? .xctestHost
            : .productionApp
        let provenanceEnabled = processKind == .productionApp
            || environment["BMUX_ENABLE_PROVENANCE_RUNTIME_IN_XCTEST"] == "1"
        var enabledCapabilities: Set<BmuxAppRuntimeCapability> = []
        if provenanceEnabled {
            enabledCapabilities.insert(.workProvenanceObservation)
            enabledCapabilities.insert(.agentChatExecutionTelemetryProjection)
        }
        if processKind == .productionApp {
            enabledCapabilities.insert(.mobileHostAndPresence)
        }
        return BmuxAppRuntimeConfiguration(
            processKind: processKind,
            enabledCapabilities: enabledCapabilities,
            workProvenanceHomeDirectory: WorkProvenanceStorageLocation.defaultHomeDirectory(
                environment: environment,
                fileManager: fileManager
            )
        )
    }

    static func test(
        enabledCapabilities: Set<BmuxAppRuntimeCapability> = [],
        workProvenanceHomeDirectory: URL
    ) -> BmuxAppRuntimeConfiguration {
        BmuxAppRuntimeConfiguration(
            processKind: .xctestHost,
            enabledCapabilities: enabledCapabilities,
            workProvenanceHomeDirectory: workProvenanceHomeDirectory
        )
    }

    func enables(_ capability: BmuxAppRuntimeCapability) -> Bool {
        enabledCapabilities.contains(capability)
    }
}
