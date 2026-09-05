import BmuxSettings
import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite(.serialized)
struct AppRuntimeCompositionTests {
    @Test
    func currentXCTestProcessDisablesWorkProvenanceByDefault() throws {
        let homeDirectory = try Self.temporaryDirectory(named: "default-disabled")
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

        let runtime = composition.makeWorkProvenanceRuntime(catalog: SettingCatalog())
        let services = composition.makeRuntimeServices(workProvenanceRuntime: runtime)
        let tabManager = TabManager()
        let databaseURL = Self.databaseURL(in: homeDirectory)

        #expect(configuration.processKind == BmuxAppRuntimeProcessKind.xctestHost)
        #expect(!configuration.enables(BmuxAppRuntimeCapability.workProvenanceObservation))
        #expect(runtime.effectiveDatabaseURL == nil)
        #expect(runtime.lifecycleState == WorkProvenanceRuntimeLifecycleState.stopped)
        #expect(services.startCount(for: BmuxAppRuntimeCapability.workProvenanceObservation) == 0)
        #expect(!FileManager.default.fileExists(atPath: databaseURL.path))

        services.start(tabManager: tabManager)

        #expect(runtime.lifecycleState == WorkProvenanceRuntimeLifecycleState.stopped)
        #expect(services.startCount(for: BmuxAppRuntimeCapability.workProvenanceObservation) == 0)
        #expect(!FileManager.default.fileExists(atPath: databaseURL.path))
    }

    @Test
    func productionProcessStartsWorkProvenanceExactlyOnce() throws {
        let homeDirectory = try Self.temporaryDirectory(named: "production")
        let configuration = BmuxAppRuntimeConfiguration.currentProcess(
            environment: [
                "BMUX_PROVENANCE_HOME": homeDirectory.path,
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

        let runtime = composition.makeWorkProvenanceRuntime(catalog: SettingCatalog())
        let services = composition.makeRuntimeServices(workProvenanceRuntime: runtime)
        let databaseURL = Self.databaseURL(in: homeDirectory)

        #expect(configuration.processKind == BmuxAppRuntimeProcessKind.productionApp)
        #expect(configuration.enables(BmuxAppRuntimeCapability.workProvenanceObservation))
        #expect(runtime.effectiveDatabaseURL == databaseURL)

        services.start(tabManager: TabManager())
        services.start(tabManager: TabManager())

        #expect(runtime.lifecycleState == WorkProvenanceRuntimeLifecycleState.ready)
        #expect(services.startCount(for: BmuxAppRuntimeCapability.workProvenanceObservation) == 1)
        #expect(FileManager.default.fileExists(atPath: databaseURL.path))

        services.stop()

        #expect(runtime.lifecycleState == WorkProvenanceRuntimeLifecycleState.stopped)
    }

    @Test
    func explicitTestCompositionCanOptIntoIsolatedWorkProvenance() throws {
        let homeDirectory = try Self.temporaryDirectory(named: "opt-in")
        let configuration = BmuxAppRuntimeConfiguration.test(
            enabledCapabilities: [BmuxAppRuntimeCapability.workProvenanceObservation],
            workProvenanceHomeDirectory: homeDirectory
        )
        let composition = BmuxAppRuntimeComposition(
            configFileURL: homeDirectory.appendingPathComponent("bmux.json"),
            secretBaseDirectory: homeDirectory.appendingPathComponent("secrets"),
            bundleIdentifier: "com.example.bmux-tests",
            runtimeConfiguration: configuration
        )

        let runtime = composition.makeWorkProvenanceRuntime(catalog: SettingCatalog())
        let services = composition.makeRuntimeServices(workProvenanceRuntime: runtime)
        let tabManager = TabManager()
        let databaseURL = Self.databaseURL(in: homeDirectory)

        #expect(configuration.processKind == BmuxAppRuntimeProcessKind.xctestHost)
        #expect(configuration.enables(BmuxAppRuntimeCapability.workProvenanceObservation))
        #expect(runtime.effectiveDatabaseURL == databaseURL)
        #expect(runtime.effectiveDatabaseURL?.path.hasPrefix(homeDirectory.path) == true)

        services.start(tabManager: tabManager)
        services.start(tabManager: tabManager)

        #expect(runtime.lifecycleState == WorkProvenanceRuntimeLifecycleState.ready)
        #expect(runtime.hasActiveLifecycleWork)
        #expect(services.startCount(for: BmuxAppRuntimeCapability.workProvenanceObservation) == 1)
        #expect(FileManager.default.fileExists(atPath: databaseURL.path))

        services.stop()

        #expect(runtime.lifecycleState == WorkProvenanceRuntimeLifecycleState.stopped)
        #expect(!runtime.hasActiveLifecycleWork)
    }

    @Test
    func xctestCompatibilityEnvironmentOptInUsesConfiguredHomeDirectory() throws {
        let homeDirectory = try Self.temporaryDirectory(named: "environment-opt-in")
        let configuration = BmuxAppRuntimeConfiguration.currentProcess(
            environment: [
                "XCTestConfigurationFilePath": "/tmp/bmux.xctestconfiguration",
                "BMUX_ENABLE_PROVENANCE_RUNTIME_IN_XCTEST": "1",
                "BMUX_PROVENANCE_HOME": homeDirectory.path,
                "HOME": homeDirectory.path
            ],
            fileManager: .default
        )

        #expect(configuration.processKind == BmuxAppRuntimeProcessKind.xctestHost)
        #expect(configuration.enables(BmuxAppRuntimeCapability.workProvenanceObservation))
        #expect(configuration.workProvenanceHomeDirectory.path == homeDirectory.path)
    }

    @Test
    func failedWorkProvenanceConstructionProducesDeterministicFailureState() throws {
        let homeDirectory = try Self.temporaryDirectory(named: "failure-state")
        let fileURL = homeDirectory.appendingPathComponent("not-a-directory")
        try Data().write(to: fileURL)
        let configuration = BmuxAppRuntimeConfiguration.test(
            enabledCapabilities: [BmuxAppRuntimeCapability.workProvenanceObservation],
            workProvenanceHomeDirectory: fileURL
        )
        let composition = BmuxAppRuntimeComposition(
            configFileURL: homeDirectory.appendingPathComponent("bmux.json"),
            secretBaseDirectory: homeDirectory.appendingPathComponent("secrets"),
            bundleIdentifier: "com.example.bmux-tests",
            runtimeConfiguration: configuration
        )

        let runtime = composition.makeWorkProvenanceRuntime(catalog: SettingCatalog())
        let services = composition.makeRuntimeServices(workProvenanceRuntime: runtime)

        services.start(tabManager: TabManager())

        if case .failed(let reason) = runtime.lifecycleState {
            #expect(!reason.isEmpty)
        } else {
            Issue.record("Expected failed work provenance lifecycle state")
        }
        #expect(services.startCount(for: BmuxAppRuntimeCapability.workProvenanceObservation) == 1)
    }

    @Test
    func startStopAreIdempotentAndDoNotLeakStateAcrossCompositions() throws {
        let enabledHomeDirectory = try Self.temporaryDirectory(named: "idempotent-enabled")
        let enabledComposition = BmuxAppRuntimeComposition(
            configFileURL: enabledHomeDirectory.appendingPathComponent("bmux.json"),
            secretBaseDirectory: enabledHomeDirectory.appendingPathComponent("secrets"),
            bundleIdentifier: "com.example.bmux-tests",
            runtimeConfiguration: .test(
                enabledCapabilities: [BmuxAppRuntimeCapability.workProvenanceObservation],
                workProvenanceHomeDirectory: enabledHomeDirectory
            )
        )
        let enabledRuntime = enabledComposition.makeWorkProvenanceRuntime(catalog: SettingCatalog())
        let enabledServices = enabledComposition.makeRuntimeServices(workProvenanceRuntime: enabledRuntime)

        enabledServices.start(tabManager: TabManager())
        enabledServices.start(tabManager: TabManager())

        #expect(enabledRuntime.lifecycleState == WorkProvenanceRuntimeLifecycleState.ready)
        #expect(enabledRuntime.hasActiveLifecycleWork)
        #expect(enabledServices.startCount(for: BmuxAppRuntimeCapability.workProvenanceObservation) == 1)

        enabledServices.stop()
        enabledServices.stop()

        #expect(enabledRuntime.lifecycleState == WorkProvenanceRuntimeLifecycleState.stopped)
        #expect(!enabledRuntime.hasActiveLifecycleWork)

        let disabledHomeDirectory = try Self.temporaryDirectory(named: "idempotent-disabled")
        let disabledComposition = BmuxAppRuntimeComposition(
            configFileURL: disabledHomeDirectory.appendingPathComponent("bmux.json"),
            secretBaseDirectory: disabledHomeDirectory.appendingPathComponent("secrets"),
            bundleIdentifier: "com.example.bmux-tests",
            runtimeConfiguration: .test(workProvenanceHomeDirectory: disabledHomeDirectory)
        )
        let disabledRuntime = disabledComposition.makeWorkProvenanceRuntime(catalog: SettingCatalog())

        #expect(disabledRuntime.lifecycleState == WorkProvenanceRuntimeLifecycleState.stopped)
        #expect(disabledRuntime.effectiveDatabaseURL == nil)
        #expect(!FileManager.default.fileExists(atPath: Self.databaseURL(in: disabledHomeDirectory).path))
    }

    private static func temporaryDirectory(named name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-runtime-composition-tests-\(UUID().uuidString)")
            .appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func databaseURL(in homeDirectory: URL) -> URL {
        WorkProvenanceStorageLocation(homeDirectory: homeDirectory).databaseURL
    }
}
