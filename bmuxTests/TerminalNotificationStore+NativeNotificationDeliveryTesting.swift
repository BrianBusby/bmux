import UserNotifications

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

extension TerminalNotificationStore {
    func configureNotificationAuthorizationHandlerForTesting(
        _ handler: @escaping NativeNotificationDeliveryHooks.AuthorizationHandler
    ) {
        configureNativeNotificationDeliveryHooksForTesting {
            $0.authorizationHandlerForTesting = handler
        }
    }

    func resetNotificationAuthorizationHandlerForTesting() {
        configureNativeNotificationDeliveryHooksForTesting {
            $0.authorizationHandlerForTesting = nil
        }
    }

    func configureUserNotificationSchedulerForTesting(
        _ scheduler: @escaping NativeNotificationDeliveryHooks.Scheduler
    ) {
        configureNativeNotificationDeliveryHooksForTesting {
            $0.scheduler = scheduler
        }
    }

    func resetUserNotificationSchedulerForTesting() {
        configureNativeNotificationDeliveryHooksForTesting {
            $0.scheduler = NativeNotificationDeliveryHooks().scheduler
        }
    }

    func configureNotificationCommandRunnerForTesting(
        _ runner: @escaping NativeNotificationDeliveryHooks.CommandRunner
    ) {
        configureNativeNotificationDeliveryHooksForTesting {
            $0.commandRunner = runner
        }
    }

    func resetNotificationCommandRunnerForTesting() {
        configureNativeNotificationDeliveryHooksForTesting {
            $0.commandRunner = NativeNotificationDeliveryHooks().commandRunner
        }
    }
}
