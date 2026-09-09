#if os(iOS)
import UIKit
import UserNotifications

@MainActor
public final class SystemMobilePushSystemClient: MobilePushSystemClient {
    public init() {}

    public func configure(
        delegate: any UNUserNotificationCenterDelegate,
        categories: Set<UNNotificationCategory>
    ) {
        let center = UNUserNotificationCenter.current()
        center.delegate = delegate
        center.setNotificationCategories(categories)
    }

    public func clearDelegate() {
        UNUserNotificationCenter.current().delegate = nil
    }

    public func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    public func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: options)
    }

    public func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    public func unregisterForRemoteNotifications() {
        UIApplication.shared.unregisterForRemoteNotifications()
    }
}
#endif
