import BMUXMobileCore
import BmuxAuthRuntime
import Foundation
import Testing
import UserNotifications
@testable import BmuxMobileShellUI

@MainActor
@Suite(.serialized)
struct MobilePushCoordinatorLifecycleTests {
    @Test func startIsIdempotentAndStopIsIdempotent() async {
        let defaults = UserDefaults(suiteName: "bmux-mobile-push-start-stop-\(UUID().uuidString)")!
        defaults.set(true, forKey: "bmux.notifications.pushEnabled")
        let system = RecordingMobilePushSystemClient()
        let registration = RecordingPushRegistration()
        let coordinator = MobilePushCoordinator(
            registration: registration,
            analytics: RecordingMobileAnalytics(),
            system: system,
            defaults: defaults
        )
        let delegate = DummyMobilePushNotificationDelegate()

        coordinator.start(delegate: delegate)
        coordinator.start(delegate: delegate)

        #expect(coordinator.lifecycleState == .ready)
        #expect(system.configureCount == 1)
        #expect(system.registerCount == 1)
        #expect(system.delegate === delegate)
        #expect(system.categories.map(\.identifier) == [MobilePushCoordinator.dismissSyncCategoryIdentifier])

        coordinator.stop()
        coordinator.stop()

        #expect(coordinator.lifecycleState == .stopped)
        #expect(system.clearDelegateCount == 1)
        #expect(system.delegate == nil)
        let snapshot = await registration.snapshot()
        #expect(snapshot.enabledValues.isEmpty)
    }

    @Test func startDoesNotRegisterWhenDisabled() {
        let defaults = UserDefaults(suiteName: "bmux-mobile-push-disabled-start-\(UUID().uuidString)")!
        let system = RecordingMobilePushSystemClient()
        let coordinator = MobilePushCoordinator(
            registration: RecordingPushRegistration(),
            analytics: RecordingMobileAnalytics(),
            system: system,
            defaults: defaults
        )

        coordinator.start(delegate: DummyMobilePushNotificationDelegate())

        #expect(coordinator.lifecycleState == .ready)
        #expect(system.configureCount == 1)
        #expect(system.registerCount == 0)
    }

    @Test func enableRequestsAuthorizationAndRegistersTokenLane() async {
        let defaults = UserDefaults(suiteName: "bmux-mobile-push-enable-\(UUID().uuidString)")!
        let system = RecordingMobilePushSystemClient()
        system.authorizationStatus = .notDetermined
        system.requestAuthorizationResult = true
        let registration = RecordingPushRegistration()
        let analytics = RecordingMobileAnalytics()
        let coordinator = MobilePushCoordinator(
            registration: registration,
            analytics: analytics,
            system: system,
            defaults: defaults
        )

        let granted = await coordinator.enable()

        #expect(granted)
        #expect(system.requestAuthorizationOptions == [.alert, .sound, .badge])
        #expect(system.registerCount == 1)
        let registrationSnapshot = await registration.snapshot()
        #expect(registrationSnapshot.enabledValues == [true])
        #expect(analytics.eventNames == [
            "ios_push_optin_prompt_shown",
            "ios_push_optin_granted",
        ])
    }

    @Test func enableDeniedDoesNotRegisterOrPersistOptIn() async {
        let defaults = UserDefaults(suiteName: "bmux-mobile-push-enable-denied-\(UUID().uuidString)")!
        let system = RecordingMobilePushSystemClient()
        system.authorizationStatus = .denied
        system.requestAuthorizationResult = false
        let registration = RecordingPushRegistration()
        let analytics = RecordingMobileAnalytics()
        let coordinator = MobilePushCoordinator(
            registration: registration,
            analytics: analytics,
            system: system,
            defaults: defaults
        )

        let granted = await coordinator.enable()

        #expect(!granted)
        #expect(system.registerCount == 0)
        let registrationSnapshot = await registration.snapshot()
        #expect(registrationSnapshot.enabledValues.isEmpty)
        #expect(analytics.eventNames == ["ios_push_optin_declined"])
        #expect(analytics.boolValue(for: "ios_push_optin_declined", key: "was_os_level_predenied") == true)
    }

    @Test func disableClearsServerFlagAndUnregistersSystemNotifications() async {
        let defaults = UserDefaults(suiteName: "bmux-mobile-push-disable-\(UUID().uuidString)")!
        let system = RecordingMobilePushSystemClient()
        let registration = RecordingPushRegistration()
        let coordinator = MobilePushCoordinator(
            registration: registration,
            analytics: RecordingMobileAnalytics(),
            system: system,
            defaults: defaults
        )

        await coordinator.disable()

        #expect(system.unregisterCount == 1)
        let registrationSnapshot = await registration.snapshot()
        #expect(registrationSnapshot.enabledValues == [false])
    }

    @Test func tokenAndFailureCallbacksRouteThroughCoordinator() async {
        let defaults = UserDefaults(suiteName: "bmux-mobile-push-callbacks-\(UUID().uuidString)")!
        let system = RecordingMobilePushSystemClient()
        let registration = RecordingPushRegistration()
        let analytics = RecordingMobileAnalytics()
        let coordinator = MobilePushCoordinator(
            registration: registration,
            analytics: analytics,
            system: system,
            defaults: defaults
        )

        await coordinator.handleDeviceToken(Data([0xde, 0xad, 0xbe, 0xef]))
        coordinator.handleRegistrationFailure(NSError(domain: "APNSTest", code: 42))

        let registrationSnapshot = await registration.snapshot()
        #expect(registrationSnapshot.deviceTokens == [Data([0xde, 0xad, 0xbe, 0xef])])
        #expect(analytics.eventNames == ["ios_push_token_registration_failed"])
        #expect(analytics.stringValue(for: "ios_push_token_registration_failed", key: "error_domain") == "APNSTest")
        #expect(analytics.intValue(for: "ios_push_token_registration_failed", key: "error_code") == 42)
    }
}

private final class DummyMobilePushNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {}

@MainActor
private final class RecordingMobilePushSystemClient: MobilePushSystemClient {
    var authorizationStatus: UNAuthorizationStatus = .notDetermined
    var requestAuthorizationResult = true
    var requestAuthorizationOptions: UNAuthorizationOptions?
    var configureCount = 0
    var clearDelegateCount = 0
    var registerCount = 0
    var unregisterCount = 0
    var delegate: (any UNUserNotificationCenterDelegate)?
    var categories: Set<UNNotificationCategory> = []

    func configure(delegate: any UNUserNotificationCenterDelegate, categories: Set<UNNotificationCategory>) {
        configureCount += 1
        self.delegate = delegate
        self.categories = categories
    }

    func clearDelegate() {
        clearDelegateCount += 1
        delegate = nil
    }

    func currentAuthorizationStatus() async -> UNAuthorizationStatus { authorizationStatus }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestAuthorizationOptions = options
        return requestAuthorizationResult
    }

    func registerForRemoteNotifications() {
        registerCount += 1
    }

    func unregisterForRemoteNotifications() {
        unregisterCount += 1
    }
}

private actor RecordingPushRegistration: PushRegistering {
    struct Snapshot: Equatable {
        var enabledValues: [Bool]
        var deviceTokens: [Data]
        var syncTokenCount: Int
        var unregisterCount: Int
    }

    private var enabledValues: [Bool] = []
    private var deviceTokens: [Data] = []
    private var syncTokenCount = 0
    private var unregisterCount = 0

    var isEnabled: Bool {
        get async { enabledValues.last ?? false }
    }

    func setEnabled(_ enabled: Bool) {
        enabledValues.append(enabled)
    }

    func register(deviceToken: Data) {
        deviceTokens.append(deviceToken)
    }

    func syncTokenIfPossible() {
        syncTokenCount += 1
    }

    func unregisterFromServer(accessToken: String?, refreshToken: String?) {
        unregisterCount += 1
    }

    func unregisterFromServer() {
        unregisterCount += 1
    }

    func snapshot() -> Snapshot {
        Snapshot(
            enabledValues: enabledValues,
            deviceTokens: deviceTokens,
            syncTokenCount: syncTokenCount,
            unregisterCount: unregisterCount
        )
    }
}

private final class RecordingMobileAnalytics: AnalyticsEmitting, @unchecked Sendable {
    private(set) var events: [(String, [String: AnalyticsValue])] = []

    var eventNames: [String] {
        events.map(\.0)
    }

    func capture(_ name: String, _ properties: [String: AnalyticsValue]) {
        events.append((name, properties))
    }

    func identify(userId: String?, alias: String?, properties: [String: AnalyticsValue]) {}

    func setSuperProperties(_ properties: [String: AnalyticsValue]) {}

    func flush() async {}

    func stringValue(for name: String, key: String) -> String? {
        guard case .string(let value)? = events.first(where: { $0.0 == name })?.1[key] else { return nil }
        return value
    }

    func boolValue(for name: String, key: String) -> Bool? {
        guard case .bool(let value)? = events.first(where: { $0.0 == name })?.1[key] else { return nil }
        return value
    }

    func intValue(for name: String, key: String) -> Int? {
        guard case .int(let value)? = events.first(where: { $0.0 == name })?.1[key] else { return nil }
        return value
    }
}
