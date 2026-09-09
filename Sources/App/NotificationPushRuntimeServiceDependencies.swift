import BmuxAuthRuntime
import BmuxNotifications
import Foundation
import UserNotifications

@MainActor
struct NotificationPushRuntimeServiceDependencies {
    var validateRequiredRuntime: () -> NotificationPushRuntimeOperationResult
    var makeDeliveryCoordinator: (
        any NotificationDeliveryTerminalNavigating,
        any NotificationFeedReplying,
        any NotificationApplicationActivating,
        NotificationDeliveryActionTitles
    ) -> any NotificationPushDeliveryCoordinating
    var configurePhonePushClient: (AuthCoordinator) -> Void
    var stopPhonePushClient: () -> Void
    var phonePushForwarding: any TerminalPhonePushForwarding
    var configureStorePhonePushForwarding: (TerminalNotificationStore, any TerminalPhonePushForwarding) -> Void
    var resetStorePhonePushForwarding: (TerminalNotificationStore) -> Void
    var handleApplicationDidBecomeActive: (TerminalNotificationStore) -> Void

    static func production() -> NotificationPushRuntimeServiceDependencies {
        NotificationPushRuntimeServiceDependencies(
            validateRequiredRuntime: { .ready },
            makeDeliveryCoordinator: { terminalNavigation, feedReplying, applicationActivation, actionTitles in
                NotificationDeliveryCoordinator(
                    center: UNUserNotificationCenter.current(),
                    terminalNavigation: terminalNavigation,
                    feedReplying: feedReplying,
                    applicationActivation: applicationActivation,
                    terminalIdentifiers: TerminalNotificationDeliveryIdentifiers(
                        categoryIdentifier: TerminalNotificationStore.categoryIdentifier,
                        showActionIdentifier: TerminalNotificationStore.actionShowIdentifier
                    ),
                    actionTitles: actionTitles
                )
            },
            configurePhonePushClient: { auth in
                PhonePushClient.shared.configure(auth: auth)
            },
            stopPhonePushClient: {
                PhonePushClient.shared.stop()
            },
            phonePushForwarding: PhonePushClient.shared,
            configureStorePhonePushForwarding: { store, forwarding in
                store.configurePhonePushForwarding(forwarding)
            },
            resetStorePhonePushForwarding: { store in
                store.resetPhonePushForwarding()
            },
            handleApplicationDidBecomeActive: { store in
                store.handleApplicationDidBecomeActive()
            }
        )
    }
}
