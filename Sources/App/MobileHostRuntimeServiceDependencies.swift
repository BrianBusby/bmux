import BmuxAuthRuntime
import Foundation

@MainActor
struct MobileHostRuntimeServiceDependencies {
    var isHostEnabled: () -> Bool
    var configureHost: (AuthCoordinator) -> Void
    var syncHostToSettings: () -> MobileHostServiceStatus
    var stopHost: () -> MobileHostServiceStatus
    var hostStatus: () -> MobileHostServiceStatus
    var hostStatusUpdates: () -> AsyncStream<MobileHostServiceStatus>
    var startPresence: (AuthCoordinator) -> MobileHostRuntimeOperationResult
    var syncPresenceToSettings: () -> MobileHostRuntimeOperationResult
    var stopPresence: (_ sendsGoodbye: Bool) -> Void
    var startDeviceRegistry: (AuthCoordinator) -> MobileHostRuntimeOperationResult
    var stopDeviceRegistry: () -> Void
    var startPairedMacBackup: (AuthCoordinator) -> MobileHostRuntimeOperationResult
    var stopPairedMacBackup: () -> Void
    var startRenderObserver: () -> Void
    var stopRenderObserver: () -> Void
    var makeWorkspaceListObserver: (TabManager, TerminalNotificationStore?) -> AnyObject

    static func production() -> MobileHostRuntimeServiceDependencies {
        MobileHostRuntimeServiceDependencies(
            isHostEnabled: { MobileHostService.isListeningEnabled },
            configureHost: { auth in MobileHostService.shared.configure(auth: auth) },
            syncHostToSettings: {
                MobileHostService.shared.syncToSettings()
                return MobileHostService.shared.statusSnapshot()
            },
            stopHost: {
                MobileHostService.shared.stop()
                return MobileHostService.shared.statusSnapshot()
            },
            hostStatus: { MobileHostService.shared.statusSnapshot() },
            hostStatusUpdates: { MobileHostService.shared.statusUpdates() },
            startPresence: { auth in
                PresenceHeartbeatClient.shared.start(auth: auth)
                return .ready
            },
            syncPresenceToSettings: {
                PresenceHeartbeatClient.shared.syncToSettings()
                return .ready
            },
            stopPresence: { sendsGoodbye in
                PresenceHeartbeatClient.shared.stop(sendsGoodbye: sendsGoodbye)
            },
            startDeviceRegistry: { auth in
                DeviceRegistryClient.shared.start(auth: auth)
                return .ready
            },
            stopDeviceRegistry: {
                DeviceRegistryClient.shared.stop()
            },
            startPairedMacBackup: { auth in
                MacPairedMacBackupPublisher.shared.start(auth: auth)
                return .ready
            },
            stopPairedMacBackup: {
                MacPairedMacBackupPublisher.shared.stop()
            },
            startRenderObserver: {
                MobileTerminalRenderObserver.shared.start()
            },
            stopRenderObserver: {
                MobileTerminalRenderObserver.shared.stop()
            },
            makeWorkspaceListObserver: { tabManager, notificationStore in
                MobileWorkspaceListObserver(tabManager: tabManager, notificationStore: notificationStore)
            }
        )
    }
}
