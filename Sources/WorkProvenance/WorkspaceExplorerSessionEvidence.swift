import ProvenanceEngineContracts

/// Retained factual and outcome detail for one Explorer history session.
struct WorkspaceExplorerSessionEvidence {
    let projection: ProvenanceFactualSessionProjectionResponse
    let outcome: ProvenanceSessionOutcomeResponse
}
