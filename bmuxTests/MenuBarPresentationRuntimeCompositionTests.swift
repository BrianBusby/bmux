import AppKit
import BmuxAuthRuntime
import BmuxSettings
import BmuxSettingsUI
import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite(.serialized)
struct MenuBarPresentationRuntimeCompositionTests {
    @Test func currentXCTestProcessDisablesMenuBarPresentationByDefault() throws {
        let homeDirectory = try Self.temporaryDirectory(named: "default-disabled")
        let harness = MenuBarPresentationRuntimeTestHarness()
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

        services.startMenuBarPresentationLifecycle(actions: harness.actions())

        #expect(configuration.processKind == .xctestHost)
        #expect(!configuration.enables(.menuBarPresentationLifecycle))
        #expect(services.menuBarPresentationLifecycleState == .disabled(reason: "disabled by composition"))
        #expect(services.startCount(for: .menuBarPresentationLifecycle) == 0)
        #expect(harness.events.isEmpty)
        #expect(harness.controllers.isEmpty)
    }

    @Test func productionProcessEnablesMenuBarPresentationCapability() throws {
        let homeDirectory = try Self.temporaryDirectory(named: "production-capability")
        let configuration = BmuxAppRuntimeConfiguration.currentProcess(
            environment: ["HOME": homeDirectory.path],
            fileManager: .default
        )

        #expect(configuration.processKind == .productionApp)
        #expect(configuration.enables(.menuBarPresentationLifecycle))
        #expect(configuration.enables(.notificationPushLifecycle))
        #expect(configuration.enables(.mobileHostAndPresence))
        #expect(configuration.enables(.browserAndDevTools))
        #expect(configuration.enables(.sidebarGitPullRequestObservation))
    }

    @Test func explicitCompositionStartsOnceReconcilesStartupAndStopsOnce() throws {
        let homeDirectory = try Self.temporaryDirectory(named: "start-stop")
        let harness = MenuBarPresentationRuntimeTestHarness()
        harness.currentActivationPolicy = .accessory
        harness.snapshot = Self.snapshot(
            menuBarOnly: false,
            showInMenuBar: true,
            activationPolicy: .regular
        )
        let services = Self.runtimeServices(homeDirectory: homeDirectory, harness: harness)

        services.startMenuBarPresentationLifecycle(actions: harness.actions())
        services.startMenuBarPresentationLifecycle(actions: harness.actions())

        #expect(services.menuBarPresentationLifecycleState == .ready)
        #expect(services.startCount(for: .menuBarPresentationLifecycle) == 1)
        #expect(harness.validateRequiredRuntimeCount == 1)
        #expect(harness.preferenceObserverInstallCount == 1)
        #expect(harness.makeMenuBarExtraControllerCount == 1)
        #expect(harness.setActivationPolicies == [.regular])
        #expect(harness.menuRefreshHandlerInstallStates == [true])

        services.stop()
        services.stop()

        #expect(services.menuBarPresentationLifecycleState == .stopped)
        #expect(!services.menuBarPresentationRuntimeService.hasActiveLifecycleWork)
        #expect(harness.preferenceObserverRemoveCount == 1)
        #expect(harness.controllers.map(\.removeCount) == [1])
        #expect(harness.menuRefreshHandlerInstallStates == [true, false])
        #expect(harness.activeObserverTokens.isEmpty)
    }

    @Test func preferenceChangesReconcileThroughStartedRuntime() throws {
        let homeDirectory = try Self.temporaryDirectory(named: "preference-changes")
        let harness = MenuBarPresentationRuntimeTestHarness()
        harness.snapshot = Self.snapshot(menuBarOnly: false, showInMenuBar: true)
        let services = Self.runtimeServices(homeDirectory: homeDirectory, harness: harness)

        services.startMenuBarPresentationLifecycle(actions: harness.actions())
        #expect(harness.makeMenuBarExtraControllerCount == 1)

        harness.snapshot = Self.snapshot(menuBarOnly: false, showInMenuBar: false)
        harness.postPreferencesDidChange()

        #expect(harness.controllers.map(\.removeCount) == [1])
        #expect(harness.menuRefreshHandlerInstallStates == [true, false])

        harness.snapshot = Self.snapshot(
            menuBarOnly: true,
            showInMenuBar: false,
            activationPolicy: .accessory
        )
        harness.postPreferencesDidChange()

        #expect(services.menuBarPresentationLifecycleState == .ready)
        #expect(harness.makeMenuBarExtraControllerCount == 2)
        #expect(harness.setActivationPolicies == [.accessory])
        #expect(harness.controllers.map(\.removeCount) == [1, 0])

        services.stop()
    }

    @Test func settingsHostActionPersistsThroughRuntimeAndReconcilesImmediately() throws {
        let homeDirectory = try Self.temporaryDirectory(named: "settings-host")
        let harness = MenuBarPresentationRuntimeTestHarness()
        harness.snapshot = Self.snapshot(menuBarOnly: false, showInMenuBar: false)
        let runtime = Self.settingsAndServices(homeDirectory: homeDirectory, harness: harness)

        runtime.services.startMenuBarPresentationLifecycle(actions: harness.actions())
        #expect(runtime.services.menuBarPresentationLifecycleState == .ready)
        #expect(harness.makeMenuBarExtraControllerCount == 0)

        #expect(runtime.settings.hostActions.setMenuBarOnly(true))

        #expect(harness.setMenuBarOnlyPreferenceValues == [true])
        #expect(harness.makeMenuBarExtraControllerCount == 1)
        #expect(harness.setActivationPolicies == [.accessory])
        #expect(runtime.services.menuBarPresentationLifecycleState == .ready)

        runtime.services.stop()
    }

    @Test func activationPolicyFailureDegradesWithoutLosingObserverAndCanRecover() throws {
        let homeDirectory = try Self.temporaryDirectory(named: "activation-degraded")
        let harness = MenuBarPresentationRuntimeTestHarness()
        harness.currentActivationPolicy = .regular
        harness.snapshot = Self.snapshot(
            menuBarOnly: true,
            showInMenuBar: false,
            activationPolicy: .accessory
        )
        harness.setActivationPolicyResult = false
        let services = Self.runtimeServices(homeDirectory: homeDirectory, harness: harness)

        services.startMenuBarPresentationLifecycle(actions: harness.actions())

        #expect(services.menuBarPresentationLifecycleState == .degraded(reason: "activation policy update failed"))
        #expect(harness.preferenceObserverInstallCount == 1)
        #expect(harness.makeMenuBarExtraControllerCount == 1)

        harness.setActivationPolicyResult = true
        harness.postPreferencesDidChange()

        #expect(services.menuBarPresentationLifecycleState == .ready)
        #expect(harness.setActivationPolicies == [.accessory, .accessory])

        services.stop()
        #expect(services.menuBarPresentationLifecycleState == .stopped)
        #expect(harness.preferenceObserverRemoveCount == 1)
    }

    @Test func stoppedRuntimeIgnoresPreferenceCallbacksAndHotkeys() throws {
        let homeDirectory = try Self.temporaryDirectory(named: "stopped")
        let harness = MenuBarPresentationRuntimeTestHarness()
        harness.snapshot = Self.snapshot(menuBarOnly: false, showInMenuBar: false)
        let services = Self.runtimeServices(homeDirectory: homeDirectory, harness: harness)

        services.startMenuBarPresentationLifecycle(actions: harness.actions())
        services.stop()
        harness.snapshot = Self.snapshot(menuBarOnly: false, showInMenuBar: true)
        harness.postPreferencesDidChange()

        #expect(harness.makeMenuBarExtraControllerCount == 0)
        #expect(!services.toggleGlobalSearchPaletteFromMenuBarRuntime())
        #expect(services.menuBarPresentationLifecycleState == .stopped)
    }

    @Test func transientGlobalSearchControllerIsOwnedAndTornDown() throws {
        let homeDirectory = try Self.temporaryDirectory(named: "transient")
        let harness = MenuBarPresentationRuntimeTestHarness()
        harness.snapshot = Self.snapshot(menuBarOnly: false, showInMenuBar: false)
        let services = Self.runtimeServices(homeDirectory: homeDirectory, harness: harness)

        services.startMenuBarPresentationLifecycle(actions: harness.actions())

        #expect(services.toggleGlobalSearchPaletteFromMenuBarRuntime())
        #expect(harness.makeMenuBarExtraControllerCount == 1)
        #expect(harness.controllers[0].toggleCount == 1)

        harness.controllers[0].dismissal?()

        #expect(harness.controllers[0].removeCount == 1)
        #expect(services.toggleGlobalSearchPaletteFromMenuBarRuntime())
        #expect(harness.makeMenuBarExtraControllerCount == 2)

        services.stop()

        #expect(harness.controllers.map(\.removeCount) == [1, 1])
        #expect(services.menuBarPresentationLifecycleState == .stopped)
    }

    @Test func failedStartupDoesNotInstallResourcesAndCanRestartAfterStop() throws {
        let homeDirectory = try Self.temporaryDirectory(named: "failed-restart")
        let harness = MenuBarPresentationRuntimeTestHarness(
            validateRequiredRuntimeResult: .failed(reason: "presentation runtime unavailable")
        )
        let services = Self.runtimeServices(homeDirectory: homeDirectory, harness: harness)

        services.startMenuBarPresentationLifecycle(actions: harness.actions())
        services.startMenuBarPresentationLifecycle(actions: harness.actions())

        #expect(services.menuBarPresentationLifecycleState == .failed(reason: "presentation runtime unavailable"))
        #expect(services.startCount(for: .menuBarPresentationLifecycle) == 1)
        #expect(harness.preferenceObserverInstallCount == 0)
        #expect(harness.makeMenuBarExtraControllerCount == 0)

        services.stop()
        harness.validateRequiredRuntimeResult = .ready
        services.startMenuBarPresentationLifecycle(actions: harness.actions())

        #expect(services.menuBarPresentationLifecycleState == .ready)
        #expect(services.startCount(for: .menuBarPresentationLifecycle) == 2)

        services.stop()
    }

    fileprivate static func snapshot(
        menuBarOnly: Bool,
        showInMenuBar: Bool,
        activationPolicy: NSApplication.ActivationPolicy? = nil,
        presentationMode: WorkspacePresentationModeSettings.Mode = .standard
    ) -> MenuBarPresentationRuntimePreferenceSnapshot {
        MenuBarPresentationRuntimePreferenceSnapshot(
            menuBarOnlyEnabled: menuBarOnly,
            showsMenuBarExtra: showInMenuBar,
            shouldInstallMenuBarExtra: menuBarOnly || showInMenuBar,
            activationPolicy: activationPolicy ?? (menuBarOnly ? .accessory : .regular),
            workspacePresentationMode: presentationMode
        )
    }

    private static func temporaryDirectory(named name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-menu-bar-presentation-runtime-tests-\(UUID().uuidString)")
            .appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func runtimeServices(
        homeDirectory: URL,
        configuration: BmuxAppRuntimeConfiguration? = nil,
        harness: MenuBarPresentationRuntimeTestHarness
    ) -> BmuxAppRuntimeServices {
        let configuration = configuration ?? .test(
            enabledCapabilities: [.menuBarPresentationLifecycle],
            workProvenanceHomeDirectory: homeDirectory
        )
        let composition = BmuxAppRuntimeComposition(
            configFileURL: homeDirectory.appendingPathComponent("bmux.json"),
            secretBaseDirectory: homeDirectory.appendingPathComponent("secrets"),
            bundleIdentifier: "com.example.bmux-menu-bar-presentation-tests",
            runtimeConfiguration: configuration,
            menuBarPresentationRuntimeDependencies: harness.dependencies()
        )
        let workProvenanceRuntime = composition.makeWorkProvenanceRuntime(catalog: SettingCatalog())
        return composition.makeRuntimeServices(workProvenanceRuntime: workProvenanceRuntime)
    }

    private static func settingsAndServices(
        homeDirectory: URL,
        configuration: BmuxAppRuntimeConfiguration? = nil,
        harness: MenuBarPresentationRuntimeTestHarness
    ) -> (settings: SettingsRuntime, services: BmuxAppRuntimeServices) {
        let configuration = configuration ?? .test(
            enabledCapabilities: [.menuBarPresentationLifecycle],
            workProvenanceHomeDirectory: homeDirectory
        )
        let defaults = UserDefaults(suiteName: "bmux-menu-bar-presentation-runtime-tests-\(UUID().uuidString)")!
        let authComposition = MacAuthComposition(environment: [:], defaults: defaults)
        let composition = BmuxAppRuntimeComposition(
            configFileURL: homeDirectory.appendingPathComponent("bmux.json"),
            secretBaseDirectory: homeDirectory.appendingPathComponent("secrets"),
            bundleIdentifier: "com.example.bmux-menu-bar-presentation-tests",
            runtimeConfiguration: configuration,
            menuBarPresentationRuntimeDependencies: harness.dependencies()
        )
        let catalog = SettingCatalog()
        let settings = composition.makeSettingsRuntime(
            catalog: catalog,
            authComposition: authComposition,
            configFileURL: homeDirectory.appendingPathComponent("bmux.json")
        )
        let workProvenanceRuntime = composition.makeWorkProvenanceRuntime(catalog: catalog)
        let services = composition.makeRuntimeServices(workProvenanceRuntime: workProvenanceRuntime)
        return (settings, services)
    }
}

@MainActor
private final class RecordingMenuBarPresentationController: MenuBarPresentationMenuBarExtraControlling {
    var removeCount = 0
    var refreshCount = 0
    var toggleCount = 0
    var toggleResult = true
    var dismissal: (() -> Void)?

    func removeFromMenuBar() {
        removeCount += 1
    }

    func refreshForDebugControls() {
        refreshCount += 1
    }

    func toggleGlobalSearchPalette(onDismiss: (() -> Void)?) -> Bool {
        toggleCount += 1
        dismissal = onDismiss
        return toggleResult
    }
}

@MainActor
private final class MenuBarPresentationRuntimeTestHarness {
    private final class ObserverToken: NSObject {
        let name: String

        init(name: String) {
            self.name = name
        }
    }

    var validateRequiredRuntimeResult: MenuBarPresentationRuntimeOperationResult
    var snapshot = MenuBarPresentationRuntimeCompositionTests.snapshot(
        menuBarOnly: false,
        showInMenuBar: true
    )
    var currentActivationPolicy = NSApplication.ActivationPolicy.regular
    var setActivationPolicyResult = true
    var validateRequiredRuntimeCount = 0
    var normalizeLegacyStoredPreferenceCount = 0
    var currentPreferenceSnapshotCount = 0
    var preferenceObserverInstallCount = 0
    var preferenceObserverRemoveCount = 0
    var makeMenuBarExtraControllerCount = 0
    var menuRefreshHandlerInstallStates: [Bool] = []
    var setMenuBarOnlyPreferenceValues: [Bool] = []
    var setActivationPolicies: [NSApplication.ActivationPolicy] = []
    var activeObserverTokens: [String] = []
    var events: [String] = []
    var controllers: [RecordingMenuBarPresentationController] = []
    private var preferenceHandler: (@MainActor () -> Void)?

    init(validateRequiredRuntimeResult: MenuBarPresentationRuntimeOperationResult = .ready) {
        self.validateRequiredRuntimeResult = validateRequiredRuntimeResult
    }

    func dependencies() -> MenuBarPresentationRuntimeServiceDependencies {
        MenuBarPresentationRuntimeServiceDependencies(
            validateRequiredRuntime: {
                self.validateRequiredRuntimeCount += 1
                self.events.append("validateRequiredRuntime")
                return self.validateRequiredRuntimeResult
            },
            normalizeLegacyStoredPreference: {
                self.normalizeLegacyStoredPreferenceCount += 1
                self.events.append("normalizeLegacyStoredPreference")
            },
            currentPreferenceSnapshot: {
                self.currentPreferenceSnapshotCount += 1
                self.events.append("currentPreferenceSnapshot")
                return self.snapshot
            },
            setMenuBarOnlyPreference: { enabled in
                self.setMenuBarOnlyPreferenceValues.append(enabled)
                self.events.append("setMenuBarOnlyPreference")
                self.snapshot = MenuBarPresentationRuntimeCompositionTests.snapshot(
                    menuBarOnly: enabled,
                    showInMenuBar: self.snapshot.showsMenuBarExtra,
                    activationPolicy: enabled ? .accessory : .regular,
                    presentationMode: self.snapshot.workspacePresentationMode
                )
                return true
            },
            currentActivationPolicy: {
                self.events.append("currentActivationPolicy")
                return self.currentActivationPolicy
            },
            setActivationPolicy: { policy in
                self.setActivationPolicies.append(policy)
                self.events.append("setActivationPolicy")
                if self.setActivationPolicyResult {
                    self.currentActivationPolicy = policy
                }
                return self.setActivationPolicyResult
            },
            makePreferencesObserver: { handler in
                self.preferenceObserverInstallCount += 1
                self.preferenceHandler = handler
                let tokenName = "preferences-\(self.preferenceObserverInstallCount)"
                self.activeObserverTokens.append(tokenName)
                self.events.append("makePreferencesObserver")
                return ObserverToken(name: tokenName)
            },
            removePreferencesObserver: { observer in
                self.preferenceObserverRemoveCount += 1
                self.events.append("removePreferencesObserver")
                guard let token = observer as? ObserverToken else { return }
                self.activeObserverTokens.removeAll { $0 == token.name }
                if self.activeObserverTokens.isEmpty {
                    self.preferenceHandler = nil
                }
            },
            setMenuRefreshHandler: { handler in
                self.menuRefreshHandlerInstallStates.append(handler != nil)
                self.events.append(handler == nil ? "clearMenuRefreshHandler" : "setMenuRefreshHandler")
            }
        )
    }

    func actions() -> MenuBarPresentationRuntimeUIActions {
        MenuBarPresentationRuntimeUIActions(
            makeMenuBarExtraController: {
                self.makeMenuBarExtraControllerCount += 1
                self.events.append("makeMenuBarExtraController")
                let controller = RecordingMenuBarPresentationController()
                self.controllers.append(controller)
                return controller
            }
        )
    }

    func postPreferencesDidChange() {
        preferenceHandler?()
    }
}
