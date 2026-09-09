import BmuxAuthRuntime
import BmuxNotifications
import BmuxSettings
import Foundation
import Testing
import UserNotifications

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite(.serialized)
struct NotificationPushRuntimeCompositionTests {
    @Test func currentXCTestProcessDisablesNotificationPushByDefault() throws {
        let homeDirectory = try Self.temporaryDirectory(named: "default-disabled")
        let harness = NotificationPushRuntimeTestHarness()
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

        Self.start(services, named: "default-disabled")

        #expect(!configuration.enables(.notificationPushLifecycle))
        #expect(services.notificationPushLifecycleState == .disabled(reason: "disabled by composition"))
        #expect(services.startCount(for: .notificationPushLifecycle) == 0)
        #expect(harness.events.isEmpty)
    }

    @Test func productionProcessEnablesNotificationPushCapability() throws {
        let homeDirectory = try Self.temporaryDirectory(named: "production-capability")
        let configuration = BmuxAppRuntimeConfiguration.currentProcess(
            environment: ["HOME": homeDirectory.path],
            fileManager: .default
        )

        #expect(configuration.processKind == .productionApp)
        #expect(configuration.enables(.notificationPushLifecycle))
        #expect(configuration.enables(.mobileHostAndPresence))
        #expect(configuration.enables(.browserAndDevTools))
        #expect(configuration.enables(.sidebarGitPullRequestObservation))
    }

    @Test func explicitTestCompositionStartsOnceAndStopsOnce() throws {
        let homeDirectory = try Self.temporaryDirectory(named: "opt-in")
        let harness = NotificationPushRuntimeTestHarness()
        let services = Self.runtimeServices(homeDirectory: homeDirectory, harness: harness)

        Self.start(services, named: "opt-in")
        Self.start(services, named: "opt-in-again")

        #expect(services.notificationPushLifecycleState == .ready)
        #expect(services.notificationPushLifecycleState.canRouteCallbacks)
        #expect(services.startCount(for: .notificationPushLifecycle) == 1)
        #expect(harness.makeDeliveryCoordinatorCount == 1)
        #expect(harness.deliveryCoordinator.configureCount == 1)
        #expect(harness.configurePhonePushCount == 1)
        #expect(harness.configureStoreForwardingCount == 1)
        #expect(harness.events == [
            "makeDeliveryCoordinator",
            "configureUserNotifications",
            "configurePhonePush",
            "configureStoreForwarding",
        ])

        services.stop()
        services.stop()

        #expect(services.notificationPushLifecycleState == .stopped)
        #expect(!services.notificationPushRuntimeService.hasActiveLifecycleWork)
        #expect(harness.resetStoreForwardingCount == 1)
        #expect(harness.stopPhonePushCount == 1)
    }

    @Test func degradedAndFailedStartupStatesAreObservable() throws {
        let degradedHarness = NotificationPushRuntimeTestHarness(
            validateRequiredRuntimeResult: .degraded(reason: "notification center degraded")
        )
        let degradedServices = Self.runtimeServices(
            homeDirectory: try Self.temporaryDirectory(named: "degraded"),
            harness: degradedHarness
        )
        Self.start(degradedServices, named: "degraded")

        #expect(degradedServices.notificationPushLifecycleState == .degraded(reason: "notification center degraded"))
        #expect(degradedHarness.makeDeliveryCoordinatorCount == 1)
        degradedServices.stop()

        let failedHarness = NotificationPushRuntimeTestHarness(
            validateRequiredRuntimeResult: .failed(reason: "notification runtime unavailable")
        )
        let failedServices = Self.runtimeServices(
            homeDirectory: try Self.temporaryDirectory(named: "failed"),
            harness: failedHarness
        )
        Self.start(failedServices, named: "failed")
        Self.start(failedServices, named: "failed-again")

        #expect(failedServices.notificationPushLifecycleState == .failed(reason: "notification runtime unavailable"))
        #expect(failedServices.startCount(for: .notificationPushLifecycle) == 1)
        #expect(failedHarness.validateRequiredRuntimeCount == 1)
        #expect(failedHarness.makeDeliveryCoordinatorCount == 0)
        #expect(failedHarness.configurePhonePushCount == 0)
        failedServices.stop()
        #expect(failedServices.notificationPushLifecycleState == .stopped)
    }

    @Test func appActiveTransitionRoutesOnlyWhileStarted() throws {
        let homeDirectory = try Self.temporaryDirectory(named: "app-active")
        let harness = NotificationPushRuntimeTestHarness()
        let services = Self.runtimeServices(homeDirectory: homeDirectory, harness: harness)

        services.notificationPushDidBecomeActive()
        #expect(harness.appActiveCount == 0)

        Self.start(services, named: "app-active")
        services.notificationPushDidBecomeActive()
        services.notificationPushDidBecomeActive()

        #expect(harness.appActiveCount == 2)

        services.stop()
        services.notificationPushDidBecomeActive()

        #expect(harness.appActiveCount == 2)
    }

    @Test func storeUsesInjectedPhoneForwarderOnlyWhileRuntimeStarted() throws {
        let homeDirectory = try Self.temporaryDirectory(named: "store-forwarding")
        let harness = NotificationPushRuntimeTestHarness()
        let services = Self.runtimeServices(homeDirectory: homeDirectory, harness: harness)
        let store = TerminalNotificationStore.shared
        let previousNotifications = store.notifications
        defer {
            services.stop()
            AppFocusState.overrideIsFocused = nil
            store.replaceNotificationsForTesting(previousNotifications)
            store.resetNotificationDeliveryHandlerForTesting()
            store.resetPhonePushForwarding()
        }
        AppFocusState.overrideIsFocused = false
        store.replaceNotificationsForTesting([])
        store.configureNotificationDeliveryHandlerForTesting { _, _, _ in }

        Self.start(services, named: "store-forwarding")
        store.addNotification(
            tabId: UUID(),
            surfaceId: UUID(),
            title: "Forward",
            subtitle: "",
            body: "Body"
        )

        #expect(harness.phonePushForwarding.forwarded.map(\.notification.title) == ["Forward"])
        #expect(harness.phonePushForwarding.forwarded.map(\.badgeCount) == [1])

        services.stop()
        store.addNotification(
            tabId: UUID(),
            surfaceId: UUID(),
            title: "After stop",
            subtitle: "",
            body: "Body"
        )

        #expect(harness.phonePushForwarding.forwarded.map(\.notification.title) == ["Forward"])
    }

    private static func temporaryDirectory(named name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-notification-push-runtime-tests-\(UUID().uuidString)")
            .appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func runtimeServices(
        homeDirectory: URL,
        configuration: BmuxAppRuntimeConfiguration? = nil,
        harness: NotificationPushRuntimeTestHarness
    ) -> BmuxAppRuntimeServices {
        let configuration = configuration ?? .test(
            enabledCapabilities: [.notificationPushLifecycle],
            workProvenanceHomeDirectory: homeDirectory
        )
        let composition = BmuxAppRuntimeComposition(
            configFileURL: homeDirectory.appendingPathComponent("bmux.json"),
            secretBaseDirectory: homeDirectory.appendingPathComponent("secrets"),
            bundleIdentifier: "com.example.bmux-notification-push-tests",
            runtimeConfiguration: configuration,
            notificationPushRuntimeDependencies: harness.dependencies()
        )
        let runtime = composition.makeWorkProvenanceRuntime(catalog: SettingCatalog())
        return composition.makeRuntimeServices(workProvenanceRuntime: runtime)
    }

    private static func start(_ services: BmuxAppRuntimeServices, named name: String) {
        services.startNotificationPushLifecycle(
            auth: authCoordinator(named: name),
            notificationStore: TerminalNotificationStore.shared,
            userNotificationDelegate: DummyNotificationDelegate(),
            terminalNavigation: RecordingTerminalNavigation(),
            feedReplying: RecordingFeedReplying(),
            applicationActivation: RecordingApplicationActivation(),
            actionTitles: actionTitles()
        )
    }

    private static func authCoordinator(named name: String) -> AuthCoordinator {
        let defaults = UserDefaults(suiteName: "bmux-notification-push-runtime-tests-\(name)-\(UUID().uuidString)")!
        return MacAuthComposition(environment: [:], defaults: defaults).coordinator
    }

    private static func actionTitles() -> NotificationDeliveryActionTitles {
        NotificationDeliveryActionTitles(
            show: "Show",
            feedPermissionAllowOnce: "Allow Once",
            feedPermissionAlways: "Always",
            feedPermissionAll: "All tools",
            feedPermissionDeny: "Deny",
            feedExitPlanUltraplan: "Ultraplan",
            feedExitPlanManual: "Manual",
            feedExitPlanAutoAccept: "Auto",
            feedQuestionReply: "Reply"
        )
    }
}

private final class DummyNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {}

@MainActor
private final class RecordingNotificationDeliveryCoordinator: NotificationPushDeliveryCoordinating {
    var configureCount = 0
    var delegate: (any UNUserNotificationCenterDelegate)?
    var onConfigure: (() -> Void)?

    func configureUserNotifications(delegate: any UNUserNotificationCenterDelegate) {
        configureCount += 1
        self.delegate = delegate
        onConfigure?()
    }

    func handleNotificationResponse(_ response: UNNotificationResponse) {}

    func presentationOptions(for notification: UNNotification) -> UNNotificationPresentationOptions { [] }
}

@MainActor
private final class RecordingTerminalNavigation: NotificationDeliveryTerminalNavigating {
    func open(tabId: UUID, surfaceId: UUID?, notificationId: UUID?) -> Bool { true }

    func openNotification(id: UUID, fallbackTabId: UUID, fallbackSurfaceId: UUID?) -> Bool { true }

    func performClickAction(_ action: NotificationNavClickAction) -> Bool { true }

    func markNotificationRead(id: UUID) {}
}

@MainActor
private final class RecordingFeedReplying: NotificationFeedReplying {
    func deliverReply(requestId: String, decision: NotificationFeedDecision) {}

    func permissionCapabilities(requestId: String) -> NotificationFeedPermissionCapabilities? { nil }
}

@MainActor
private final class RecordingApplicationActivation: NotificationApplicationActivating {
    func activateApplication() {}
}

@MainActor
private final class RecordingPhonePushForwarding: TerminalPhonePushForwarding {
    struct ForwardedNotification {
        let notification: TerminalNotification
        let badgeCount: Int
    }

    struct ForwardedDismissal {
        let ids: [String]
        let badgeCount: Int
    }

    var willForwardReplacementValue = false
    var forwarded: [ForwardedNotification] = []
    var forwardedDismissals: [ForwardedDismissal] = []

    func willForwardReplacement(defaults: UserDefaults) -> Bool {
        willForwardReplacementValue
    }

    func forward(_ notification: TerminalNotification, badgeCount: Int) -> Bool {
        forwarded.append(ForwardedNotification(notification: notification, badgeCount: badgeCount))
        return true
    }

    func forwardDismissed(ids: [String], badgeCount: Int) {
        forwardedDismissals.append(ForwardedDismissal(ids: ids, badgeCount: badgeCount))
    }
}

@MainActor
private final class NotificationPushRuntimeTestHarness {
    let validateRequiredRuntimeResult: NotificationPushRuntimeOperationResult
    let deliveryCoordinator = RecordingNotificationDeliveryCoordinator()
    let phonePushForwarding = RecordingPhonePushForwarding()
    var validateRequiredRuntimeCount = 0
    var makeDeliveryCoordinatorCount = 0
    var configurePhonePushCount = 0
    var stopPhonePushCount = 0
    var configureStoreForwardingCount = 0
    var resetStoreForwardingCount = 0
    var appActiveCount = 0
    var events: [String] = []

    init(validateRequiredRuntimeResult: NotificationPushRuntimeOperationResult = .ready) {
        self.validateRequiredRuntimeResult = validateRequiredRuntimeResult
    }

    func dependencies() -> NotificationPushRuntimeServiceDependencies {
        NotificationPushRuntimeServiceDependencies(
            validateRequiredRuntime: {
                self.validateRequiredRuntimeCount += 1
                return self.validateRequiredRuntimeResult
            },
            makeDeliveryCoordinator: { _, _, _, _ in
                self.makeDeliveryCoordinatorCount += 1
                self.events.append("makeDeliveryCoordinator")
                self.deliveryCoordinator.onConfigure = {
                    self.events.append("configureUserNotifications")
                }
                return self.deliveryCoordinator
            },
            configurePhonePushClient: { _ in
                self.configurePhonePushCount += 1
                self.events.append("configurePhonePush")
            },
            stopPhonePushClient: {
                self.stopPhonePushCount += 1
                self.events.append("stopPhonePush")
            },
            phonePushForwarding: phonePushForwarding,
            configureStorePhonePushForwarding: { store, forwarding in
                self.configureStoreForwardingCount += 1
                self.events.append("configureStoreForwarding")
                store.configurePhonePushForwarding(forwarding)
            },
            resetStorePhonePushForwarding: { store in
                self.resetStoreForwardingCount += 1
                self.events.append("resetStoreForwarding")
                store.resetPhonePushForwarding()
            },
            handleApplicationDidBecomeActive: { _ in
                self.appActiveCount += 1
                self.events.append("appDidBecomeActive")
            }
        )
    }
}
