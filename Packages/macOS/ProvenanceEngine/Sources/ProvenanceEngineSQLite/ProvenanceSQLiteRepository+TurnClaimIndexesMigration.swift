import Foundation

extension ProvenanceSQLiteRepository {
    /// Indexes each claim independently because one event can carry multiple payloads.
    static let turnClaimIndexMigrations = [
        ProvenanceSQLiteMigration(
            version: 32,
            statements: [
                """
                CREATE INDEX provenance_turn_claim_turn_index
                ON provenance_events (json_extract(payload_json, '$.codingAgentTurn.id'))
                WHERE json_valid(payload_json) AND json_extract(payload_json, '$.codingAgentTurn.id') IS NOT NULL
                """,
                """
                CREATE INDEX provenance_turn_claim_prompt_index
                ON provenance_events (json_extract(payload_json, '$.codingAgentPrompt.turnID'))
                WHERE json_valid(payload_json) AND json_extract(payload_json, '$.codingAgentPrompt.turnID') IS NOT NULL
                """,
                """
                CREATE INDEX provenance_turn_claim_plan_index
                ON provenance_events (json_extract(payload_json, '$.codingAgentPlanUpdate.turnID'))
                WHERE json_valid(payload_json) AND json_extract(payload_json, '$.codingAgentPlanUpdate.turnID') IS NOT NULL
                """,
                """
                CREATE INDEX provenance_turn_claim_command_index
                ON provenance_events (json_extract(payload_json, '$.codingAgentCommand.turnID'))
                WHERE json_valid(payload_json) AND json_extract(payload_json, '$.codingAgentCommand.turnID') IS NOT NULL
                """,
                """
                CREATE INDEX provenance_turn_claim_reasoning_index
                ON provenance_events (json_extract(payload_json, '$.codingAgentReasoningSummary.turnID'))
                WHERE json_valid(payload_json) AND json_extract(payload_json, '$.codingAgentReasoningSummary.turnID') IS NOT NULL
                """,
                """
                CREATE INDEX provenance_turn_claim_message_index
                ON provenance_events (json_extract(payload_json, '$.codingAgentAssistantMessage.turnID'))
                WHERE json_valid(payload_json) AND json_extract(payload_json, '$.codingAgentAssistantMessage.turnID') IS NOT NULL
                """,
                """
                CREATE INDEX provenance_turn_claim_file_change_index
                ON provenance_events (json_extract(payload_json, '$.codingAgentFileChangeAttribution.turnID'))
                WHERE json_valid(payload_json) AND json_extract(payload_json, '$.codingAgentFileChangeAttribution.turnID') IS NOT NULL
                """,
                "UPDATE provenance_metadata SET value = '32' WHERE key = 'schema_version'",
            ]
        ),
    ]
}
