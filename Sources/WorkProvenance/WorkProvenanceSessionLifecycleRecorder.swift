import Foundation
import ProvenanceEngineContracts

/// Records observed agent session lifecycle changes through the public Provenance Engine SDK.
actor WorkProvenanceSessionLifecycleRecorder {
    private let client: any ProvenanceEngineContracts.ProvenanceEngineClient

    /// Last persistence error, retained for diagnostics.
    private(set) var lastErrorDescription: String?

    /// Creates an engine-backed session lifecycle recorder.
    init(client: any ProvenanceEngineContracts.ProvenanceEngineClient) {
        self.client = client
    }

    /// Records a lifecycle change, keeping provenance persistence best-effort.
    func record(_ change: AgentSessionLifecycleChange, timestamp: Date) async {
        let response = await client.recordSessionLifecycle(ProvenanceEngineContracts.ProvenanceSessionLifecycleRequest(
            phase: ProvenanceEngineContracts.ProvenanceSessionLifecyclePhase(change.phase),
            parentSessionID: change.parentSessionID,
            agentKind: change.agentKind.sourceName,
            workspaceID: change.workspaceID,
            surfaceID: change.surfaceID,
            workingDirectory: change.workingDirectory,
            externalIdentityKind: "subagent",
            externalIdentityValue: change.externalSessionID,
            displayName: change.displayName,
            timestamp: timestamp
        ))
        lastErrorDescription = response.errorDescription
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
