import ProvenanceEngineContracts

extension ProvenanceSessionOutcome {
    /// Keeps the aggregate and exact constituent IDs while avoiding a second copy of every turn payload.
    func storingTurnReferencesOnly() -> Self {
        replacingTurnOutcomes([])
    }

    func replacingTurnOutcomes(_ turns: [ProvenanceTurnOutcome]) -> Self {
        Self(
            schemaVersion: schemaVersion,
            sessionID: sessionID,
            session: session,
            externalIdentities: externalIdentities,
            providerThreadIdentities: providerThreadIdentities,
            projection: projection,
            constituentTurns: constituentTurns,
            turnOutcomes: turns,
            objectives: objectives,
            planItems: planItems,
            actionsCompleted: actionsCompleted,
            commandsCompleted: commandsCompleted,
            changedArtifacts: changedArtifacts,
            decisions: decisions,
            validationsAttempted: validationsAttempted,
            blockers: blockers,
            unresolvedItems: unresolvedItems,
            repositoryBoundaries: repositoryBoundaries,
            resumePoints: resumePoints,
            latestResumePoint: latestResumePoint,
            lifecycleState: lifecycleState,
            completionState: completionState,
            completeness: completeness
        )
    }
}
