import BmuxAuthRuntime
import BmuxNotifications
import Foundation
import UserNotifications

@MainActor
final class NotificationPushRuntimeService {
    private let isCapabilityEnabled: Bool
    private let dependencies: NotificationPushRuntimeServiceDependencies
    private var didAttemptStart = false
    private var didStart = false
    private var didConfigurePhonePush = false
    private var notificationStore: TerminalNotificationStore?
    private var deliveryCoordinator: (any NotificationPushDeliveryCoordinating)?
    private var latestStartupResult: NotificationPushRuntimeOperationResult = .ready
    private(set) var lifecycleState: NotificationPushRuntimeLifecycleState

    init(
        isCapabilityEnabled: Bool,
        dependencies: NotificationPushRuntimeServiceDependencies
    ) {
        self.isCapabilityEnabled = isCapabilityEnabled
        self.dependencies = dependencies
        self.lifecycleState = isCapabilityEnabled
            ? .notStarted
            : .disabled(reason: "disabled by composition")
    }

    @discardableResult
    func start(
        auth: AuthCoordinator,
        notificationStore: TerminalNotificationStore,
        userNotificationDelegate: any UNUserNotificationCenterDelegate,
        terminalNavigation: any NotificationDeliveryTerminalNavigating,
        feedReplying: any NotificationFeedReplying,
        applicationActivation: any NotificationApplicationActivating,
        actionTitles: NotificationDeliveryActionTitles
    ) -> Bool {
        guard isCapabilityEnabled else {
            lifecycleState = .disabled(reason: "disabled by composition")
            return false
        }

        let shouldCountStart = !didAttemptStart
        guard shouldCountStart else { return false }

        didAttemptStart = true
        lifecycleState = .starting
        latestStartupResult = dependencies.validateRequiredRuntime()
        switch latestStartupResult {
        case .failed(let reason):
            lifecycleState = .failed(reason: reason)
            return shouldCountStart
        case .disabled(let reason):
            lifecycleState = .disabled(reason: reason)
            return shouldCountStart
        case .ready, .degraded:
            break
        }

        let coordinator = dependencies.makeDeliveryCoordinator(
            terminalNavigation,
            feedReplying,
            applicationActivation,
            actionTitles
        )
        coordinator.configureUserNotifications(delegate: userNotificationDelegate)
        dependencies.configurePhonePushClient(auth)
        dependencies.configureStorePhonePushForwarding(
            notificationStore,
            dependencies.phonePushForwarding
        )
        self.notificationStore = notificationStore
        self.deliveryCoordinator = coordinator
        didConfigurePhonePush = true
        didStart = true
        updateLifecycleState(from: latestStartupResult)
        return shouldCountStart
    }

    func handleApplicationDidBecomeActive() {
        guard canRouteEvents, let notificationStore else { return }
        dependencies.handleApplicationDidBecomeActive(notificationStore)
    }

    func handleNotificationResponse(_ response: UNNotificationResponse) {
        guard canRouteEvents, let deliveryCoordinator else { return }
        deliveryCoordinator.handleNotificationResponse(response)
    }

    func presentationOptions(for notification: UNNotification) -> UNNotificationPresentationOptions {
        guard canRouteEvents, let deliveryCoordinator else { return [] }
        return deliveryCoordinator.presentationOptions(for: notification)
    }

    func stop() {
        guard hasActiveLifecycleWork || didAttemptStart else {
            if isCapabilityEnabled {
                lifecycleState = .stopped
            }
            return
        }

        lifecycleState = .stopping
        if let notificationStore {
            dependencies.resetStorePhonePushForwarding(notificationStore)
        }
        if didConfigurePhonePush {
            dependencies.stopPhonePushClient()
        }
        notificationStore = nil
        deliveryCoordinator = nil
        didConfigurePhonePush = false
        didStart = false
        didAttemptStart = false
        latestStartupResult = .ready
        lifecycleState = .stopped
    }

    var hasActiveLifecycleWork: Bool {
        didStart
            || didConfigurePhonePush
            || notificationStore != nil
            || deliveryCoordinator != nil
    }

    private var canRouteEvents: Bool {
        isCapabilityEnabled && lifecycleState.canRouteCallbacks
    }

    private func updateLifecycleState(from result: NotificationPushRuntimeOperationResult) {
        switch result {
        case .ready:
            lifecycleState = .ready
        case .degraded(let reason):
            lifecycleState = .degraded(reason: reason)
        case .failed(let reason):
            lifecycleState = .failed(reason: reason)
        case .disabled(let reason):
            lifecycleState = .disabled(reason: reason)
        }
    }
}
