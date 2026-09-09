import AppKit
import Foundation

@MainActor
final class MenuBarPresentationRuntimeService {
    private let isCapabilityEnabled: Bool
    private let dependencies: MenuBarPresentationRuntimeServiceDependencies
    private var uiActions: MenuBarPresentationRuntimeUIActions?
    private var preferencesObserver: NSObjectProtocol?
    private var persistentMenuBarExtraController: (any MenuBarPresentationMenuBarExtraControlling)?
    private var transientGlobalSearchMenuBarExtraController: (any MenuBarPresentationMenuBarExtraControlling)?
    private var didAttemptStart = false
    private var didStart = false
    private var didInstallMenuRefreshHandler = false
    private var latestStartupResult: MenuBarPresentationRuntimeOperationResult = .ready
    private var lastPreferenceSnapshot: MenuBarPresentationRuntimePreferenceSnapshot?
    private(set) var lifecycleState: MenuBarPresentationRuntimeLifecycleState

    init(
        isCapabilityEnabled: Bool,
        dependencies: MenuBarPresentationRuntimeServiceDependencies
    ) {
        self.isCapabilityEnabled = isCapabilityEnabled
        self.dependencies = dependencies
        self.lifecycleState = isCapabilityEnabled
            ? .notStarted
            : .disabled(reason: "disabled by composition")
    }

    @discardableResult
    func start(actions: MenuBarPresentationRuntimeUIActions) -> Bool {
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

        self.uiActions = actions
        didStart = true
        dependencies.normalizeLegacyStoredPreference()
        installPreferencesObserver()
        updateLifecycleState(from: mergeStartupResults(
            latestStartupResult,
            reconcileCurrentPreferences()
        ))
        return shouldCountStart
    }

    func stop() {
        guard hasActiveLifecycleWork || didAttemptStart else {
            if isCapabilityEnabled {
                lifecycleState = .stopped
            }
            return
        }

        lifecycleState = .stopping
        removePreferencesObserver()
        removePersistentMenuBarExtra()
        removeTransientGlobalSearchMenuBarExtra()
        uiActions = nil
        didStart = false
        didAttemptStart = false
        latestStartupResult = .ready
        lastPreferenceSnapshot = nil
        lifecycleState = .stopped
    }

    var hasActiveLifecycleWork: Bool {
        didStart
            || preferencesObserver != nil
            || persistentMenuBarExtraController != nil
            || transientGlobalSearchMenuBarExtraController != nil
            || didInstallMenuRefreshHandler
    }

    @discardableResult
    func setMenuBarOnly(_ enabled: Bool) -> Bool {
        guard canReconcilePreferences else { return false }
        guard dependencies.setMenuBarOnlyPreference(enabled) else {
            lifecycleState = .degraded(reason: "menu-bar-only preference write failed")
            return false
        }
        updateLifecycleState(from: mergeStartupResults(
            latestStartupResult,
            reconcileCurrentPreferences()
        ))
        return true
    }

    @discardableResult
    func toggleGlobalSearchPalette() -> Bool {
        guard canUseMenuBarExtraControllers, let uiActions else { return false }
        if persistentMenuBarExtraController == nil,
           dependencies.currentPreferenceSnapshot().shouldInstallMenuBarExtra {
            updateLifecycleState(from: mergeStartupResults(
                latestStartupResult,
                reconcileCurrentPreferences()
            ))
        }
        if let persistentMenuBarExtraController,
           persistentMenuBarExtraController.toggleGlobalSearchPalette(onDismiss: nil) {
            return true
        }
        return toggleTransientGlobalSearchMenuBarExtra(uiActions: uiActions)
    }

    func refreshMenuBarExtraForDebugControls() {
        guard canUseMenuBarExtraControllers else { return }
        persistentMenuBarExtraController?.refreshForDebugControls()
    }

    private var canReconcilePreferences: Bool {
        isCapabilityEnabled && didStart && lifecycleState.isUsable
    }

    private var canUseMenuBarExtraControllers: Bool {
        isCapabilityEnabled && didStart && lifecycleState.isUsable
    }

    private func installPreferencesObserver() {
        guard preferencesObserver == nil else { return }
        preferencesObserver = dependencies.makePreferencesObserver { [weak self] in
            guard let self, self.canReconcilePreferences else { return }
            self.updateLifecycleState(from: self.mergeStartupResults(
                self.latestStartupResult,
                self.reconcileCurrentPreferences()
            ))
        }
    }

    private func removePreferencesObserver() {
        if let preferencesObserver {
            dependencies.removePreferencesObserver(preferencesObserver)
            self.preferencesObserver = nil
        }
    }

    private func reconcileCurrentPreferences() -> MenuBarPresentationRuntimeOperationResult {
        guard isCapabilityEnabled, didStart else {
            return .disabled(reason: "runtime not started")
        }
        dependencies.normalizeLegacyStoredPreference()
        let snapshot = dependencies.currentPreferenceSnapshot()
        let activationResult = reconcileActivationPolicy(snapshot.activationPolicy)
        reconcileMenuBarExtraVisibility(snapshot)
        lastPreferenceSnapshot = snapshot
        return activationResult
    }

    private func reconcileActivationPolicy(
        _ targetPolicy: NSApplication.ActivationPolicy
    ) -> MenuBarPresentationRuntimeOperationResult {
        guard dependencies.currentActivationPolicy() != targetPolicy else { return .ready }
        if dependencies.setActivationPolicy(targetPolicy) {
            return .ready
        }
        return .degraded(reason: "activation policy update failed")
    }

    private func reconcileMenuBarExtraVisibility(
        _ snapshot: MenuBarPresentationRuntimePreferenceSnapshot
    ) {
        guard snapshot.shouldInstallMenuBarExtra else {
            let previouslyInstalled = lastPreferenceSnapshot?.shouldInstallMenuBarExtra == true
            let hadPersistentController = persistentMenuBarExtraController != nil
            removePersistentMenuBarExtra()
            if previouslyInstalled || hadPersistentController {
                removeTransientGlobalSearchMenuBarExtra()
            }
            return
        }
        installPersistentMenuBarExtraIfNeeded()
    }

    private func installPersistentMenuBarExtraIfNeeded() {
        guard persistentMenuBarExtraController == nil, let uiActions else { return }
        removeTransientGlobalSearchMenuBarExtra()
        persistentMenuBarExtraController = uiActions.makeMenuBarExtraController()
        installMenuRefreshHandlerIfNeeded()
    }

    private func removePersistentMenuBarExtra() {
        persistentMenuBarExtraController?.removeFromMenuBar()
        persistentMenuBarExtraController = nil
        clearMenuRefreshHandlerIfNeeded()
    }

    private func removeTransientGlobalSearchMenuBarExtra() {
        transientGlobalSearchMenuBarExtraController?.removeFromMenuBar()
        transientGlobalSearchMenuBarExtraController = nil
    }

    private func toggleTransientGlobalSearchMenuBarExtra(
        uiActions: MenuBarPresentationRuntimeUIActions
    ) -> Bool {
        if let transientGlobalSearchMenuBarExtraController {
            if transientGlobalSearchMenuBarExtraController.toggleGlobalSearchPalette(
                onDismiss: transientGlobalSearchDismissalHandler(for: transientGlobalSearchMenuBarExtraController)
            ) {
                return true
            }
            transientGlobalSearchMenuBarExtraController.removeFromMenuBar()
            self.transientGlobalSearchMenuBarExtraController = nil
        }

        let controller = uiActions.makeMenuBarExtraController()
        transientGlobalSearchMenuBarExtraController = controller
        guard controller.toggleGlobalSearchPalette(
            onDismiss: transientGlobalSearchDismissalHandler(for: controller)
        ) else {
            controller.removeFromMenuBar()
            if isCurrentTransientGlobalSearchController(controller) {
                transientGlobalSearchMenuBarExtraController = nil
            }
            return false
        }
        return true
    }

    private func transientGlobalSearchDismissalHandler(
        for controller: any MenuBarPresentationMenuBarExtraControlling
    ) -> () -> Void {
        { [weak self, weak controller] in
            guard let self,
                  let controller,
                  self.isCurrentTransientGlobalSearchController(controller) else { return }
            controller.removeFromMenuBar()
            self.transientGlobalSearchMenuBarExtraController = nil
        }
    }

    private func isCurrentTransientGlobalSearchController(
        _ controller: any MenuBarPresentationMenuBarExtraControlling
    ) -> Bool {
        guard let transientGlobalSearchMenuBarExtraController else { return false }
        return (transientGlobalSearchMenuBarExtraController as AnyObject) === (controller as AnyObject)
    }

    private func installMenuRefreshHandlerIfNeeded() {
        guard !didInstallMenuRefreshHandler else { return }
        dependencies.setMenuRefreshHandler { [weak self] in
            self?.persistentMenuBarExtraController?.refreshForDebugControls()
        }
        didInstallMenuRefreshHandler = true
    }

    private func clearMenuRefreshHandlerIfNeeded() {
        guard didInstallMenuRefreshHandler else { return }
        dependencies.setMenuRefreshHandler(nil)
        didInstallMenuRefreshHandler = false
    }

    private func mergeStartupResults(
        _ lhs: MenuBarPresentationRuntimeOperationResult,
        _ rhs: MenuBarPresentationRuntimeOperationResult
    ) -> MenuBarPresentationRuntimeOperationResult {
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

    private func updateLifecycleState(from result: MenuBarPresentationRuntimeOperationResult) {
        switch result {
        case .ready:
            lifecycleState = .ready
        case .disabled(let reason):
            lifecycleState = .disabled(reason: reason)
        case .degraded(let reason):
            lifecycleState = .degraded(reason: reason)
        case .failed(let reason):
            lifecycleState = .failed(reason: reason)
        }
    }
}
