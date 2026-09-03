import ProvenanceEngineContracts

extension ProvenanceSQLiteRepository {
    func projectionCounts(from payloads: [ProvenanceEventPayload]) -> [String: Int] {
        var repositories = Set<String>()
        var worktrees = Set<String>()
        var sessions = Set<String>()
        var sessionRelationships = Set<String>()
        var externalIdentities = Set<String>()
        var workItems = Set<String>()
        var contributions = Set<String>()
        var checkpoints = Set<String>()
        var changeSets = Set<String>()
        var fileChanges = Set<String>()
        var validationRuns = Set<String>()
        var workspaceDisplays = Set<String>()
        var workspaceCodingAgentSessionAssociations = Set<String>()
        var codingAgentThreads = Set<String>()
        var codingAgentTurns = Set<String>()
        var codingAgentPrompts = Set<String>()
        var codingAgentPlanUpdates = Set<String>()
        var codingAgentCommands = Set<String>()
        var codingAgentReasoningSummaries = Set<String>()
        var codingAgentAssistantMessages = Set<String>()
        var codingAgentFileChangeAttributions = Set<String>()

        for payload in payloads {
            if let repository = payload.repository {
                repositories.insert(repository.id)
            }
            if let worktree = payload.worktree {
                worktrees.insert(worktree.id)
            }
            if let session = payload.session {
                sessions.insert(session.id)
            }
            if let relationship = payload.sessionRelationship {
                sessionRelationships.insert(relationship.sessionID)
            }
            for identity in payload.externalIdentities {
                externalIdentities.insert("\(identity.system)\u{0}\(identity.kind)\u{0}\(identity.externalID)")
            }
            if let workItem = payload.workItem {
                workItems.insert(workItem.id)
            }
            if let contribution = payload.contribution {
                contributions.insert(contribution.id)
            }
            if let checkpoint = payload.checkpoint {
                checkpoints.insert(checkpoint.id)
            }
            if let changeSet = payload.changeSet {
                changeSets.insert(changeSet.id)
            }
            for fileChange in payload.fileChanges {
                fileChanges.insert(fileChange.id)
            }
            if let validationRun = payload.validationRun {
                validationRuns.insert(validationRun.id)
            }
            if let workspaceDisplay = payload.workspaceDisplay {
                workspaceDisplays.insert(workspaceDisplay.id)
            }
            if let association = payload.workspaceCodingAgentSessionAssociation {
                workspaceCodingAgentSessionAssociations.insert(association.id)
            }
            if let codingAgentThread = payload.codingAgentThread {
                codingAgentThreads.insert(codingAgentThread.id)
            }
            if let codingAgentTurn = payload.codingAgentTurn {
                codingAgentTurns.insert(codingAgentTurn.id)
            }
            if let codingAgentPrompt = payload.codingAgentPrompt {
                codingAgentPrompts.insert(codingAgentPrompt.id)
            }
            if let codingAgentPlanUpdate = payload.codingAgentPlanUpdate {
                codingAgentPlanUpdates.insert(codingAgentPlanUpdate.id)
            }
            if let codingAgentCommand = payload.codingAgentCommand {
                codingAgentCommands.insert(codingAgentCommand.id)
            }
            if let codingAgentReasoningSummary = payload.codingAgentReasoningSummary {
                codingAgentReasoningSummaries.insert(codingAgentReasoningSummary.id)
            }
            if let codingAgentAssistantMessage = payload.codingAgentAssistantMessage {
                codingAgentAssistantMessages.insert(codingAgentAssistantMessage.id)
            }
            if let codingAgentFileChangeAttribution = payload.codingAgentFileChangeAttribution {
                codingAgentFileChangeAttributions.insert(codingAgentFileChangeAttribution.id)
            }
        }

        return [
            "provenance_repositories": repositories.count,
            "provenance_worktrees": worktrees.count,
            "provenance_sessions": sessions.count,
            "provenance_session_relationships": sessionRelationships.count,
            "provenance_session_external_identities": externalIdentities.count,
            "provenance_work_items": workItems.count,
            "provenance_work_contributions": contributions.count,
            "provenance_checkpoints": checkpoints.count,
            "provenance_change_sets": changeSets.count,
            "provenance_file_changes": fileChanges.count,
            "provenance_validation_runs": validationRuns.count,
            "provenance_workspace_display": workspaceDisplays.count,
            "provenance_workspace_coding_agent_session_associations": workspaceCodingAgentSessionAssociations.count,
            "provenance_coding_agent_threads": codingAgentThreads.count,
            "provenance_coding_agent_turns": codingAgentTurns.count,
            "provenance_coding_agent_prompts": codingAgentPrompts.count,
            "provenance_coding_agent_plan_updates": codingAgentPlanUpdates.count,
            "provenance_coding_agent_commands": codingAgentCommands.count,
            "provenance_coding_agent_reasoning_summaries": codingAgentReasoningSummaries.count,
            "provenance_coding_agent_assistant_messages": codingAgentAssistantMessages.count,
            "provenance_coding_agent_file_change_attributions": codingAgentFileChangeAttributions.count,
        ]
    }

    func projectionKeys(from payloads: [ProvenanceEventPayload]) -> [String: Set<String>] {
        var repositories = Set<String>()
        var worktrees = Set<String>()
        var sessions = Set<String>()
        var sessionRelationships = Set<String>()
        var externalIdentities = Set<String>()
        var workItems = Set<String>()
        var contributions = Set<String>()
        var checkpoints = Set<String>()
        var changeSets = Set<String>()
        var fileChanges = Set<String>()
        var validationRuns = Set<String>()
        var workspaceDisplays = Set<String>()
        var workspaceCodingAgentSessionAssociations = Set<String>()
        var codingAgentThreads = Set<String>()
        var codingAgentTurns = Set<String>()
        var codingAgentPrompts = Set<String>()
        var codingAgentPlanUpdates = Set<String>()
        var codingAgentCommands = Set<String>()
        var codingAgentReasoningSummaries = Set<String>()
        var codingAgentAssistantMessages = Set<String>()
        var codingAgentFileChangeAttributions = Set<String>()

        for payload in payloads {
            if let repository = payload.repository {
                repositories.insert(repository.id)
            }
            if let worktree = payload.worktree {
                worktrees.insert(worktree.id)
            }
            if let session = payload.session {
                sessions.insert(session.id)
            }
            if let relationship = payload.sessionRelationship {
                sessionRelationships.insert(relationship.sessionID)
            }
            for identity in payload.externalIdentities {
                externalIdentities.insert(projectionExternalIdentityKey(identity))
            }
            if let workItem = payload.workItem {
                workItems.insert(workItem.id)
            }
            if let contribution = payload.contribution {
                contributions.insert(contribution.id)
            }
            if let checkpoint = payload.checkpoint {
                checkpoints.insert(checkpoint.id)
            }
            if let changeSet = payload.changeSet {
                changeSets.insert(changeSet.id)
            }
            for fileChange in payload.fileChanges {
                fileChanges.insert(fileChange.id)
            }
            if let validationRun = payload.validationRun {
                validationRuns.insert(validationRun.id)
            }
            if let workspaceDisplay = payload.workspaceDisplay {
                workspaceDisplays.insert(workspaceDisplay.id)
            }
            if let association = payload.workspaceCodingAgentSessionAssociation {
                workspaceCodingAgentSessionAssociations.insert(association.id)
            }
            if let codingAgentThread = payload.codingAgentThread {
                codingAgentThreads.insert(codingAgentThread.id)
            }
            if let codingAgentTurn = payload.codingAgentTurn {
                codingAgentTurns.insert(codingAgentTurn.id)
            }
            if let codingAgentPrompt = payload.codingAgentPrompt {
                codingAgentPrompts.insert(codingAgentPrompt.id)
            }
            if let codingAgentPlanUpdate = payload.codingAgentPlanUpdate {
                codingAgentPlanUpdates.insert(codingAgentPlanUpdate.id)
            }
            if let codingAgentCommand = payload.codingAgentCommand {
                codingAgentCommands.insert(codingAgentCommand.id)
            }
            if let codingAgentReasoningSummary = payload.codingAgentReasoningSummary {
                codingAgentReasoningSummaries.insert(codingAgentReasoningSummary.id)
            }
            if let codingAgentAssistantMessage = payload.codingAgentAssistantMessage {
                codingAgentAssistantMessages.insert(codingAgentAssistantMessage.id)
            }
            if let codingAgentFileChangeAttribution = payload.codingAgentFileChangeAttribution {
                codingAgentFileChangeAttributions.insert(codingAgentFileChangeAttribution.id)
            }
        }

        return [
            "provenance_repositories": repositories,
            "provenance_worktrees": worktrees,
            "provenance_sessions": sessions,
            "provenance_session_relationships": sessionRelationships,
            "provenance_session_external_identities": externalIdentities,
            "provenance_work_items": workItems,
            "provenance_work_contributions": contributions,
            "provenance_checkpoints": checkpoints,
            "provenance_change_sets": changeSets,
            "provenance_file_changes": fileChanges,
            "provenance_validation_runs": validationRuns,
            "provenance_workspace_display": workspaceDisplays,
            "provenance_workspace_coding_agent_session_associations": workspaceCodingAgentSessionAssociations,
            "provenance_coding_agent_threads": codingAgentThreads,
            "provenance_coding_agent_turns": codingAgentTurns,
            "provenance_coding_agent_prompts": codingAgentPrompts,
            "provenance_coding_agent_plan_updates": codingAgentPlanUpdates,
            "provenance_coding_agent_commands": codingAgentCommands,
            "provenance_coding_agent_reasoning_summaries": codingAgentReasoningSummaries,
            "provenance_coding_agent_assistant_messages": codingAgentAssistantMessages,
            "provenance_coding_agent_file_change_attributions": codingAgentFileChangeAttributions,
        ]
    }

    var projectionTableNames: [String] {
        [
            "provenance_repositories",
            "provenance_worktrees",
            "provenance_sessions",
            "provenance_session_relationships",
            "provenance_session_external_identities",
            "provenance_work_items",
            "provenance_work_contributions",
            "provenance_checkpoints",
            "provenance_change_sets",
            "provenance_file_changes",
            "provenance_validation_runs",
            "provenance_workspace_display",
            "provenance_workspace_coding_agent_session_associations",
            "provenance_coding_agent_threads",
            "provenance_coding_agent_turns",
            "provenance_coding_agent_prompts",
            "provenance_coding_agent_plan_updates",
            "provenance_coding_agent_commands",
            "provenance_coding_agent_reasoning_summaries",
            "provenance_coding_agent_assistant_messages",
            "provenance_coding_agent_file_change_attributions",
        ]
    }

    func projectionExternalIdentityKey(_ identity: ProvenanceExternalIdentityRecord) -> String {
        projectionExternalIdentityKey(system: identity.system, kind: identity.kind, externalID: identity.externalID)
    }

    func projectionExternalIdentityKey(system: String, kind: String, externalID: String) -> String {
        "\(system)\u{0}\(kind)\u{0}\(externalID)"
    }
}
