import AppKit
import Foundation
import os

nonisolated struct AgentChatActionInFlightGate {
    private struct State {
        var isRunning = false
    }

    private nonisolated static let lock = OSAllocatedUnfairLock(initialState: State())

    static func begin() -> Bool {
        lock.withLock { state in
            guard !state.isRunning else { return false }
            state.isRunning = true
            return true
        }
    }

    static func end() {
        lock.withLock { state in
            state.isRunning = false
        }
    }
}

@MainActor
private enum AgentChatProjectionSidecarRecoveryState {
    static var task: Task<Void, Never>?
    static var cooldownUntil: Date?
    static var url: URL?
}

extension AppDelegate {

    func startAgentChatExecutionTelemetryProjection(
        agentChat: BmuxAgentChatConfiguration,
        globalConfigPath: String? = nil
    ) {
        guard !Self.detectRunningUnderXCTest(ProcessInfo.processInfo.environment) else { return }
        workProvenanceRuntime?.startExecutionTelemetryProjection(
            agentChatURL: agentChat.url,
            sidecarStatusHandler: { [weak self] status in
                self?.handleAgentChatProjectionSidecarStatus(
                    status,
                    agentChat: agentChat,
                    globalConfigPath: globalConfigPath
                )
            }
        )
    }

    func startAgentChatExecutionTelemetryProjection(agentChatURL: URL) {
        startAgentChatExecutionTelemetryProjection(
            agentChat: BmuxAgentChatConfiguration(
                url: agentChatURL,
                startCommand: nil,
                source: .defaults
            )
        )
    }

    func startAgentChatExecutionTelemetryProjectionFromLoadedConfigStore() {
        guard let bmuxConfigStore = mainWindowContexts.values.compactMap(\.bmuxConfigStore).first else {
            return
        }
        startAgentChatExecutionTelemetryProjection(
            agentChat: bmuxConfigStore.agentChat,
            globalConfigPath: bmuxConfigStore.globalConfigPath
        )
    }

    func cancelAgentChatProjectionSidecarRecovery() {
        AgentChatProjectionSidecarRecoveryState.task?.cancel()
        AgentChatProjectionSidecarRecoveryState.task = nil
    }

    @discardableResult
    func performConfiguredNewAgentChatAction(
        context: MainWindowContext,
        preferredWindow: NSWindow?,
        onExecuted: (() -> Void)?
    ) -> Bool {
        let bmuxConfigStore = context.bmuxConfigStore
        return performNewAgentChatAction(
            tabManager: context.tabManager,
            agentChat: bmuxConfigStore?.agentChat ?? .default,
            globalConfigPath: bmuxConfigStore?.globalConfigPath,
            preferredWindow: resolvedWindow(for: context) ?? preferredWindow,
            onExecuted: onExecuted
        )
    }

    @discardableResult
    func executeConfiguredBmuxAction(
        id actionID: String,
        tabManager: TabManager,
        preferredWindow: NSWindow? = nil
    ) -> Bool {
        guard let context = mainWindowContext(for: tabManager),
              let action = context.bmuxConfigStore?.resolvedAction(id: actionID) else {
            return false
        }
        return executeConfiguredBmuxAction(
            action,
            context: context,
            preferredWindow: preferredWindow
        )
    }

    @discardableResult
    func performNewAgentChatAction(
        tabManager: TabManager,
        agentChat: BmuxAgentChatConfiguration,
        globalConfigPath: String?,
        preferredWindow: NSWindow?,
        onExecuted: (() -> Void)? = nil
    ) -> Bool {
        guard BrowserAvailabilitySettings.isEnabled() else {
            NSSound.beep()
            return false
        }
        guard AgentChatActionInFlightGate.begin() else {
            NSSound.beep()
            return false
        }
        Task { @MainActor [weak self, weak tabManager] in
            defer { AgentChatActionInFlightGate.end() }
            guard let self else { return }
            self.startAgentChatExecutionTelemetryProjection(
                agentChat: agentChat,
                globalConfigPath: globalConfigPath
            )
            let isReachable = await self.ensureAgentChatServerAvailable(
                agentChat,
                globalConfigPath: globalConfigPath,
                preferredWindow: preferredWindow
            )
            guard let tabManager else { return }
            guard let workspace = self.openAgentChatWorkspace(
                tabManager: tabManager,
                agentChat: agentChat
            ) else {
                NSSound.beep()
                return
            }
            if !isReachable {
                self.postAgentChatServerUnavailableNotification(
                    workspace: workspace,
                    agentChat: agentChat
                )
            }
            onExecuted?()
        }
        return true
    }

    @discardableResult
    private func openAgentChatWorkspace(
        tabManager: TabManager,
        agentChat: BmuxAgentChatConfiguration
    ) -> Workspace? {
        let beforeIds = Set(tabManager.tabs.map(\.id))
        let workspaceName = String(
            localized: "workspace.agentChat.defaultTitle",
            defaultValue: "Agent Chat"
        )
        let workspaceDefinition = BmuxWorkspaceDefinition(
            name: workspaceName,
            layout: .pane(BmuxPaneDefinition(surfaces: [
                BmuxSurfaceDefinition(
                    type: .browser,
                    name: workspaceName,
                    command: nil,
                    cwd: nil,
                    env: nil,
                    url: agentChat.url.absoluteString,
                    focus: true
                ),
            ]))
        )
        let command = BmuxCommandDefinition(
            name: workspaceName,
            workspace: workspaceDefinition
        )
        let baseCwd = tabManager.selectedWorkspace?.currentDirectory
            ?? FileManager.default.homeDirectoryForCurrentUser.path
        guard BmuxConfigExecutor.executeWorkspaceCommand(
            command: command,
            workspace: workspaceDefinition,
            tabManager: tabManager,
            baseCwd: baseCwd
        ) else {
            return nil
        }
        return tabManager.tabs.first { !beforeIds.contains($0.id) } ?? tabManager.selectedWorkspace
    }

    private func postAgentChatServerUnavailableNotification(
        workspace: Workspace,
        agentChat: BmuxAgentChatConfiguration
    ) {
        let body: String
        if let startCommand = agentChat.startCommand {
            let format = String(
                localized: "notification.agentChat.serverUnavailable.bodyWithCommand",
                defaultValue: "bmux couldn't reach %@. Start it with: %@"
            )
            body = String(format: format, agentChat.url.absoluteString, startCommand)
        } else {
            let format = String(
                localized: "notification.agentChat.serverUnavailable.bodyDefault",
                defaultValue: "bmux couldn't reach %@. Start the server with bmux-chat or configure agentChat.startCommand in bmux.json."
            )
            body = String(format: format, agentChat.url.absoluteString)
        }
        TerminalNotificationStore.shared.addNotification(
            tabId: workspace.id,
            surfaceId: workspace.focusedPanelId,
            title: String(
                localized: "notification.agentChat.serverUnavailable.title",
                defaultValue: "Agent chat server isn't running"
            ),
            subtitle: String(
                localized: "notification.agentChat.serverUnavailable.subtitle",
                defaultValue: "Opened Agent Chat"
            ),
            body: body,
            cooldownKey: "agent-chat-server-unavailable.\(agentChat.url.absoluteString)",
            cooldownInterval: 30
        )
    }

    func handleAgentChatProjectionSidecarStatus(
        _ status: ExecutionTelemetryProjectionSidecarStatus,
        agentChat: BmuxAgentChatConfiguration,
        globalConfigPath: String?
    ) {
        switch status {
        case .available(let agentChatURL):
            guard agentChatURL == agentChat.url else { return }
            AgentChatProjectionSidecarRecoveryState.task?.cancel()
            AgentChatProjectionSidecarRecoveryState.task = nil
            AgentChatProjectionSidecarRecoveryState.cooldownUntil = nil
            AgentChatProjectionSidecarRecoveryState.url = agentChatURL
        case .unavailable(let agentChatURL, let errorDescription):
            guard agentChatURL == agentChat.url else { return }
            recoverUnavailableAgentChatProjectionSidecar(
                agentChat: agentChat,
                globalConfigPath: globalConfigPath,
                errorDescription: errorDescription
            )
        }
    }

    private func recoverUnavailableAgentChatProjectionSidecar(
        agentChat: BmuxAgentChatConfiguration,
        globalConfigPath: String?,
        errorDescription: String
    ) {
        if AgentChatProjectionSidecarRecoveryState.url != agentChat.url {
            AgentChatProjectionSidecarRecoveryState.task?.cancel()
            AgentChatProjectionSidecarRecoveryState.task = nil
            AgentChatProjectionSidecarRecoveryState.cooldownUntil = nil
            AgentChatProjectionSidecarRecoveryState.url = agentChat.url
        }
        guard let startCommand = agentChat.startCommand else {
            postAgentChatProjectionServerUnavailableNotification(
                agentChat: agentChat,
                startCommand: nil,
                errorDescription: errorDescription
            )
            return
        }
        if let cooldownUntil = AgentChatProjectionSidecarRecoveryState.cooldownUntil,
           Date() < cooldownUntil {
            return
        }
        guard AgentChatProjectionSidecarRecoveryState.task == nil else { return }
        AgentChatProjectionSidecarRecoveryState.cooldownUntil = Date().addingTimeInterval(60)
        AgentChatProjectionSidecarRecoveryState.task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { AgentChatProjectionSidecarRecoveryState.task = nil }
            let isReachable = await self.ensureAgentChatServerAvailable(
                agentChat,
                globalConfigPath: globalConfigPath,
                preferredWindow: NSApp.keyWindow ?? NSApp.mainWindow
            )
            if isReachable {
                AgentChatProjectionSidecarRecoveryState.cooldownUntil = nil
            } else {
                self.postAgentChatProjectionServerUnavailableNotification(
                    agentChat: agentChat,
                    startCommand: startCommand,
                    errorDescription: errorDescription
                )
            }
        }
    }

    private func postAgentChatProjectionServerUnavailableNotification(
        agentChat: BmuxAgentChatConfiguration,
        startCommand: String?,
        errorDescription: String
    ) {
#if DEBUG
        bmuxDebugLog("agentChat.provenanceProjection.unavailable url=\(agentChat.url.absoluteString) error=\(errorDescription)")
#endif
        guard let workspace = tabManager?.selectedWorkspace
            ?? mainWindowContexts.values.compactMap({ $0.tabManager.selectedWorkspace }).first else {
            return
        }
        let body: String
        if let startCommand {
            let format = String(
                localized: "notification.agentChat.provenanceServerUnavailable.bodyWithCommand",
                defaultValue: "bmux couldn't reach %@ while syncing provenance, and the configured start command did not make it available: %@"
            )
            body = String(format: format, agentChat.url.absoluteString, startCommand)
        } else {
            let format = String(
                localized: "notification.agentChat.provenanceServerUnavailable.bodyDefault",
                defaultValue: "bmux couldn't reach %@ while syncing provenance. Start the server with bmux-chat or configure agentChat.startCommand in bmux.json."
            )
            body = String(format: format, agentChat.url.absoluteString)
        }
        TerminalNotificationStore.shared.addNotification(
            tabId: workspace.id,
            surfaceId: workspace.focusedPanelId,
            title: String(
                localized: "notification.agentChat.provenanceServerUnavailable.title",
                defaultValue: "Agent Chat server isn't running"
            ),
            subtitle: String(
                localized: "notification.agentChat.provenanceServerUnavailable.subtitle",
                defaultValue: "Provenance sync"
            ),
            body: body,
            cooldownKey: "agent-chat-provenance-server-unavailable.\(agentChat.url.absoluteString)",
            cooldownInterval: 60
        )
    }

    private func ensureAgentChatServerAvailable(
        _ agentChat: BmuxAgentChatConfiguration,
        globalConfigPath: String?,
        preferredWindow: NSWindow?
    ) async -> Bool {
        if await Self.agentChatServerIsHealthy(healthURL: agentChat.healthURL, timeout: 1.5) {
            return true
        }
        guard let startCommand = agentChat.startCommand else {
            return false
        }
        guard await authorizeAgentChatStartCommandIfNeeded(
            agentChat,
            command: startCommand,
            globalConfigPath: globalConfigPath,
            preferredWindow: preferredWindow
        ) else {
            return false
        }
        guard Self.launchDetachedAgentChatStartCommand(
            startCommand,
            currentDirectoryURL: Self.agentChatStartCommandDirectoryURL(for: agentChat)
        ) else {
            return false
        }
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(10))
        while !Task.isCancelled, clock.now < deadline {
            if await Self.agentChatServerIsHealthy(healthURL: agentChat.healthURL, timeout: 1.5) {
                return true
            }
            do {
                // Bounded, cancellable health polling after a configured server start.
                try await clock.sleep(for: .milliseconds(250))
            } catch {
                return false
            }
        }
        return false
    }

    private func authorizeAgentChatStartCommandIfNeeded(
        _ agentChat: BmuxAgentChatConfiguration,
        command: String,
        globalConfigPath: String?,
        preferredWindow: NSWindow?
    ) async -> Bool {
        guard agentChat.startCommandRequiresTrust else { return true }
        guard case .local(let sourcePath) = agentChat.source,
              let globalConfigPath else {
            return false
        }
        let descriptor = Self.agentChatStartCommandTrustDescriptor(
            command: command,
            sourcePath: sourcePath
        )
        return await withCheckedContinuation { continuation in
            _ = BmuxConfigExecutor.authorizeProjectAutomationIfNeeded(
                descriptor: descriptor,
                confirm: false,
                configSourcePath: sourcePath,
                globalConfigPath: globalConfigPath,
                displayCommand: command,
                displayTitle: String(localized: "command.newAgentChat.title", defaultValue: "New agent chat"),
                presentingWindow: preferredWindow,
                onAuthorized: {
                    continuation.resume(returning: true)
                },
                onDenied: {
                    continuation.resume(returning: false)
                }
            )
        }
    }

    nonisolated private static func agentChatStartCommandTrustDescriptor(
        command: String,
        sourcePath: String
    ) -> BmuxActionTrustDescriptor {
        BmuxActionTrustDescriptor(
            actionID: "\(BmuxSurfaceTabBarBuiltInAction.newAgentChat.configID).startCommand",
            kind: "agentChatStartCommand",
            command: command,
            target: "agentChatServer",
            workspaceCommand: nil,
            configPath: canonicalAgentChatPath(sourcePath),
            projectRoot: canonicalAgentChatPath(BmuxButtonIcon.projectRoot(forConfigPath: sourcePath)),
            iconFingerprint: nil
        )
    }

    nonisolated private static func agentChatServerIsHealthy(
        healthURL: URL,
        timeout: TimeInterval
    ) async -> Bool {
        var request = URLRequest(
            url: healthURL,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: timeout
        )
        request.httpMethod = "GET"
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return (200..<300).contains(httpResponse.statusCode)
        } catch {
            return false
        }
    }

    nonisolated private static func agentChatStartCommandDirectoryURL(
        for agentChat: BmuxAgentChatConfiguration
    ) -> URL {
        if case .local(let sourcePath) = agentChat.source {
            return URL(
                fileURLWithPath: canonicalAgentChatPath(BmuxButtonIcon.projectRoot(forConfigPath: sourcePath)),
                isDirectory: true
            )
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    nonisolated private static func launchDetachedAgentChatStartCommand(
        _ command: String,
        currentDirectoryURL: URL
    ) -> Bool {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCommand.isEmpty else { return false }
        let environment = ProcessInfo.processInfo.environment
        guard let shellPath = environment["SHELL"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !shellPath.isEmpty else {
            NSLog("[AgentChat] SHELL is not set; cannot launch startCommand")
            return false
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shellPath)
        process.arguments = ["-lc", trimmedCommand]
        process.currentDirectoryURL = currentDirectoryURL
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            return true
        } catch {
            NSLog("[AgentChat] failed to launch startCommand: %@", String(describing: error))
            return false
        }
    }

    nonisolated private static func canonicalAgentChatPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }
}
