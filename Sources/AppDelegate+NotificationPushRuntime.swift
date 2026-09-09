import BmuxNotifications
import Foundation
import UserNotifications

extension AppDelegate {
    func startNotificationPushRuntime(
        auth: MacAuthComposition,
        notificationStore: TerminalNotificationStore
    ) {
        guard let appRuntimeServices else { return }
        appRuntimeServices.startNotificationPushLifecycle(
            auth: auth.coordinator,
            notificationStore: notificationStore,
            userNotificationDelegate: self,
            terminalNavigation: notificationNavigation,
            feedReplying: notificationDeliverySeams,
            applicationActivation: notificationDeliverySeams,
            actionTitles: notificationDeliveryActionTitles
        )
    }
}
