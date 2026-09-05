import Foundation
import Testing
@testable import bmux

@MainActor
@Suite(.serialized)
struct AppRuntimeCompositionTests {
    @Test
    func currentXCTestProcessDisablesWorkProvenanceByDefault() throws {
        let homeDirectory = try temporaryDirectory(named: "default-disabled")
        let configuration = BmuxAppRuntimeConfiguration.currentProcess(
            environment: [
                "XCTestConfigurationFilePath": "/tmp/bmux.xctestconfiguration",
                "HOME": homeDirectory.path
            ],
            fileManager: .default
        )
        let composition = BmuxAppRuntimeComposition(
            configFileURL: homeDirectory.appendingPathComponent("bmux.json"),
            secretBaseDirectory: homeDirectory.appendingPathComponent("secrets"),
            bundleIdentifier: "com.example.bmux-tests",
            runtimeConfiguration: configuration
        )

        let runtime = composition.makeWorkProvenanceRuntime(catalog: .empty)
        let services = composition.makeRuntimeServices(workProvenanceRuntime: runtime)
        let tabManager = TabManager()

        #expect(configuration.processKind == .xctestHost)
        #expect(!configuration.enables(.workProvenanceObservation))
        #expect(runtime.effectiveDatabaseURL == nil)
        #expect(runtime.lifecycleState == .stopped)
        #expect(!FileManager.default.fileExists(atPath: homeDirectory.appendingPathComponent(".bmux/provenance-engine.sqlite").path))

        services.start(tabManager: tabManager)

        #expect(runtime.lifecycleState == .stopped)
        #expect(!FileManager.default.fileExists(atPath: homeDirectory.appendingPathComponent(".bmux/provenance-engine.sqlite").path))
    }

    @Test
    func explicitTestCompositionCanOptIntoIsolatedWorkProvenance() throws {
        let homeDirectory = try temporaryDirectory(named: "opt-in")
        let configuration = BmuxAppRuntimeConfiguration.test(
            enabledCapabilities: [.workProvenanceObservation],
            workProvenanceHomeDirectory: homeDirectory
        )
        let composition = BmuxAppRuntimeComposition(
            configFileURL: homeDirectory.appendingPathComponent("bmux.json"),
            secretBaseDirectory: homeDirectory.appendingPathComponent("secrets"),
            bundleIdentifier: "com.example.bmux-tests",
            runtimeConfiguration: configuration
        )

        let runtime = composition.makeWorkProvenanceRuntime(catalog: .empty)
        let services = composition.makeRuntimeServices(workProvenanceRuntime: runtime)
        let tabManager = TabManager()

        #expect(configuration.processKind == .xctestHost)
        #expect(configuration.enables(.workProvenanceObservation))
        #expect(runtime.effectiveDatabaseURL?.path.hasPrefix(homeDirectory.path) == true)

        services.start(tabManager: tabManager)

        #expect(runtime.lifecycleState == .ready)
        #expect(FileManager.default.fileExists(atPath: homeDirectory.appendingPathComponent(".bmux/provenance-engine.sqlite").path))

        services.stop()

        #expect(runtime.lifecycleState == .stopped)
    }

    @Test
    func xctestCompatibilityEnvironmentOptInUsesConfiguredHomeDirectory() throws {
        let homeDirectory = try temporaryDirectory(named: "environment-opt-in")
        let configuration = BmuxAppRuntimeConfiguration.currentProcess(
            environment: [
                "XCTestConfigurationFilePath": "/tmp/bmux.xctestconfiguration",
                "BMUX_ENABLE_PROVENANCE_RUNTIME_IN_XCTEST": "1",
                "BMUX_PROVENANCE_HOME": homeDirectory.path,
                "HOME": homeDirectory.path
            ],
            fileManager: .default
        )

        #expect(configuration.processKind == .xctestHost)
        #expect(configuration.enables(.workProvenanceObservation))
        #expect(configuration.workProvenanceHomeDirectory.path == homeDirectory.path)
    }

    @Test
    func failedWorkProvenanceConstructionProducesDeterministicFailureState() throws {
        let homeDirectory = try temporaryDirectory(named: "failure-state")
        let fileURL = homeDirectory.appendingPathComponent("not-a-directory")
        try Data().write(to: fileURL)
        let configuration = BmuxAppRuntimeConfiguration.test(
            enabledCapabilities: [.workProvenanceObservation],
            workProvenanceHomeDirectory: fileURL
        )
        let composition = BmuxAppRuntimeComposition(
            configFileURL: homeDirectory.appendingPathComponent("bmux.json"),
            secretBaseDirectory: homeDirectory.appendingPathComponent("secrets"),
            bundleIdentifier: "com.example.bmux-tests",
            runtimeConfiguration: configuration
        )

        let runtime = composition.makeWorkProvenanceRuntime(catalog: .empty)
        let services = composition.makeRuntimeServices(workProvenanceRuntime: runtime)

        services.start(tabManager: TabManager())

        if case .failed(let reason) = runtime.lifecycleState {
            #expect(!reason.isEmpty)
        } else {
            Issue.record("Expected failed state, got \(runtime.lifecycleState)")
        }
    }

    @Test
    func startStopAreIdempotentAndDoNotLeakStateAcrossCompositions() throws {
        let enabledHomeDirectory = try temporaryDirectory(named: "idempotent-enabled")
        let enabledComposition = BmuxAppRuntimeComposition(
            configFileURL: enabledHomeDirectory.appendingPathComponent("bmux.json"),
            secretBaseDirectory: enabledHomeDirectory.appendingPathComponent("secrets"),
            bundleIdentifier: "com.example.bmux-tests",
            runtimeConfiguration: .test(
                enabledCapabilities: [.workProvenanceObservation],
                workProvenanceHomeDirectory: enabledHomeDirectory
            )
        )
        let enabledRuntime = enabledComposition.makeWorkProvenanceRuntime(catalog: .empty)
        let enabledServices = enabledComposition.makeRuntimeServices(workProvenanceRuntime: enabledRuntime)

        enabledServices.start(tabManager: TabManager())
        enabledServices.start(tabManager: TabManager())

        #expect(enabledRuntime.lifecycleState == .ready)

        enabledServices.stop()
        enabledServices.stop()

        #expect(enabledRuntime.lifecycleState == .stopped)

        let disabledHomeDirectory = try temporaryDirectory(named: "idempotent-disabled")
        let disabledComposition = BmuxAppRuntimeComposition(
            configFileURL: disabledHomeDirectory.appendingPathComponent("bmux.json"),
            secretBaseDirectory: disabledHomeDirectory.appendingPathComponent("secrets"),
            bundleIdentifier: "com.example.bmux-tests",
            runtimeConfiguration: .test(workProvenanceHomeDirectory: disabledHomeDirectory)
        )
        let disabledRuntime = disabledComposition.makeWorkProvenanceRuntime(catalog: .empty)

        #expect(disabledRuntime.lifecycleState == .stopped)
        #expect(disabledRuntime.effectiveDatabaseURL == nil)
        #expect(!FileManager.default.fileExists(atPath: disabledHomeDirectory.appendingPathComponent(".bmux/provenance-engine.sqlite").path))
    }

    private static func temporaryDirectory(named name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-runtime-composition-tests-\(UUID().uuidString)")
            .appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
