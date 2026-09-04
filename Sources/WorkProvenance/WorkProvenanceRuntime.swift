import AppKit
import BmuxAgentChat
import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK

struct WorkProvenanceLiveWorkspaceBinding: Equatable, Sendable {
    let runtimeWorkspaceID: UUID
    let stableWorkspaceID: UUID
    let surfaceIDs: Set<UUID>
    let currentDirectory: String
}

enum WorkProvenanceSessionAssociationResolver {
    static func resolvedStableWorkspaceID(
        workspaceID: String?,
        surfaceID: String?,
        workingDirectory: String?,
        liveWorkspaceBindings: [WorkProvenanceLiveWorkspaceBinding]
    ) -> String? {
        if let workspaceUUID = uuid(from: workspaceID),
           let binding = liveWorkspaceBindings.first(where: {
               $0.runtimeWorkspaceID == workspaceUUID || $0.stableWorkspaceID == workspaceUUID
           }) {
            return binding.stableWorkspaceID.uuidString
        }

        if let surfaceUUID = uuid(from: surfaceID),
           let binding = liveWorkspaceBindings.first(where: { $0.surfaceIDs.contains(surfaceUUID) }) {
            return binding.stableWorkspaceID.uuidString
        }

        if let workingDirectory = normalizedPath(workingDirectory) {
            let matchingBindings = liveWorkspaceBindings.filter {
                normalizedPath($0.currentDirectory) == workingDirectory
            }
            if matchingBindings.count == 1 {
                return matchingBindings[0].stableWorkspaceID.uuidString
            }
        }

        return trimmedNonEmpty(workspaceID)
    }

    private static func uuid(from value: String?) -> UUID? {
        trimmedNonEmpty(value).flatMap(UUID.init(uuidString:))
    }

    private static func normalizedPath(_ path: String?) -> String? {
        guard let path = trimmedNonEmpty(path) else { return nil }
        return NSString(string: path).standardizingPath
    }

    private static func trimmedNonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

/// Main-actor runtime that wires workspace lifecycle to observe-only provenance storage.
@MainActor
final class WorkProvenanceRuntime {
    private weak var tabManager: TabManager?
    private let observationService: WorkProvenanceObservationService?
    private let workspaceDisplayCurrentStateStore: WorkspaceDisplayCurrentStateStore?
    private let workspaceDisplayCurrentStateSubscription: WorkspaceDisplayCurrentStateSubscription?
    private let sessionLifecycleRecorder: WorkProvenanceSessionLifecycleRecorder?
    private let codingAgentEvidenceRecorder: WorkProvenanceCodingAgentEvidenceRecorder?
    private var directoryObservationTask: Task<Void, Never>?
    private var titleObservationTask: Task<Void, Never>?
    private var displayMetadataObservationTask: Task<Void, Never>?
    private var activationObservationTask: Task<Void, Never>?
    private var executionTelemetryProjectionService: ExecutionTelemetryProvenanceProjectionService?

    /// Effective V1 database path when the runtime starts successfully.
    let effectiveDatabaseURL: URL?

    /// Startup failure retained for diagnostics when provenance is disabled.
    let startupErrorDescription: String?

    /// Whether the runtime has a usable provenance store.
    let isEnabled: Bool

    /// Creates a provenance runtime.
    init(
        observationService: WorkProvenanceObservationService?,
        workspaceDisplayCurrentStateStore: WorkspaceDisplayCurrentStateStore? = nil,
        workspaceDisplayCurrentStateSubscription: WorkspaceDisplayCurrentStateSubscription? = nil,
        sessionLifecycleRecorder: WorkProvenanceSessionLifecycleRecorder? = nil,
        codingAgentEvidenceRecorder: WorkProvenanceCodingAgentEvidenceRecorder? = nil,
        effectiveDatabaseURL: URL? = nil,
        startupErrorDescription: String? = nil
    ) {
        self.observationService = observationService
        self.workspaceDisplayCurrentStateStore = workspaceDisplayCurrentStateStore
        self.workspaceDisplayCurrentStateSubscription = workspaceDisplayCurrentStateSubscription
        self.sessionLifecycleRecorder = sessionLifecycleRecorder
        self.codingAgentEvidenceRecorder = codingAgentEvidenceRecorder
        self.effectiveDatabaseURL = effectiveDatabaseURL
        self.startupErrorDescription = startupErrorDescription
        self.isEnabled = observationService != nil
    }

    deinit {
        directoryObservationTask?.cancel()
        titleObservationTask?.cancel()
        displayMetadataObservationTask?.cancel()
        activationObservationTask?.cancel()
    }

    /// Creates the standard runtime backed by the per-user bmux state directory.
    static func live(
        homeDirectory: URL = WorkProvenanceStorageLocation.defaultHomeDirectory(),
        linearAuthorizationProvider: (any WorkProvenanceLinearAuthorizationProviding)? = nil
    ) -> WorkProvenanceRuntime {
        let location = WorkProvenanceStorageLocation(homeDirectory: homeDirectory)
        do {
            let client: any ProvenanceEngineContracts.ProvenanceEngineClient =
                try ProvenanceEngineClientFactory().defaultSQLiteClient(homeDirectory: homeDirectory)
            NSLog("bmux provenance runtime using database: %@", location.databaseURL.path)
            return WorkProvenanceRuntime(
                observationService: WorkProvenanceObservationService(
                    client: client,
                    gitInspector: WorkProvenanceGitInspector(),
                    ticketLinkResolver: WorkProvenanceLinearTicketLinkResolver(
                        authorizationProvider: linearAuthorizationProvider
                    )
                ),
                workspaceDisplayCurrentStateStore: WorkspaceDisplayCurrentStateStore(client: client),
                workspaceDisplayCurrentStateSubscription: WorkspaceDisplayCurrentStateSubscription(
                    databaseURL: location.databaseURL
                ),
                sessionLifecycleRecorder: WorkProvenanceSessionLifecycleRecorder(
                    client: client
                ),
                codingAgentEvidenceRecorder: WorkProvenanceCodingAgentEvidenceRecorder(
                    client: client
                ),
                effectiveDatabaseURL: location.databaseURL
            )
        } catch {
            let description = String(describing: error)
            NSLog("bmux provenance runtime unavailable: %@", description)
            return WorkProvenanceRuntime(
                observationService: nil,
                effectiveDatabaseURL: location.databaseURL,
                startupErrorDescription: description
            )
        }
    }

    /// Starts observing workspace list and current-directory changes.
    func start(tabManager: TabManager) {
        guard let observationService else { return }
        self.tabManager = tabManager
        Task {
            await observationService.pruneExpiredObservedHistory()
        }
        observeWorkspaces(tabManager.tabs)
        startDirectoryObservationIfNeeded()
        startDisplayObservationIfNeeded()
        startActivationObservationIfNeeded()
        startWorkspaceDisplayCurrentStateSubscriptionIfNeeded()
    }

    /// Starts projecting eligible live execution telemetry facts into provenance.
    func startExecutionTelemetryProjection(
        agentChatURL: URL,
        sidecarStatusHandler: @escaping (ExecutionTelemetryProjectionSidecarStatus) -> Void = { _ in }
    ) {
        guard let sessionLifecycleRecorder else { return }
        guard executionTelemetryProjectionService?.agentChatURL != agentChatURL else {
            executionTelemetryProjectionService?.updateSidecarStatusHandler(sidecarStatusHandler)
            executionTelemetryProjectionService?.start()
            return
        }
        executionTelemetryProjectionService?.stop()
        let service = ExecutionTelemetryProvenanceProjectionService(
            agentChatURL: agentChatURL,
            lifecycleRecorder: sessionLifecycleRecorder,
            codingAgentEvidenceRecorder: codingAgentEvidenceRecorder,
            workspaceAssociationResolver: { [weak self] summary in
                self?.executionTelemetryWorkspaceAssociation(for: summary)
                    ?? ExecutionTelemetryWorkspaceAssociation(workingDirectory: summary.cwd)
            },
            sidecarStatusHandler: sidecarStatusHandler
        )
        executionTelemetryProjectionService = service
        service.start()
    }

    /// Observes the provided live workspaces.
    func observeWorkspaces(_ workspaces: [Workspace]) {
        StartupBreadcrumbLog.append("workProvenance.runtime.observeWorkspaces", fields: [
            "count": "\(workspaces.count)"
        ])
        guard let observationService else { return }
        let snapshots = workspaces.map(WorkProvenanceWorkspaceSnapshot.init(workspace:))
        let stableWorkspaceIDs = snapshots.map(\.stableWorkspaceID)
        Task {
            await observationService.observeWorkspaceSnapshots(snapshots)
            await MainActor.run {
                self.refreshWorkspaceDisplayCurrentState(stableWorkspaceIDs: stableWorkspaceIDs)
            }
        }
    }

    /// Reads the latest PE-owned workspace display state cached for a workspace.
    func workspaceDisplayCurrentStateSnapshot(for workspace: Workspace) -> WorkspaceDisplayCurrentStateSnapshot? {
        workspaceDisplayCurrentStateStore?.snapshot(for: workspace)
    }

    /// Refreshes one workspace display projection from PE for tab/sidebar rendering.
    func refreshWorkspaceDisplayCurrentState(for workspace: Workspace) {
        refreshWorkspaceDisplayCurrentState(stableWorkspaceIDs: [workspace.stableId])
    }

    /// Persists an observed agent session lifecycle change.
    func recordSessionLifecycleChange(_ change: AgentSessionLifecycleChange, timestamp: Date) {
        guard let sessionLifecycleRecorder else { return }
        let resolvedChange = AgentSessionLifecycleChange(
            phase: change.phase,
            parentSessionID: change.parentSessionID,
            agentKind: change.agentKind,
            workspaceID: provenanceWorkspaceID(
                workspaceID: change.workspaceID,
                surfaceID: change.surfaceID,
                workingDirectory: change.workingDirectory
            ),
            surfaceID: change.surfaceID,
            workingDirectory: change.workingDirectory,
            externalSessionID: change.externalSessionID,
            displayName: change.displayName
        )
        Task {
            await sessionLifecycleRecorder.record(resolvedChange, timestamp: timestamp)
        }
    }

    /// Persists an observed top-level agent session presence change.
    func recordSessionPresenceChange(_ change: AgentSessionPresenceChange, timestamp: Date) {
        guard let sessionLifecycleRecorder else { return }
        let resolvedChange = AgentSessionPresenceChange(
            phase: change.phase,
            sessionID: change.sessionID,
            agentKind: change.agentKind,
            workspaceID: provenanceWorkspaceID(
                workspaceID: change.workspaceID,
                surfaceID: change.surfaceID,
                workingDirectory: change.workingDirectory
            ),
            surfaceID: change.surfaceID,
            workingDirectory: change.workingDirectory,
            displayName: change.displayName
        )
        Task {
            await sessionLifecycleRecorder.record(resolvedChange, timestamp: timestamp)
        }
    }

    private func executionTelemetryWorkspaceAssociation(
        for summary: AgentChatSessionSummary
    ) -> ExecutionTelemetryWorkspaceAssociation {
        ExecutionTelemetryWorkspaceAssociation(
            workspaceID: provenanceWorkspaceID(
                workspaceID: nil,
                surfaceID: nil,
                workingDirectory: summary.cwd
            ),
            surfaceID: nil,
            workingDirectory: summary.cwd
        )
    }

    private func provenanceWorkspaceID(
        workspaceID: String?,
        surfaceID: String?,
        workingDirectory: String?
    ) -> String? {
        WorkProvenanceSessionAssociationResolver.resolvedStableWorkspaceID(
            workspaceID: workspaceID,
            surfaceID: surfaceID,
            workingDirectory: workingDirectory,
            liveWorkspaceBindings: liveWorkspaceBindings()
        )
    }

    private func liveWorkspaceBindings() -> [WorkProvenanceLiveWorkspaceBinding] {
        tabManager?.tabs.map { workspace in
            WorkProvenanceLiveWorkspaceBinding(
                runtimeWorkspaceID: workspace.id,
                stableWorkspaceID: workspace.stableId,
                surfaceIDs: Set(workspace.panels.keys),
                currentDirectory: workspace.currentDirectory
            )
        } ?? []
    }

    private func startDirectoryObservationIfNeeded() {
        guard directoryObservationTask == nil else { return }
        directoryObservationTask = Task { @MainActor [weak self] in
            let notifications = NotificationCenter.default.notifications(
                named: .workspaceCurrentDirectoryDidChange
            )
            for await notification in notifications {
                self?.handleCurrentDirectoryNotification(notification)
            }
        }
    }

    private func startDisplayObservationIfNeeded() {
        if titleObservationTask == nil {
            titleObservationTask = Task { @MainActor [weak self] in
                let notifications = NotificationCenter.default.notifications(
                    named: .workspaceTitleDidChange
                )
                for await notification in notifications {
                    self?.observeWorkspace(from: notification)
                }
            }
        }
        if displayMetadataObservationTask == nil {
            displayMetadataObservationTask = Task { @MainActor [weak self] in
                let notifications = NotificationCenter.default.notifications(
                    named: .workspaceDisplayMetadataDidChange
                )
                for await notification in notifications {
                    self?.observeWorkspace(from: notification)
                }
            }
        }
    }

    private func startActivationObservationIfNeeded() {
        guard activationObservationTask == nil else { return }
        activationObservationTask = Task { @MainActor [weak self] in
            let notifications = NotificationCenter.default.notifications(
                named: NSApplication.didBecomeActiveNotification
            )
            for await _ in notifications {
                self?.refreshAllWorkspaceDisplayCurrentState()
            }
        }
    }

    private func startWorkspaceDisplayCurrentStateSubscriptionIfNeeded() {
        workspaceDisplayCurrentStateSubscription?.start(
            stableWorkspaceIDs: { [weak self] in
                self?.tabManager?.tabs.map(\.stableId) ?? []
            },
            refresh: { [weak self] stableWorkspaceIDs in
                self?.refreshWorkspaceDisplayCurrentState(stableWorkspaceIDs: stableWorkspaceIDs)
            }
        )
    }

    private func handleCurrentDirectoryNotification(_ notification: Notification) {
        observeWorkspace(from: notification)
    }

    private func observeWorkspace(from notification: Notification) {
        let workspaceID = (notification.userInfo?["workspaceId"] as? UUID)
            ?? (notification.userInfo?[GhosttyNotificationKey.tabId] as? UUID)
        guard let workspaceID,
              let workspace = tabManager?.tabs.first(where: { $0.id == workspaceID }) else {
            return
        }
        observeWorkspaces([workspace])
    }

    private func refreshAllWorkspaceDisplayCurrentState() {
        refreshWorkspaceDisplayCurrentState(stableWorkspaceIDs: tabManager?.tabs.map(\.stableId) ?? [])
    }

    private func refreshWorkspaceDisplayCurrentState(stableWorkspaceIDs: [UUID]) {
        workspaceDisplayCurrentStateStore?.refresh(
            stableWorkspaceIDs: stableWorkspaceIDs,
            notify: { [weak self] stableWorkspaceID in
                self?.workspaceDisplayCurrentStateDidChange(stableWorkspaceID: stableWorkspaceID)
            }
        )
    }

    private func workspaceDisplayCurrentStateDidChange(stableWorkspaceID: UUID) {
        guard let tabManager,
              let workspace = tabManager.tabs.first(where: { $0.stableId == stableWorkspaceID }) else {
            return
        }
        tabManager.objectWillChange.send()
        workspace.sidebarImmediateObservationChangeSubject.send(())
    }

    private static var isRunningUnderXCTest: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
