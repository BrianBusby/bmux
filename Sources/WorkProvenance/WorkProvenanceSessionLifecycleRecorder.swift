import Foundation
import ProvenanceEngineContracts

/// Records observed agent session lifecycle changes through the public Provenance Engine SDK.
actor WorkProvenanceSessionLifecycleRecorder {
    private let client: any ProvenanceEngineContracts.ProvenanceEngineClient
    private let gitInspector: any WorkProvenanceGitInspecting
    private let stableIDFactory: WorkProvenanceStableIDFactory

    /// Last persistence error, retained for diagnostics.
    private(set) var lastErrorDescription: String?

    /// Creates an engine-backed session lifecycle recorder.
    init(
        client: any ProvenanceEngineContracts.ProvenanceEngineClient,
        gitInspector: any WorkProvenanceGitInspecting = WorkProvenanceGitInspector(),
        stableIDFactory: WorkProvenanceStableIDFactory = WorkProvenanceStableIDFactory()
    ) {
        self.client = client
        self.gitInspector = gitInspector
        self.stableIDFactory = stableIDFactory
    }

    /// Records a lifecycle change, keeping provenance persistence best-effort.
    func record(_ change: AgentSessionLifecycleChange, timestamp: Date) async {
        let worktreeID = await resolvedWorktreeID(for: change.workingDirectory)
        let response = await client.recordSessionLifecycle(ProvenanceEngineContracts.ProvenanceSessionLifecycleRequest(
            phase: ProvenanceEngineContracts.ProvenanceSessionLifecyclePhase(change.phase),
            parentSessionID: change.parentSessionID,
            agentKind: change.agentKind.sourceName,
            workspaceID: change.workspaceID,
            surfaceID: change.surfaceID,
            worktreeID: worktreeID,
            workingDirectory: change.workingDirectory,
            externalIdentityKind: "subagent",
            externalIdentityValue: change.externalSessionID,
            displayName: change.displayName,
            timestamp: timestamp
        ))
        lastErrorDescription = response.errorDescription
        if let errorDescription = response.errorDescription {
            NSLog("bmux provenance session lifecycle recording failed: %@", errorDescription)
        }
    }

    /// Records top-level agent session presence, keeping provenance persistence best-effort.
    func record(_ change: AgentSessionPresenceChange, timestamp: Date) async {
        guard let sessionID = Self.trimmedNonEmpty(change.sessionID),
              let agentKind = Self.trimmedNonEmpty(change.agentKind.sourceName) else {
            return
        }
        let workspaceID = Self.trimmedNonEmpty(change.workspaceID)
        let surfaceID = Self.trimmedNonEmpty(change.surfaceID)
        let workingDirectory = Self.trimmedNonEmpty(change.workingDirectory)
        let worktreeID = await resolvedWorktreeID(for: workingDirectory)
        let response = await client.recordSessionLifecycle(ProvenanceEngineContracts.ProvenanceSessionLifecycleRequest(
            phase: ProvenanceEngineContracts.ProvenanceSessionLifecyclePhase(change.phase),
            sessionID: sessionID,
            parentSessionID: nil,
            agentKind: agentKind,
            workspaceID: workspaceID,
            surfaceID: surfaceID,
            worktreeID: worktreeID,
            workingDirectory: workingDirectory,
            externalIdentityKind: nil,
            externalIdentityValue: nil,
            displayName: change.displayName,
            timestamp: timestamp
        ))
        lastErrorDescription = response.errorDescription
        if let errorDescription = response.errorDescription {
            NSLog("bmux provenance agent session presence recording failed: %@", errorDescription)
        }
    }

    /// Records a broad sidecar execution-telemetry lifecycle presence fact.
    func recordExecutionTelemetrySessionStarted(
        sessionID: String,
        provider: String,
        providerSessionID: String?,
        workspaceID: String? = nil,
        surfaceID: String? = nil,
        workingDirectory: String?,
        timestamp: Date
    ) async {
        let trimmedSessionID = Self.trimmedNonEmpty(sessionID)
        let trimmedProvider = Self.trimmedNonEmpty(provider)
        guard let trimmedSessionID, let trimmedProvider else { return }
        let trimmedProviderSessionID = Self.trimmedNonEmpty(providerSessionID)
        let trimmedWorkspaceID = Self.trimmedNonEmpty(workspaceID)
        let trimmedSurfaceID = Self.trimmedNonEmpty(surfaceID)
        let trimmedWorkingDirectory = Self.trimmedNonEmpty(workingDirectory)
        let worktreeID = await resolvedWorktreeID(for: trimmedWorkingDirectory)
        let response = await client.recordSessionLifecycle(ProvenanceEngineContracts.ProvenanceSessionLifecycleRequest(
            phase: .started,
            sessionID: trimmedSessionID,
            parentSessionID: nil,
            agentKind: trimmedProvider,
            workspaceID: trimmedWorkspaceID,
            surfaceID: trimmedSurfaceID,
            worktreeID: worktreeID,
            workingDirectory: trimmedWorkingDirectory,
            externalIdentityKind: trimmedProviderSessionID == nil ? nil : "provider_session",
            externalIdentityValue: trimmedProviderSessionID,
            displayName: nil,
            timestamp: timestamp
        ))
        lastErrorDescription = response.errorDescription
        if let errorDescription = response.errorDescription {
            NSLog("bmux provenance execution telemetry lifecycle recording failed: %@", errorDescription)
        }
    }

    private func resolvedWorktreeID(for workingDirectory: String?) async -> String? {
        guard let workingDirectory = workingDirectory?.trimmingCharacters(in: .whitespacesAndNewlines),
              !workingDirectory.isEmpty,
              let snapshot = await gitInspector.snapshot(for: workingDirectory) else {
            return nil
        }
        return stableIDFactory.worktreeID(repositoryRoot: snapshot.repositoryRoot)
    }

    private static func trimmedNonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

private extension ProvenanceEngineContracts.ProvenanceSessionLifecyclePhase {
    init(_ phase: AgentSessionLifecycleChange.Phase) {
        switch phase {
        case .started:
            self = .started
        case .stopped:
            self = .stopped
        }
    }
}
