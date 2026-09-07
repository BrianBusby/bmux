import AppKit
import Foundation

@MainActor
final class BrowserDevToolsRuntimeService {
    private let isCapabilityEnabled: Bool
    private let dependencies: BrowserDevToolsRuntimeServiceDependencies
    private var observerTokens: [NSObjectProtocol] = []
    private var didStart = false
    private var didStartSystemProxyObservation = false
    private var didCloseInspectorsForShutdown = false
    private var didDrainBrowserResourcesForShutdown = false
    private(set) var lifecycleState: BrowserDevToolsRuntimeLifecycleState
    private(set) var focusedAddressBarPanelId: UUID?

    init(
        isCapabilityEnabled: Bool,
        dependencies: BrowserDevToolsRuntimeServiceDependencies
    ) {
        self.isCapabilityEnabled = isCapabilityEnabled
        self.dependencies = dependencies
        self.lifecycleState = isCapabilityEnabled
            ? .notStarted
            : .disabled(reason: "disabled by composition")
    }

    func start(handlers: BrowserDevToolsRuntimeEventHandlers = .noop) {
        guard isCapabilityEnabled else {
            lifecycleState = .disabled(reason: "disabled by composition")
            return
        }
        guard !didStart else { return }

        lifecycleState = .starting

        let requiredRuntimeResult = dependencies.validateRequiredRuntime()
        switch requiredRuntimeResult {
        case .failed(let reason):
            lifecycleState = .failed(reason: reason)
            return
        case .disabled(let reason):
            lifecycleState = .disabled(reason: reason)
            return
        case .ready, .degraded:
            break
        }

        didStart = true
        didCloseInspectorsForShutdown = false
        didDrainBrowserResourcesForShutdown = false

        let proxyObservationResult = dependencies.startSystemProxyObservation()
        didStartSystemProxyObservation = true
        installBrowserFocusObservers(handlers: handlers)
        updateLifecycleState(from: mergeStartupResults(
            requiredRuntimeResult,
            nonFatalResult(proxyObservationResult)
        ))
    }

    func stopForAppTermination() {
        stop()
    }

    func stop() {
        guard hasActiveLifecycleWork else {
            if isCapabilityEnabled {
                lifecycleState = .stopped
            }
            return
        }

        lifecycleState = .stopping
        closeAllWebInspectorsForShutdownIfNeeded()
        drainBrowserResourcesForShutdownIfNeeded()
        removeBrowserFocusObservers()
        if didStartSystemProxyObservation {
            dependencies.stopSystemProxyObservation()
        }
        didStartSystemProxyObservation = false
        didStart = false
        focusedAddressBarPanelId = nil
        lifecycleState = .stopped
    }

    var hasActiveLifecycleWork: Bool {
        didStart
            || didStartSystemProxyObservation
            || !observerTokens.isEmpty
    }

    func setFocusedAddressBarPanelId(_ panelId: UUID?) {
        focusedAddressBarPanelId = panelId
    }

    @discardableResult
    func clearFocusedAddressBarPanelId(_ panelId: UUID) -> Bool {
        guard focusedAddressBarPanelId == panelId else { return false }
        focusedAddressBarPanelId = nil
        return true
    }

    @discardableResult
    func closeAllWebInspectorsForAppTeardown() -> Int {
        guard isCapabilityEnabled else { return 0 }
        didCloseInspectorsForShutdown = true
        return dependencies.closeAllWebInspectors()
    }

    @discardableResult
    func closeWebInspectors(in window: NSWindow) -> Int {
        guard isCapabilityEnabled else { return 0 }
        return dependencies.closeWebInspectorsInWindow(window)
    }

    private func installBrowserFocusObservers(handlers: BrowserDevToolsRuntimeEventHandlers) {
        guard observerTokens.isEmpty else { return }
        observerTokens.append(dependencies.makeAddressBarFocusObserver { [weak self] panelId in
            guard let self else { return }
            focusedAddressBarPanelId = panelId
            handlers.addressBarFocused(panelId)
        })
        observerTokens.append(dependencies.makeAddressBarBlurObserver { [weak self] panelId in
            guard let self else { return }
            let wasTracked = focusedAddressBarPanelId == panelId
            if wasTracked {
                focusedAddressBarPanelId = nil
            }
            handlers.addressBarBlurred(panelId, wasTracked)
        })
        observerTokens.append(dependencies.makeWebViewFirstResponderObserver { notification in
            handlers.webViewBecameFirstResponder(notification)
        })
    }

    private func removeBrowserFocusObservers() {
        observerTokens.forEach(dependencies.removeObserver)
        observerTokens.removeAll()
    }

    private func closeAllWebInspectorsForShutdownIfNeeded() {
        guard !didCloseInspectorsForShutdown else { return }
        _ = closeAllWebInspectorsForAppTeardown()
    }

    private func drainBrowserResourcesForShutdownIfNeeded() {
        guard !didDrainBrowserResourcesForShutdown else { return }
        dependencies.discardPrewarmedWebViews()
        dependencies.flushBrowserProfileSaves()
        didDrainBrowserResourcesForShutdown = true
    }

    private func nonFatalResult(
        _ result: BrowserDevToolsRuntimeOperationResult
    ) -> BrowserDevToolsRuntimeOperationResult {
        switch result {
        case .failed(let reason):
            return .degraded(reason: reason)
        case .ready, .disabled, .degraded:
            return result
        }
    }

    private func mergeStartupResults(
        _ lhs: BrowserDevToolsRuntimeOperationResult,
        _ rhs: BrowserDevToolsRuntimeOperationResult
    ) -> BrowserDevToolsRuntimeOperationResult {
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

    private func updateLifecycleState(from result: BrowserDevToolsRuntimeOperationResult) {
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
