#if os(iOS)
import UserNotifications

@MainActor
public protocol MobilePushSystemClient: AnyObject {
    func configure(
        delegate: any UNUserNotificationCenterDelegate,
        categories: Set<UNNotificationCategory>
    )

    func clearDelegate()

    func currentAuthorizationStatus() async -> UNAuthorizationStatus

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool

    func registerForRemoteNotifications()

    func unregisterForRemoteNotifications()
}
#endif
