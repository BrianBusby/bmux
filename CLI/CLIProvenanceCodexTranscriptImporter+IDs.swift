import Foundation
import ProvenanceEngineContracts

extension CLIProvenanceCodexTranscriptImporter {
    func threadRecordID(providerThreadID: String) -> String {
        stableIDFactory.id(prefix: "coding-agent-thread", value: "codex\n\(providerThreadID)")
    }

    func turnRecordID(providerTurnID: String) -> String {
        stableIDFactory.id(prefix: "coding-agent-turn", value: "codex\n\(providerTurnID)")
    }

    func externalIdentity(
        sessionID: String,
        kind: String,
        externalID: String,
        observedAt: Date
    ) -> ProvenanceExternalIdentityRecord {
        ProvenanceExternalIdentityRecord(
            id: stableIDFactory.id(prefix: "identity", value: "\(sessionID)\ncodex\n\(kind)\n\(externalID)"),
            sessionID: sessionID,
            system: "codex",
            kind: kind,
            externalID: externalID,
            source: .observed,
            confidence: .high,
            createdAt: observedAt,
            updatedAt: observedAt
        )
    }

    func eventID(sessionID: String, line: TranscriptLine, kind: String) -> String {
        stableIDFactory.id(
            prefix: "event",
            value: "codex-transcript\n\(sessionID)\n\(line.ordinal ?? line.lineNumber)\n\(kind)"
        )
    }

    func recordID(
        prefix: String,
        sessionID: String,
        line: TranscriptLine,
        discriminator: String? = nil
    ) -> String {
        stableIDFactory.id(
            prefix: prefix,
            value: "codex-transcript\n\(sessionID)\n\(line.ordinal ?? line.lineNumber)\n\(discriminator ?? "")"
        )
    }
}
