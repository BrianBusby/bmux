import Foundation
import ProvenanceEngineContracts

extension BMUXCLI {
    func runProvenanceSession(commandArgs: [String], jsonOutput: Bool) async throws {
        let commandName = "provenance session outcome"
        let (databasePath, remainingAfterDatabase) = parseOption(commandArgs, name: "--database")
        let (revisionID, remainingAfterRevision) = parseOption(remainingAfterDatabase, name: "--revision")
        var remaining = remainingAfterRevision
        try rejectProvenanceUnknownFlags(remaining, commandName: commandName)
        guard remaining.first?.lowercased() == "outcome" else {
            throw CLIError(message: String(
                localized: "cli.provenance.session.usage",
                defaultValue: "Usage: bmux provenance session outcome <session-id> [--revision <revision-id>] [--database <path>] [--json]"
            ))
        }
        remaining.removeFirst()
        guard let sessionID = remaining.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              !sessionID.isEmpty else {
            throw CLIError(message: String(
                localized: "cli.provenance.session.usage",
                defaultValue: "Usage: bmux provenance session outcome <session-id> [--revision <revision-id>] [--database <path>] [--json]"
            ))
        }
        remaining.removeFirst()
        guard remaining.isEmpty else {
            throw CLIError(message: provenanceUnexpectedArgumentMessage(commandName: commandName, argument: remaining[0]))
        }

        let response: ProvenanceEngineContracts.ProvenanceSessionOutcomeResponse
        if let databaseURL = provenanceSessionOutcomeDatabaseOverrideURL(databasePath: databasePath),
           !FileManager.default.fileExists(atPath: databaseURL.path) {
            response = ProvenanceEngineContracts.ProvenanceSessionOutcomeResponse(
                found: false,
                reason: "no_database",
                sessionID: sessionID,
                outcome: nil
            )
        } else {
            let (client, _) = try provenanceEngineClient(databasePath: databasePath)
            response = try await client.sessionOutcome(ProvenanceSessionOutcomeRequest(
                sessionID: sessionID,
                revisionID: revisionID
            ))
        }
        printProvenanceSessionOutcome(response, jsonOutput: jsonOutput)
    }

    private func provenanceSessionOutcomeDatabaseOverrideURL(databasePath: String?) -> URL? {
        if let databasePath = databasePath?.trimmingCharacters(in: .whitespacesAndNewlines),
           !databasePath.isEmpty {
            return URL(fileURLWithPath: NSString(string: databasePath).expandingTildeInPath)
        }
        return nil
    }

    private func printProvenanceSessionOutcome(
        _ response: ProvenanceEngineContracts.ProvenanceSessionOutcomeResponse,
        jsonOutput: Bool
    ) {
        if jsonOutput {
            print(jsonString(provenanceSessionOutcomeResponsePayload(response)))
            return
        }
        print(renderProvenanceSessionOutcome(response))
    }

    private func renderProvenanceSessionOutcome(
        _ response: ProvenanceEngineContracts.ProvenanceSessionOutcomeResponse
    ) -> String {
        guard response.found, let outcome = response.outcome else {
            return [
                String.localizedStringWithFormat(
                    String(
                        localized: "cli.provenance.session.output.notFound",
                        defaultValue: "No session outcome found for %@"
                    ),
                    response.sessionID
                ),
                response.reason.map {
                    String.localizedStringWithFormat(
                        String(localized: "cli.provenance.output.reason", defaultValue: "Reason: %@"),
                        $0
                    )
                },
            ].compactMap(\.self).joined(separator: "\n")
        }

        let unknown = String(localized: "cli.provenance.session.output.unknown", defaultValue: "unknown")
        let watermark = outcome.projection.sourceEvidenceWatermark.map(String.init) ?? unknown
        var lines = provenanceSessionOutcomeHeaderLines(outcome, watermark: watermark)
        if let resumePoint = outcome.latestResumePoint?.text, !resumePoint.isEmpty {
            lines.append(String.localizedStringWithFormat(
                String(localized: "cli.provenance.session.output.resumePoint", defaultValue: "Latest resume point: %@"),
                resumePoint
            ))
        }
        return lines.joined(separator: "\n")
    }

    private func provenanceSessionOutcomeHeaderLines(
        _ outcome: ProvenanceEngineContracts.ProvenanceSessionOutcome,
        watermark: String
    ) -> [String] {
        [
            String.localizedStringWithFormat(
                String(localized: "cli.provenance.session.output.header", defaultValue: "Session outcome for %@"),
                outcome.sessionID
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.provenance.session.output.lifecycle", defaultValue: "Lifecycle: %@ - state: %@"),
                outcome.lifecycleState,
                outcome.completionState
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.provenance.session.output.revision", defaultValue: "Revision: %@ - watermark: %@"),
                outcome.projection.revisionID,
                watermark
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.provenance.session.output.completeness", defaultValue: "Completeness: %@"),
                outcome.completeness.status
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.provenance.session.output.providerThreads", defaultValue: "Provider threads: %d"),
                outcome.providerThreadIdentities.count
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.provenance.session.output.turns", defaultValue: "Turns: %d"),
                outcome.constituentTurns.count
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.provenance.session.output.repositoryBoundaries", defaultValue: "Repository boundaries: %d"),
                outcome.repositoryBoundaries.count
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.provenance.session.output.objectivesPlan", defaultValue: "Objectives: %d - plan items: %d"),
                outcome.objectives.count,
                outcome.planItems.count
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.provenance.session.output.commandsValidations", defaultValue: "Commands: %d - validations: %d"),
                outcome.commandsCompleted.count,
                outcome.validationsAttempted.count
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.provenance.session.output.artifacts", defaultValue: "Changed artifacts: %d"),
                outcome.changedArtifacts.count
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.provenance.session.output.blockersUnresolved", defaultValue: "Blockers: %d - unresolved: %d"),
                outcome.blockers.count,
                outcome.unresolvedItems.count
            ),
        ]
    }

    private func provenanceSessionOutcomeResponsePayload(
        _ response: ProvenanceEngineContracts.ProvenanceSessionOutcomeResponse
    ) -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .secondsSince1970
        guard let data = try? encoder.encode(response),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [
                "found": false,
                "reason": "encoding_failed",
                "session_id": response.sessionID,
                "outcome": NSNull(),
            ]
        }
        return object
    }
}
