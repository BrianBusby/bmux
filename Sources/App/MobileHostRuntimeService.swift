import BMUXMobileCore
import BmuxAuthRuntime
import Foundation

@MainActor
final class MobileHostRuntimeService {
    private let isCapabilityEnabled: Bool
    private let dependencies: MobileHostRuntimeServiceDependencies
    private var settingsObserver: NSObjectProtocol?
    private var hostStatusObservationTask: Task<Void, Never>?
    private var workspaceListObservers: [ObjectIdentifier: AnyObject] = [:]
    private var auth: AuthCoordinator?
    private var didStart = false
    private var didConfigureHost = false
    private var didStartPresence = false
    private var didStartRoutePublication = false
    private var didStartRenderObserver = false
    private var latestPublicationResult: MobileHostRuntimeOperationResult = .ready
    private(set) var lifecycleState: MobileHostRuntimeLifecycleState
    private(set) var latestHostStatus: MobileHostServiceStatus?

    init(
        isCapabilityEnabled: Bool,
        dependencies: MobileHostRuntimeServiceDependencies
    ) {
        self.isCapabilityEnabled = isCapabilityEnabled
        self.dependencies = dependencies
        self.lifecycleState = isCapabilityEnabled
            ? .notStarted
            : .disabled(reason: "disabled by composition")
    }

    func start(
        auth: AuthCoordinator?,
        tabManager: TabManager?,
        notificationStore: TerminalNotificationStore?
    ) {
        guard isCapabilityEnabled else {
            lifecycleState = .disabled(reason: "disabled by composition")
            return
        }

        if let auth {
            self.auth = auth
        }

        guard !didStart else {
            if let tabManager {
                attachWorkspaceListObserver(tabManager: tabManager, notificationStore: notificationStore)
            }
            syncToSettings()
            return
        }

        didStart = true
        lifecycleState = .starting
        installSettingsObserver()
        installHostStatusObservation()
        if let tabManager {
            attachWorkspaceListObserver(tabManager: tabManager, notificationStore: notificationStore)
        }
        syncToSettings()
    }

    func syncToSettings() {
        guard isCapabilityEnabled else {
            lifecycleState = .disabled(reason: "disabled by composition")
            return
        }
        guard didStart else { return }

        let isHostEnabled = dependencies.isHostEnabled()
        if isHostEnabled {
            configureHostIfNeeded()
        }
        let status = dependencies.syncHostToSettings()
        latestHostStatus = status
        if isHostEnabled {
            reconcileEnabledSettingWork(for: status, syncsPresenceSettings: true)
        } else {
            stopHostSideWorkKeepingExplicitPresenceIfNeeded(finalRoutes: status.routes)
            latestPublicationResult = .disabled(reason: "disabled by settings")
        }
        updateLifecycleState(from: status)
    }

    private func reconcileEnabledSettingWork(
        for status: MobileHostServiceStatus,
        syncsPresenceSettings: Bool
    ) {
        guard status.isRunning else {
            stopEnabledSettingWork(
                sendsPresenceGoodbye: false,
                finalRoutes: status.routes,
                resetsHostConfiguration: false
            )
            return
        }

        latestPublicationResult = .ready
        startRenderObserverIfNeeded()
        if let auth {
            configureHostIfNeeded()
            startPresenceIfNeeded(auth: auth)
            startRoutePublicationIfNeeded(auth: auth)
            if syncsPresenceSettings {
                syncPresenceToSettings()
            }
        } else {
            latestPublicationResult = .degraded(reason: "waiting for authentication")
        }
    }

    func attachWorkspaceListObserver(
        tabManager: TabManager,
        notificationStore: TerminalNotificationStore?
    ) {
        guard isCapabilityEnabled, didStart else { return }
        let id = ObjectIdentifier(tabManager)
        guard workspaceListObservers[id] == nil else { return }
        workspaceListObservers[id] = dependencies.makeWorkspaceListObserver(tabManager, notificationStore)
    }

    func removeWorkspaceListObserverIfUnused(
        tabManager: TabManager,
        isStillUsed: Bool
    ) {
        guard !isStillUsed else { return }
        workspaceListObservers.removeValue(forKey: ObjectIdentifier(tabManager))
    }

    func stopForAppTermination() {
        stop(sendsPresenceGoodbye: true)
    }

    func stop() {
        stop(sendsPresenceGoodbye: false)
    }

    var hasActiveLifecycleWork: Bool {
        didStart
            || settingsObserver != nil
            || hostStatusObservationTask != nil
            || !workspaceListObservers.isEmpty
            || didStartPresence
            || didStartRoutePublication
            || didStartRenderObserver
    }

    private func configureHostIfNeeded() {
        if let auth, !didConfigureHost {
            dependencies.configureHost(auth)
            didConfigureHost = true
        }
    }

    private func startRenderObserverIfNeeded() {
        if !didStartRenderObserver {
            dependencies.startRenderObserver()
            didStartRenderObserver = true
        }
    }

    private func startRoutePublicationIfNeeded(auth: AuthCoordinator) {
        if !didStartRoutePublication {
            latestPublicationResult = mergePublicationResults(
                latestPublicationResult,
                startRoutePublication(auth: auth)
            )
            didStartRoutePublication = true
        }
    }

    private func startPresenceIfNeeded(auth: AuthCoordinator) {
        guard dependencies.isPresenceEnabled() else {
            stopPresenceIfNeeded(sendsGoodbye: true)
            latestPublicationResult = mergePublicationResults(
                latestPublicationResult,
                .disabled(reason: "presence disabled by settings")
            )
            return
        }

        if !didStartPresence {
            latestPublicationResult = mergePublicationResults(
                latestPublicationResult,
                dependencies.startPresence(auth)
            )
            didStartPresence = true
        }
    }

    private func syncPresenceToSettings() {
        guard didStartPresence else { return }
        latestPublicationResult = mergePublicationResults(
            latestPublicationResult,
            dependencies.syncPresenceToSettings()
        )
    }

    private func startRoutePublication(auth: AuthCoordinator) -> MobileHostRuntimeOperationResult {
        var result = MobileHostRuntimeOperationResult.ready
        result = mergePublicationResults(result, dependencies.startDeviceRegistry(auth))
        result = mergePublicationResults(result, dependencies.startPairedMacBackup(auth))
        return result
    }

    private func stopEnabledSettingWork(
        sendsPresenceGoodbye: Bool,
        finalRoutes: [CmxAttachRoute],
        resetsHostConfiguration: Bool
    ) {
        if didStartRenderObserver {
            dependencies.stopRenderObserver()
            didStartRenderObserver = false
        }
        if didStartRoutePublication {
            dependencies.stopPairedMacBackup()
            dependencies.stopDeviceRegistry(finalRoutes)
        }
        didStartRoutePublication = false
        stopPresenceIfNeeded(sendsGoodbye: sendsPresenceGoodbye)
        if resetsHostConfiguration {
            didConfigureHost = false
        }
    }

    private func stopHostSideWorkKeepingExplicitPresenceIfNeeded(finalRoutes: [CmxAttachRoute]) {
        if didStartRenderObserver {
            dependencies.stopRenderObserver()
            didStartRenderObserver = false
        }
        if didStartRoutePublication {
            dependencies.stopPairedMacBackup()
            dependencies.stopDeviceRegistry(finalRoutes)
            didStartRoutePublication = false
        }
        if let auth, dependencies.isPresenceEnabled() {
            startPresenceIfNeeded(auth: auth)
            syncPresenceToSettings()
        } else {
            stopPresenceIfNeeded(sendsGoodbye: true)
        }
        didConfigureHost = false
    }

    private func stopPresenceIfNeeded(sendsGoodbye: Bool) {
        guard didStartPresence else { return }
        dependencies.stopPresence(sendsGoodbye)
        didStartPresence = false
    }

    private func installSettingsObserver() {
        guard settingsObserver == nil else { return }
        settingsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults.standard,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.syncToSettings()
            }
        }
    }

    private func installHostStatusObservation() {
        guard hostStatusObservationTask == nil else { return }
        hostStatusObservationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await status in dependencies.hostStatusUpdates() {
                if Task.isCancelled { break }
                latestHostStatus = status
                if dependencies.isHostEnabled() {
                    reconcileEnabledSettingWork(for: status, syncsPresenceSettings: false)
                }
                updateLifecycleState(from: status)
            }
        }
    }

    private func updateLifecycleState(from status: MobileHostServiceStatus) {
        if status.isRunning {
            if status.usesEphemeralFallback {
                lifecycleState = .degraded(reason: "preferred port unavailable; listening on ephemeral fallback")
                return
            }
            switch latestPublicationResult {
            case .ready, .disabled:
                lifecycleState = .ready
            case .degraded(let reason):
                lifecycleState = .degraded(reason: reason)
            case .failed(let reason):
                lifecycleState = .degraded(reason: reason)
            }
            return
        }

        if !dependencies.isHostEnabled() {
            lifecycleState = .disabled(reason: "disabled by settings")
            return
        }

        if let lastError = status.lastErrorDescription?.trimmingCharacters(in: .whitespacesAndNewlines),
           !lastError.isEmpty {
            lifecycleState = .failed(reason: lastError)
            return
        }

        lifecycleState = .starting
    }

    private func stop(sendsPresenceGoodbye: Bool) {
        guard didStart || settingsObserver != nil || hostStatusObservationTask != nil else {
            if isCapabilityEnabled {
                lifecycleState = .stopped
            }
            return
        }

        lifecycleState = .stopping
        settingsObserver.map(NotificationCenter.default.removeObserver)
        settingsObserver = nil
        hostStatusObservationTask?.cancel()
        hostStatusObservationTask = nil
        workspaceListObservers.removeAll()
        latestHostStatus = dependencies.stopHost()
        stopEnabledSettingWork(
            sendsPresenceGoodbye: sendsPresenceGoodbye,
            finalRoutes: latestHostStatus?.routes ?? [],
            resetsHostConfiguration: true
        )
        auth = nil
        didStart = false
        latestPublicationResult = .ready
        lifecycleState = .stopped
    }

    private func mergePublicationResults(
        _ lhs: MobileHostRuntimeOperationResult,
        _ rhs: MobileHostRuntimeOperationResult
    ) -> MobileHostRuntimeOperationResult {
        switch (lhs, rhs) {
        case (.failed, _):
            return lhs
        case (_, .failed):
            return rhs
        case (.degraded, _):
            return lhs
        case (_, .degraded):
            return rhs
        case (.disabled, _):
            return lhs
        case (_, .disabled):
            return rhs
        case (.ready, .ready):
            return .ready
        }
    }
}
