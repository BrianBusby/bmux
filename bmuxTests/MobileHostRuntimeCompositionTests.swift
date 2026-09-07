import BmuxAuthRuntime
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
struct MobileHostRuntimeCompositionTests {
    @Test
    func currentXCTestProcessDisablesMobileHostByDefault() throws {
        let homeDirectory = try Self.temporaryDirectory(named: "default-disabled")
        let harness = MobileHostRuntimeTestHarness()
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

        services.startMobileHostAndPresence(
            auth: Self.authCoordinator(named: "default-disabled"),
            tabManager: TabManager(),
            notificationStore: nil
        )

        #expect(!configuration.enables(BmuxAppRuntimeCapability.mobileHostAndPresence))
        #expect(services.mobileHostLifecycleState == MobileHostRuntimeLifecycleState.disabled(reason: "disabled by composition"))
        #expect(services.startCount(for: BmuxAppRuntimeCapability.mobileHostAndPresence) == 0)
        #expect(harness.configureHostCount == 0)
        #expect(harness.syncHostCount == 0)
        #expect(harness.startPresenceCount == 0)
        #expect(harness.startDeviceRegistryCount == 0)
        #expect(harness.startPairedMacBackupCount == 0)
        #expect(harness.startRenderObserverCount == 0)
        #expect(harness.makeWorkspaceObserverCount == 0)
    }

    @Test
    func productionProcessEnablesMobileHostCapability() throws {
        let homeDirectory = try Self.temporaryDirectory(named: "production-capability")
        let configuration = BmuxAppRuntimeConfiguration.currentProcess(
            environment: ["HOME": homeDirectory.path],
            fileManager: .default
        )

        #expect(configuration.processKind == BmuxAppRuntimeProcessKind.productionApp)
        #expect(configuration.enables(BmuxAppRuntimeCapability.mobileHostAndPresence))
        #expect(configuration.enables(BmuxAppRuntimeCapability.workProvenanceObservation))
        #expect(configuration.enables(BmuxAppRuntimeCapability.agentChatExecutionTelemetryProjection))
    }

    @Test
    func explicitTestCompositionStartsMobileHostOnceAndStopsDeterministically() throws {
        let homeDirectory = try Self.temporaryDirectory(named: "opt-in")
        let harness = MobileHostRuntimeTestHarness()
        let services = Self.runtimeServices(homeDirectory: homeDirectory, harness: harness)
        let tabManager = TabManager()

        services.startMobileHostAndPresence(
            auth: Self.authCoordinator(named: "opt-in"),
            tabManager: tabManager,
            notificationStore: nil
        )
        services.startMobileHostAndPresence(
            auth: Self.authCoordinator(named: "opt-in-second"),
            tabManager: tabManager,
            notificationStore: nil
        )

        #expect(services.mobileHostLifecycleState == MobileHostRuntimeLifecycleState.ready)
        #expect(services.startCount(for: BmuxAppRuntimeCapability.mobileHostAndPresence) == 1)
        #expect(harness.configureHostCount == 1)
        #expect(harness.startPresenceCount == 1)
        #expect(harness.startDeviceRegistryCount == 1)
        #expect(harness.startPairedMacBackupCount == 1)
        #expect(harness.startRenderObserverCount == 1)
        #expect(harness.makeWorkspaceObserverCount == 1)
        #expect(harness.lifecycleEvents.prefix(7) == [
            "configureHost",
            "syncHostToSettings",
            "startRenderObserver",
            "startPresence",
            "startDeviceRegistry",
            "startPairedMacBackup",
            "syncPresenceToSettings",
        ])

        services.stopMobileHostAndPresenceForAppTermination()
        services.stop()

        #expect(services.mobileHostLifecycleState == MobileHostRuntimeLifecycleState.stopped)
        #expect(!services.mobileHostRuntimeService.hasActiveLifecycleWork)
        #expect(harness.stopHostCount == 1)
        #expect(harness.stopPresenceCount == 1)
        #expect(harness.stopPresenceGoodbyeValues == [true])
        #expect(harness.stopDeviceRegistryCount == 1)
        #expect(harness.stopPairedMacBackupCount == 1)
        #expect(harness.stopRenderObserverCount == 1)
    }

    @Test
    func readinessFallbackFailureAndPublicationDegradeStateAreObservable() throws {
        let ready = try Self.startedServices(
            named: "ready",
            harness: MobileHostRuntimeTestHarness(status: Self.status(isRunning: true))
        )
        #expect(ready.services.mobileHostLifecycleState == MobileHostRuntimeLifecycleState.ready)
        #expect(ready.services.mobileHostLifecycleState.isListenerReady)
        ready.services.stop()

        let fallback = try Self.startedServices(
            named: "fallback",
            harness: MobileHostRuntimeTestHarness(status: Self.status(
                isRunning: true,
                port: 49152,
                usesEphemeralFallback: true
            ))
        )
        #expect(fallback.services.mobileHostLifecycleState == MobileHostRuntimeLifecycleState.degraded(
            reason: "preferred port unavailable; listening on ephemeral fallback"
        ))
        #expect(fallback.services.mobileHostLifecycleState.isListenerReady)
        fallback.services.stop()

        let listenerFailure = try Self.startedServices(
            named: "listener-failure",
            harness: MobileHostRuntimeTestHarness(status: Self.status(
                isRunning: false,
                port: nil,
                lastErrorDescription: "bind failed"
            ))
        )
        #expect(listenerFailure.services.mobileHostLifecycleState == MobileHostRuntimeLifecycleState.failed(reason: "bind failed"))
        listenerFailure.services.stop()

        let presenceFailure = try Self.startedServices(
            named: "presence-failure",
            harness: MobileHostRuntimeTestHarness(
                startPresenceResult: MobileHostRuntimeOperationResult.failed(reason: "presence unavailable")
            )
        )
        #expect(presenceFailure.services.mobileHostLifecycleState == MobileHostRuntimeLifecycleState.degraded(reason: "presence unavailable"))
        #expect(presenceFailure.services.mobileHostLifecycleState.isListenerReady)
        presenceFailure.services.stop()
    }

    @Test
    func settingsDisableAndReEnableOwnSideWork() throws {
        let homeDirectory = try Self.temporaryDirectory(named: "settings-reenable")
        let harness = MobileHostRuntimeTestHarness()
        let services = Self.runtimeServices(homeDirectory: homeDirectory, harness: harness)

        services.startMobileHostAndPresence(
            auth: Self.authCoordinator(named: "settings-reenable"),
            tabManager: TabManager(),
            notificationStore: nil
        )
        harness.isHostEnabled = false
        harness.status = Self.status(isRunning: false, port: nil)
        services.syncMobileHostAndPresenceToSettings()

        #expect(services.mobileHostLifecycleState == MobileHostRuntimeLifecycleState.disabled(reason: "disabled by settings"))
        #expect(harness.stopPresenceCount == 1)
        #expect(harness.stopDeviceRegistryCount == 1)
        #expect(harness.stopPairedMacBackupCount == 1)
        #expect(harness.stopRenderObserverCount == 1)

        harness.isHostEnabled = true
        harness.status = Self.status(isRunning: true)
        services.syncMobileHostAndPresenceToSettings()

        #expect(services.mobileHostLifecycleState == MobileHostRuntimeLifecycleState.ready)
        #expect(harness.configureHostCount == 2)
        #expect(harness.startPresenceCount == 2)
        #expect(harness.startDeviceRegistryCount == 2)
        #expect(harness.startPairedMacBackupCount == 2)
        #expect(harness.startRenderObserverCount == 2)

        services.stop()

        #expect(!services.mobileHostRuntimeService.hasActiveLifecycleWork)
        #expect(harness.stopHostCount == 1)
        #expect(harness.stopPresenceCount == 2)
        #expect(harness.stopDeviceRegistryCount == 2)
        #expect(harness.stopPairedMacBackupCount == 2)
        #expect(harness.stopRenderObserverCount == 2)
        #expect(harness.stopPresenceGoodbyeValues == [true, false])
    }

    @Test
    func authenticationAvailabilityStartsPublicationWithoutDuplicatingListenerLifecycle() throws {
        let homeDirectory = try Self.temporaryDirectory(named: "auth-late")
        let harness = MobileHostRuntimeTestHarness()
        let services = Self.runtimeServices(homeDirectory: homeDirectory, harness: harness)

        services.startMobileHostAndPresence(
            auth: Optional<AuthCoordinator>.none,
            tabManager: Optional<TabManager>.none,
            notificationStore: Optional<TerminalNotificationStore>.none
        )

        #expect(services.mobileHostLifecycleState == MobileHostRuntimeLifecycleState.degraded(reason: "waiting for authentication"))
        #expect(harness.configureHostCount == 0)
        #expect(harness.startPresenceCount == 0)
        #expect(harness.startRenderObserverCount == 1)

        harness.events.removeAll()
        services.startMobileHostAndPresence(
            auth: Self.authCoordinator(named: "auth-late"),
            tabManager: Optional<TabManager>.none,
            notificationStore: Optional<TerminalNotificationStore>.none
        )
        services.startMobileHostAndPresence(
            auth: Self.authCoordinator(named: "auth-late-second"),
            tabManager: Optional<TabManager>.none,
            notificationStore: Optional<TerminalNotificationStore>.none
        )

        #expect(services.mobileHostLifecycleState == MobileHostRuntimeLifecycleState.ready)
        #expect(services.startCount(for: BmuxAppRuntimeCapability.mobileHostAndPresence) == 1)
        #expect(harness.configureHostCount == 1)
        #expect(harness.startPresenceCount == 1)
        #expect(harness.startDeviceRegistryCount == 1)
        #expect(harness.startPairedMacBackupCount == 1)
        #expect(harness.lifecycleEvents.prefix(6) == [
            "configureHost",
            "syncHostToSettings",
            "startPresence",
            "startDeviceRegistry",
            "startPairedMacBackup",
            "syncPresenceToSettings",
        ])
        #expect(harness.startRenderObserverCount == 1)

        services.stop()
    }

    @Test
    func productionCompositionPathStartsMobileHostAndPublishesRoutes() throws {
        let homeDirectory = try Self.temporaryDirectory(named: "production-path")
        let harness = MobileHostRuntimeTestHarness()
        let configuration = BmuxAppRuntimeConfiguration.currentProcess(
            environment: ["BMUX_PROVENANCE_HOME": homeDirectory.path, "HOME": homeDirectory.path],
            fileManager: .default
        )
        let services = Self.runtimeServices(
            homeDirectory: homeDirectory,
            configuration: configuration,
            harness: harness
        )

        services.startMobileHostAndPresence(
            auth: Self.authCoordinator(named: "production-path"),
            tabManager: TabManager(),
            notificationStore: nil
        )

        #expect(configuration.enables(BmuxAppRuntimeCapability.mobileHostAndPresence))
        #expect(services.mobileHostLifecycleState == MobileHostRuntimeLifecycleState.ready)
        #expect(harness.configureHostCount == 1)
        #expect(harness.startPresenceCount == 1)
        #expect(harness.startDeviceRegistryCount == 1)
        #expect(harness.startPairedMacBackupCount == 1)

        services.stop()

        #expect(services.mobileHostLifecycleState == MobileHostRuntimeLifecycleState.stopped)
        #expect(harness.stopPresenceGoodbyeValues == [false])
    }

    private static func temporaryDirectory(named name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-mobile-host-runtime-tests-\(UUID().uuidString)")
            .appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func startedServices(
        named name: String,
        harness: MobileHostRuntimeTestHarness
    ) throws -> (services: BmuxAppRuntimeServices, harness: MobileHostRuntimeTestHarness) {
        let homeDirectory = try temporaryDirectory(named: name)
        let services = runtimeServices(homeDirectory: homeDirectory, harness: harness)
        services.startMobileHostAndPresence(
            auth: authCoordinator(named: name),
            tabManager: Optional<TabManager>.none,
            notificationStore: Optional<TerminalNotificationStore>.none
        )
        return (services, harness)
    }

    private static func runtimeServices(
        homeDirectory: URL,
        configuration: BmuxAppRuntimeConfiguration? = nil,
        harness: MobileHostRuntimeTestHarness
    ) -> BmuxAppRuntimeServices {
        let configuration = configuration ?? .test(
            enabledCapabilities: [BmuxAppRuntimeCapability.mobileHostAndPresence],
            workProvenanceHomeDirectory: homeDirectory
        )
        let composition = BmuxAppRuntimeComposition(
            configFileURL: homeDirectory.appendingPathComponent("bmux.json"),
            secretBaseDirectory: homeDirectory.appendingPathComponent("secrets"),
            bundleIdentifier: "com.example.bmux-tests",
            runtimeConfiguration: configuration,
            mobileHostRuntimeDependencies: harness.dependencies()
        )
        let runtime = composition.makeWorkProvenanceRuntime(catalog: SettingCatalog())
        return composition.makeRuntimeServices(workProvenanceRuntime: runtime)
    }

    private static func authCoordinator(named name: String) -> AuthCoordinator {
        let defaults = UserDefaults(suiteName: "bmux-mobile-host-runtime-tests-\(name)-\(UUID().uuidString)")!
        return MacAuthComposition(environment: [:], defaults: defaults).coordinator
    }

    private static func status(
        isRunning: Bool,
        port: Int? = 58465,
        configuredPort: Int = 58465,
        usesEphemeralFallback: Bool = false,
        lastErrorDescription: String? = nil
    ) -> MobileHostServiceStatus {
        MobileHostServiceStatus(
            isRunning: isRunning,
            port: port,
            configuredPort: configuredPort,
            usesEphemeralFallback: usesEphemeralFallback,
            routes: [],
            activeConnectionCount: 0,
            lastErrorDescription: lastErrorDescription
        )
    }

    private static func stoppedStatus() -> MobileHostServiceStatus {
        status(isRunning: false, port: nil)
    }

    @MainActor
    private final class MobileHostRuntimeTestHarness {
        var isHostEnabled: Bool
        var status: MobileHostServiceStatus
        var startPresenceResult: MobileHostRuntimeOperationResult
        var configureHostCount = 0
        var syncHostCount = 0
        var stopHostCount = 0
        var startPresenceCount = 0
        var syncPresenceCount = 0
        var stopPresenceCount = 0
        var stopPresenceGoodbyeValues: [Bool] = []
        var startDeviceRegistryCount = 0
        var stopDeviceRegistryCount = 0
        var startPairedMacBackupCount = 0
        var stopPairedMacBackupCount = 0
        var startRenderObserverCount = 0
        var stopRenderObserverCount = 0
        var makeWorkspaceObserverCount = 0
        var events: [String] = []

        var lifecycleEvents: [String] {
            events.filter { $0 != "makeWorkspaceListObserver" }
        }

        init(
            isHostEnabled: Bool = true,
            status: MobileHostServiceStatus? = nil,
            startPresenceResult: MobileHostRuntimeOperationResult = .ready
        ) {
            self.isHostEnabled = isHostEnabled
            self.status = status ?? MobileHostRuntimeCompositionTests.status(isRunning: true)
            self.startPresenceResult = startPresenceResult
        }

        func dependencies() -> MobileHostRuntimeServiceDependencies {
            MobileHostRuntimeServiceDependencies(
                isHostEnabled: { self.isHostEnabled },
                configureHost: { _ in
                    self.configureHostCount += 1
                    self.events.append("configureHost")
                },
                syncHostToSettings: {
                    self.syncHostCount += 1
                    self.events.append("syncHostToSettings")
                    return self.status
                },
                stopHost: {
                    self.stopHostCount += 1
                    self.events.append("stopHost")
                    self.status = MobileHostRuntimeCompositionTests.stoppedStatus()
                    return self.status
                },
                hostStatus: { self.status },
                hostStatusUpdates: {
                    let status = self.status
                    return AsyncStream { continuation in continuation.yield(status) }
                },
                startPresence: { _ in
                    self.startPresenceCount += 1
                    self.events.append("startPresence")
                    return self.startPresenceResult
                },
                syncPresenceToSettings: {
                    self.syncPresenceCount += 1
                    self.events.append("syncPresenceToSettings")
                    return MobileHostRuntimeOperationResult.ready
                },
                stopPresence: { sendsGoodbye in
                    self.stopPresenceCount += 1
                    self.stopPresenceGoodbyeValues.append(sendsGoodbye)
                    self.events.append("stopPresence")
                },
                startDeviceRegistry: { _ in
                    self.startDeviceRegistryCount += 1
                    self.events.append("startDeviceRegistry")
                    return MobileHostRuntimeOperationResult.ready
                },
                stopDeviceRegistry: {
                    self.stopDeviceRegistryCount += 1
                    self.events.append("stopDeviceRegistry")
                },
                startPairedMacBackup: { _ in
                    self.startPairedMacBackupCount += 1
                    self.events.append("startPairedMacBackup")
                    return MobileHostRuntimeOperationResult.ready
                },
                stopPairedMacBackup: {
                    self.stopPairedMacBackupCount += 1
                    self.events.append("stopPairedMacBackup")
                },
                startRenderObserver: {
                    self.startRenderObserverCount += 1
                    self.events.append("startRenderObserver")
                },
                stopRenderObserver: {
                    self.stopRenderObserverCount += 1
                    self.events.append("stopRenderObserver")
                },
                makeWorkspaceListObserver: { _, _ in
                    self.makeWorkspaceObserverCount += 1
                    self.events.append("makeWorkspaceListObserver")
                    return NSObject()
                }
            )
        }
    }
}
