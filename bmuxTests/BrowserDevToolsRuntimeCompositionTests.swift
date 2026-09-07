import AppKit
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
struct BrowserDevToolsRuntimeCompositionTests {
    @Test func testCurrentXCTestProcessDisablesBrowserDevToolsByDefault() throws {
        let homeDirectory = try Self.temporaryDirectory(named: "default-disabled")
        let harness = BrowserDevToolsRuntimeTestHarness()
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

        services.startBrowserAndDevTools()

        #expect(configuration.processKind == BmuxAppRuntimeProcessKind.xctestHost)
        #expect(!(configuration.enables(BmuxAppRuntimeCapability.browserAndDevTools)))
        #expect(services.browserDevToolsLifecycleState == .disabled(reason: "disabled by composition"))
        #expect(services.startCount(for: BmuxAppRuntimeCapability.browserAndDevTools) == 0)
        #expect(harness.validateRequiredRuntimeCount == 0)
        #expect(harness.startSystemProxyObservationCount == 0)
        #expect(harness.focusObserverInstallCount == 0)
        #expect(harness.blurObserverInstallCount == 0)
        #expect(harness.webViewObserverInstallCount == 0)
        #expect(harness.closeAllWebInspectorsCount == 0)
        #expect(harness.discardPrewarmedWebViewsCount == 0)
        #expect(harness.flushBrowserProfileSavesCount == 0)
    }

    @Test func testProductionProcessEnablesBrowserDevToolsCapability() throws {
        let homeDirectory = try Self.temporaryDirectory(named: "production-capability")
        let configuration = BmuxAppRuntimeConfiguration.currentProcess(
            environment: ["HOME": homeDirectory.path],
            fileManager: .default
        )

        #expect(configuration.processKind == BmuxAppRuntimeProcessKind.productionApp)
        #expect(configuration.enables(BmuxAppRuntimeCapability.browserAndDevTools))
        #expect(configuration.enables(BmuxAppRuntimeCapability.mobileHostAndPresence))
        #expect(configuration.enables(BmuxAppRuntimeCapability.workProvenanceObservation))
        #expect(configuration.enables(BmuxAppRuntimeCapability.agentChatExecutionTelemetryProjection))
    }

    @Test func testExplicitCompositionStartsBrowserDevToolsOnceAndStopsDeterministically() throws {
        let homeDirectory = try Self.temporaryDirectory(named: "opt-in")
        let harness = BrowserDevToolsRuntimeTestHarness()
        let services = Self.runtimeServices(homeDirectory: homeDirectory, harness: harness)
        var focusEvents: [UUID] = []
        var blurEvents: [(UUID, Bool)] = []
        var webViewEvents = 0
        let handlers = BrowserDevToolsRuntimeEventHandlers(
            addressBarFocused: { panelId in
                focusEvents.append(panelId)
            },
            addressBarBlurred: { panelId, wasTracked in
                blurEvents.append((panelId, wasTracked))
            },
            webViewBecameFirstResponder: { _ in
                webViewEvents += 1
            }
        )

        services.startBrowserAndDevTools(handlers: handlers)
        services.startBrowserAndDevTools(handlers: handlers)

        #expect(services.browserDevToolsLifecycleState == .ready)
        #expect(services.browserDevToolsLifecycleState.isUsable)
        #expect(services.startCount(for: BmuxAppRuntimeCapability.browserAndDevTools) == 1)
        #expect(harness.validateRequiredRuntimeCount == 1)
        #expect(harness.startSystemProxyObservationCount == 1)
        #expect(harness.focusObserverInstallCount == 1)
        #expect(harness.blurObserverInstallCount == 1)
        #expect(harness.webViewObserverInstallCount == 1)
        #expect(harness.removeObserverCount == 0)

        let panelId = UUID()
        harness.postAddressBarFocus(panelId)
        #expect(services.focusedBrowserAddressBarPanelId == panelId)
        harness.postWebViewFirstResponder()
        harness.postAddressBarBlur(panelId)
        #expect(services.focusedBrowserAddressBarPanelId == nil)
        #expect(focusEvents == [panelId])
        #expect(blurEvents.count == 1)
        #expect(blurEvents.first?.0 == panelId)
        #expect(blurEvents.first?.1 == true)
        #expect(webViewEvents == 1)

        services.stopBrowserAndDevToolsForAppTermination()
        services.stop()

        #expect(services.browserDevToolsLifecycleState == .stopped)
        #expect(!(services.browserDevToolsRuntimeService.hasActiveLifecycleWork))
        #expect(harness.stopSystemProxyObservationCount == 1)
        #expect(harness.removeObserverCount == 3)
        #expect(harness.closeAllWebInspectorsCount == 1)
        #expect(harness.discardPrewarmedWebViewsCount == 1)
        #expect(harness.flushBrowserProfileSavesCount == 1)
    }

    @Test func testRequiredFailureAndProxyDegradeStatesAreObservable() throws {
        let failedHomeDirectory = try Self.temporaryDirectory(named: "required-failure")
        let failedHarness = BrowserDevToolsRuntimeTestHarness(
            validateRequiredRuntimeResult: .failed(reason: "required browser runtime unavailable")
        )
        let failedServices = Self.runtimeServices(
            homeDirectory: failedHomeDirectory,
            harness: failedHarness
        )

        failedServices.startBrowserAndDevTools()

        #expect(failedServices.browserDevToolsLifecycleState == .failed(reason: "required browser runtime unavailable"))
        #expect(!(failedServices.browserDevToolsLifecycleState.isUsable))
        #expect(failedServices.startCount(for: BmuxAppRuntimeCapability.browserAndDevTools) == 1)
        #expect(failedHarness.validateRequiredRuntimeCount == 1)
        #expect(failedHarness.startSystemProxyObservationCount == 0)
        #expect(failedHarness.focusObserverInstallCount == 0)

        failedServices.stop()

        #expect(failedServices.browserDevToolsLifecycleState == .stopped)
        #expect(failedHarness.closeAllWebInspectorsCount == 0)
        #expect(failedHarness.flushBrowserProfileSavesCount == 0)

        let degradedHomeDirectory = try Self.temporaryDirectory(named: "proxy-degraded")
        let degradedHarness = BrowserDevToolsRuntimeTestHarness(
            startSystemProxyObservationResult: .failed(reason: "system proxy unavailable")
        )
        let degradedServices = Self.runtimeServices(
            homeDirectory: degradedHomeDirectory,
            harness: degradedHarness
        )

        degradedServices.startBrowserAndDevTools()

        #expect(degradedServices.browserDevToolsLifecycleState == .degraded(reason: "system proxy unavailable"))
        #expect(degradedServices.browserDevToolsLifecycleState.isUsable)
        #expect(degradedHarness.startSystemProxyObservationCount == 1)
        #expect(degradedHarness.focusObserverInstallCount == 1)

        degradedServices.stop()

        #expect(degradedServices.browserDevToolsLifecycleState == .stopped)
        #expect(degradedHarness.stopSystemProxyObservationCount == 1)
        #expect(degradedHarness.removeObserverCount == 3)
    }

    @Test func testShutdownIsSafeBeforeReadinessAndAfterPartialFailure() throws {
        let beforeReadyHomeDirectory = try Self.temporaryDirectory(named: "stop-before-start")
        let beforeReadyHarness = BrowserDevToolsRuntimeTestHarness()
        let beforeReadyServices = Self.runtimeServices(
            homeDirectory: beforeReadyHomeDirectory,
            harness: beforeReadyHarness
        )

        beforeReadyServices.stop()
        beforeReadyServices.stopBrowserAndDevToolsForAppTermination()

        #expect(beforeReadyServices.browserDevToolsLifecycleState == .stopped)
        #expect(beforeReadyHarness.stopSystemProxyObservationCount == 0)
        #expect(beforeReadyHarness.removeObserverCount == 0)
        #expect(beforeReadyHarness.closeAllWebInspectorsCount == 0)
        #expect(beforeReadyHarness.flushBrowserProfileSavesCount == 0)

        let degradedHomeDirectory = try Self.temporaryDirectory(named: "stop-after-degraded")
        let degradedHarness = BrowserDevToolsRuntimeTestHarness(
            startSystemProxyObservationResult: .degraded(reason: "proxy mirror delayed")
        )
        let degradedServices = Self.runtimeServices(
            homeDirectory: degradedHomeDirectory,
            harness: degradedHarness
        )

        degradedServices.startBrowserAndDevTools()
        degradedServices.stopBrowserAndDevToolsForAppTermination()
        degradedServices.stop()

        #expect(degradedServices.browserDevToolsLifecycleState == .stopped)
        #expect(degradedHarness.stopSystemProxyObservationCount == 1)
        #expect(degradedHarness.removeObserverCount == 3)
        #expect(degradedHarness.closeAllWebInspectorsCount == 1)
        #expect(degradedHarness.discardPrewarmedWebViewsCount == 1)
        #expect(degradedHarness.flushBrowserProfileSavesCount == 1)
    }

    @Test func testRestartAfterStopReinstallsOwnedWorkWithoutLeakingPreviousObservers() throws {
        let homeDirectory = try Self.temporaryDirectory(named: "restart")
        let harness = BrowserDevToolsRuntimeTestHarness()
        let services = Self.runtimeServices(homeDirectory: homeDirectory, harness: harness)

        services.startBrowserAndDevTools()
        services.stopBrowserAndDevToolsForAppTermination()
        services.startBrowserAndDevTools()
        services.stop()

        #expect(services.browserDevToolsLifecycleState == .stopped)
        #expect(services.startCount(for: BmuxAppRuntimeCapability.browserAndDevTools) == 2)
        #expect(harness.startSystemProxyObservationCount == 2)
        #expect(harness.stopSystemProxyObservationCount == 2)
        #expect(harness.focusObserverInstallCount == 2)
        #expect(harness.blurObserverInstallCount == 2)
        #expect(harness.webViewObserverInstallCount == 2)
        #expect(harness.removeObserverCount == 6)
        #expect(harness.activeObserverTokens.isEmpty)
    }

    @Test func testRuntimeServicesRouteInspectorAndFocusEntrypointsThroughOwner() throws {
        let homeDirectory = try Self.temporaryDirectory(named: "runtime-routes")
        let harness = BrowserDevToolsRuntimeTestHarness()
        let services = Self.runtimeServices(homeDirectory: homeDirectory, harness: harness)
        let panelId = UUID()

        services.startBrowserAndDevTools()
        services.setFocusedBrowserAddressBarPanelId(panelId)

        #expect(services.focusedBrowserAddressBarPanelId == panelId)
        #expect(services.clearFocusedBrowserAddressBarPanelId(panelId))
        #expect(services.focusedBrowserAddressBarPanelId == nil)
        #expect(services.closeBrowserWebInspectorsForAppTeardown() == 2)
        #expect(harness.closeAllWebInspectorsCount == 1)
        #expect(services.closeBrowserWebInspectors(in: NSWindow()) == 1)
        #expect(harness.closeWebInspectorsInWindowCount == 1)

        services.stop()

        #expect(harness.closeAllWebInspectorsCount == 1)
        #expect(harness.discardPrewarmedWebViewsCount == 1)
        #expect(harness.flushBrowserProfileSavesCount == 1)
    }

    @Test func testProductionCompositionPathStartsBrowserDevToolsAndTearsDown() throws {
        let homeDirectory = try Self.temporaryDirectory(named: "production-path")
        let harness = BrowserDevToolsRuntimeTestHarness()
        let configuration = BmuxAppRuntimeConfiguration.currentProcess(
            environment: ["BMUX_PROVENANCE_HOME": homeDirectory.path, "HOME": homeDirectory.path],
            fileManager: .default
        )
        let services = Self.runtimeServices(
            homeDirectory: homeDirectory,
            configuration: configuration,
            harness: harness
        )

        services.startBrowserAndDevTools()

        #expect(configuration.enables(BmuxAppRuntimeCapability.browserAndDevTools))
        #expect(services.browserDevToolsLifecycleState == .ready)
        #expect(harness.validateRequiredRuntimeCount == 1)
        #expect(harness.startSystemProxyObservationCount == 1)
        #expect(harness.focusObserverInstallCount == 1)
        #expect(harness.blurObserverInstallCount == 1)
        #expect(harness.webViewObserverInstallCount == 1)

        services.stop()

        #expect(services.browserDevToolsLifecycleState == .stopped)
        #expect(harness.stopSystemProxyObservationCount == 1)
        #expect(harness.removeObserverCount == 3)
    }

    private static func temporaryDirectory(named name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-browser-devtools-runtime-suite-\(UUID().uuidString)")
            .appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func runtimeServices(
        homeDirectory: URL,
        configuration: BmuxAppRuntimeConfiguration? = nil,
        harness: BrowserDevToolsRuntimeTestHarness
    ) -> BmuxAppRuntimeServices {
        let configuration = configuration ?? .test(
            enabledCapabilities: [BmuxAppRuntimeCapability.browserAndDevTools],
            workProvenanceHomeDirectory: homeDirectory
        )
        let composition = BmuxAppRuntimeComposition(
            configFileURL: homeDirectory.appendingPathComponent("bmux.json"),
            secretBaseDirectory: homeDirectory.appendingPathComponent("secrets"),
            bundleIdentifier: "com.example.bmux-suite",
            runtimeConfiguration: configuration,
            browserDevToolsRuntimeDependencies: harness.dependencies()
        )
        let runtime = composition.makeWorkProvenanceRuntime(catalog: SettingCatalog())
        return composition.makeRuntimeServices(workProvenanceRuntime: runtime)
    }

    @MainActor
    private final class BrowserDevToolsRuntimeTestHarness {
        private final class ObserverToken: NSObject {
            let name: String

            init(name: String) {
                self.name = name
            }
        }

        var validateRequiredRuntimeResult: BrowserDevToolsRuntimeOperationResult
        var startSystemProxyObservationResult: BrowserDevToolsRuntimeOperationResult
        var validateRequiredRuntimeCount = 0
        var startSystemProxyObservationCount = 0
        var stopSystemProxyObservationCount = 0
        var focusObserverInstallCount = 0
        var blurObserverInstallCount = 0
        var webViewObserverInstallCount = 0
        var removeObserverCount = 0
        var closeAllWebInspectorsCount = 0
        var closeWebInspectorsInWindowCount = 0
        var discardPrewarmedWebViewsCount = 0
        var flushBrowserProfileSavesCount = 0
        var activeObserverTokens: [String] = []
        private var focusHandler: (@MainActor (_ panelId: UUID) -> Void)?
        private var blurHandler: (@MainActor (_ panelId: UUID) -> Void)?
        private var webViewHandler: (@MainActor (_ notification: Notification) -> Void)?

        init(
            validateRequiredRuntimeResult: BrowserDevToolsRuntimeOperationResult = .ready,
            startSystemProxyObservationResult: BrowserDevToolsRuntimeOperationResult = .ready
        ) {
            self.validateRequiredRuntimeResult = validateRequiredRuntimeResult
            self.startSystemProxyObservationResult = startSystemProxyObservationResult
        }

        func dependencies() -> BrowserDevToolsRuntimeServiceDependencies {
            BrowserDevToolsRuntimeServiceDependencies(
                validateRequiredRuntime: {
                    self.validateRequiredRuntimeCount += 1
                    return self.validateRequiredRuntimeResult
                },
                startSystemProxyObservation: {
                    self.startSystemProxyObservationCount += 1
                    return self.startSystemProxyObservationResult
                },
                stopSystemProxyObservation: {
                    self.stopSystemProxyObservationCount += 1
                },
                makeAddressBarFocusObserver: { handler in
                    self.focusObserverInstallCount += 1
                    self.focusHandler = handler
                    return self.makeObserverToken(named: "focus-\(self.focusObserverInstallCount)")
                },
                makeAddressBarBlurObserver: { handler in
                    self.blurObserverInstallCount += 1
                    self.blurHandler = handler
                    return self.makeObserverToken(named: "blur-\(self.blurObserverInstallCount)")
                },
                makeWebViewFirstResponderObserver: { handler in
                    self.webViewObserverInstallCount += 1
                    self.webViewHandler = handler
                    return self.makeObserverToken(named: "webview-\(self.webViewObserverInstallCount)")
                },
                removeObserver: { observer in
                    self.removeObserverCount += 1
                    guard let token = observer as? ObserverToken else { return }
                    self.activeObserverTokens.removeAll { $0 == token.name }
                },
                closeAllWebInspectors: {
                    self.closeAllWebInspectorsCount += 1
                    return 2
                },
                closeWebInspectorsInWindow: { _ in
                    self.closeWebInspectorsInWindowCount += 1
                    return 1
                },
                discardPrewarmedWebViews: {
                    self.discardPrewarmedWebViewsCount += 1
                },
                flushBrowserProfileSaves: {
                    self.flushBrowserProfileSavesCount += 1
                }
            )
        }

        func postAddressBarFocus(_ panelId: UUID) {
            focusHandler?(panelId)
        }

        func postAddressBarBlur(_ panelId: UUID) {
            blurHandler?(panelId)
        }

        func postWebViewFirstResponder() {
            webViewHandler?(Notification(name: .browserDidBecomeFirstResponderWebView))
        }

        private func makeObserverToken(named name: String) -> ObserverToken {
            activeObserverTokens.append(name)
            return ObserverToken(name: name)
        }
    }
}
