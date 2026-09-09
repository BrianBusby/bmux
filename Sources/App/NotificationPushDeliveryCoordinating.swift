import BmuxNotifications
import Foundation
import UserNotifications

@MainActor
protocol NotificationPushDeliveryCoordinating: AnyObject {
    func configureUserNotifications(delegate: any UNUserNotificationCenterDelegate)

    func handleNotificationResponse(_ response: UNNotificationResponse)

    func presentationOptions(for notification: UNNotification) -> UNNotificationPresentationOptions
}

extension NotificationDeliveryCoordinator: NotificationPushDeliveryCoordinating {}
