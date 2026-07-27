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
            sessionID: change.sessionID,
            parentSessionID: change.sessionID == nil ? change.parentSessionID : nil,
            agentKind: change.agentKind.sourceName,
            workspaceID: change.workspaceID,
            surfaceID: change.surfaceID,
            worktreeID: worktreeID,
            workingDirectory: change.workingDirectory,
            externalIdentityKind: change.externalSessionID == nil ? nil : "subagent",
            externalIdentityValue: change.externalSessionID,
            displayName: change.displayName,
            timestamp: timestamp
        ))
        lastErrorDescription = response.errorDescription
        if let errorDescription = response.errorDescription {
            NSLog("bmux provenance session lifecycle recording failed: %@", errorDescription)
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
