import Foundation
import ProvenanceEngineContracts

extension AgentSessionSmartSessionSnapshot {
    struct Command: Equatable, Sendable {
        let commandID: String
        let command: String
        let cwd: String?
        let status: String
        let exitCode: Int?
        let outputSummary: String?
        let startedAt: Date?
        let completedAt: Date
        let source: String
        let confidence: String

        init(record: ProvenanceCodingAgentCommandRecord) {
            self.commandID = record.id
            self.command = record.command
            self.cwd = record.cwd
            self.status = record.status
            self.exitCode = record.exitCode
            self.outputSummary = record.outputSummary
            self.startedAt = record.startedAt
            self.completedAt = record.completedAt
            self.source = record.source.rawValue
            self.confidence = record.confidence.rawValue
        }

        var bridgePayload: [String: Any] {
            AgentSessionSmartSessionBridgeDictionary.compact([
                "commandId": commandID,
                "command": command,
                "cwd": cwd,
                "status": status,
                "exitCode": exitCode,
                "outputSummary": outputSummary,
                "startedAt": AgentSessionSmartSessionBridgeDictionary.isoString(startedAt),
                "completedAt": AgentSessionSmartSessionBridgeDictionary.isoString(completedAt),
                "source": source,
                "confidence": confidence
            ])
        }
    }

    struct ReasoningSummary: Equatable, Sendable {
        let summaryID: String
        let text: String
        let completedAt: Date
        let source: String
        let confidence: String

        init(record: ProvenanceCodingAgentReasoningSummaryRecord) {
            self.summaryID = record.id
            self.text = record.text
            self.completedAt = record.completedAt
            self.source = record.source.rawValue
            self.confidence = record.confidence.rawValue
        }

        var bridgePayload: [String: Any] {
            [
                "summaryId": summaryID,
                "text": text,
                "completedAt": AgentSessionSmartSessionBridgeDictionary.isoString(completedAt),
                "source": source,
                "confidence": confidence
            ]
        }
    }

    struct FileChangeAttribution: Equatable, Sendable {
        let attributionID: String
        let paths: [String]
        let summary: String?
        let observedAt: Date
        let source: String
        let confidence: String

        init(record: ProvenanceCodingAgentFileChangeAttributionRecord) {
            self.attributionID = record.id
            self.paths = record.paths
            self.summary = record.summary
            self.observedAt = record.observedAt
            self.source = record.source.rawValue
            self.confidence = record.confidence.rawValue
        }

        var bridgePayload: [String: Any] {
            AgentSessionSmartSessionBridgeDictionary.compact([
                "attributionId": attributionID,
                "paths": paths,
                "summary": summary,
                "observedAt": AgentSessionSmartSessionBridgeDictionary.isoString(observedAt),
                "source": source,
                "confidence": confidence
            ])
        }
    }

    struct SemanticMessage: Equatable, Sendable {
        let messageID: String
        let semanticInferenceID: String
        let semanticInferenceKind: String
        let scope: String
        let scopeID: String
        let concisePhrase: String
        let expandedMeaning: String
        let supportingFactualRevision: Int?
        let confidence: String
        let specificity: String
        let presentationProducerID: String
        let presentationProducerVersion: String
        let presentationPolicyID: String
        let presentationPolicyVersion: String
        let localeIdentifier: String?
        let createdAt: Date
        let status: String

        init(record: ProvenanceSemanticMessageRecord) {
            self.messageID = record.id
            self.semanticInferenceID = record.semanticInferenceID
            self.semanticInferenceKind = record.semanticInferenceKind
            self.scope = record.scope.rawValue
            self.scopeID = record.scopeID
            self.concisePhrase = record.concisePhrase
            self.expandedMeaning = record.expandedMeaning
            self.supportingFactualRevision = record.supportingFactualRevision
            self.confidence = record.confidence.rawValue
            self.specificity = record.specificity.rawValue
            self.presentationProducerID = record.presentationProducerID
            self.presentationProducerVersion = record.presentationProducerVersion
            self.presentationPolicyID = record.presentationPolicyID
            self.presentationPolicyVersion = record.presentationPolicyVersion
            self.localeIdentifier = record.localeIdentifier
            self.createdAt = record.createdAt
            self.status = record.status.rawValue
        }

        var bridgePayload: [String: Any] {
            AgentSessionSmartSessionBridgeDictionary.compact([
                "messageId": messageID,
                "semanticInferenceId": semanticInferenceID,
                "semanticInferenceKind": semanticInferenceKind,
                "scope": scope,
                "scopeId": scopeID,
                "concisePhrase": concisePhrase,
                "expandedMeaning": expandedMeaning,
                "supportingFactualRevision": supportingFactualRevision,
                "confidence": confidence,
                "specificity": specificity,
                "presentationProducerId": presentationProducerID,
                "presentationProducerVersion": presentationProducerVersion,
                "presentationPolicyId": presentationPolicyID,
                "presentationPolicyVersion": presentationPolicyVersion,
                "localeIdentifier": localeIdentifier,
                "createdAt": AgentSessionSmartSessionBridgeDictionary.isoString(createdAt),
                "status": status
            ])
        }
    }
}
