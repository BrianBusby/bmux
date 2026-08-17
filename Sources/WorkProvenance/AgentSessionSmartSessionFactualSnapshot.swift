import Foundation
import ProvenanceEngineContracts

extension AgentSessionSmartSessionSnapshot {
    struct Factual: Equatable, Sendable {
        let latestTurn: Turn?
        let priorTurns: [TurnReference]
        let turnCount: Int

        init(factualProjection: ProvenanceFactualSessionProjectionSnapshot) {
            self.latestTurn = factualProjection.latestTurn.map(Turn.init(turnSnapshot:))
            self.priorTurns = factualProjection.priorTurns.map(TurnReference.init(reference:))
            self.turnCount = factualProjection.turns.count
        }

        var bridgePayload: [String: Any] {
            AgentSessionSmartSessionBridgeDictionary.compact([
                "latestTurn": AgentSessionSmartSessionBridgeDictionary.optional(latestTurn?.bridgePayload),
                "priorTurns": priorTurns.map(\.bridgePayload),
                "turnCount": turnCount
            ])
        }
    }

    struct Turn: Equatable, Sendable {
        let turnID: String
        let threadID: String?
        let provider: String
        let providerTurnID: String
        let status: String
        let model: String?
        let startedAt: Date?
        let completedAt: Date?
        let updatedAt: Date
        let prompt: Prompt?
        let plan: Plan?
        let completedCommands: [Command]
        let visibleReasoningSummaries: [ReasoningSummary]
        let fileChangeAttributions: [FileChangeAttribution]

        init(turnSnapshot: ProvenanceFactualSessionProjectionTurnSnapshot) {
            let turn = turnSnapshot.turn
            self.turnID = turn.id
            self.threadID = turn.threadID
            self.provider = turn.provider
            self.providerTurnID = turn.providerTurnID
            self.status = turn.status
            self.model = turn.model
            self.startedAt = turn.startedAt
            self.completedAt = turn.completedAt
            self.updatedAt = turn.updatedAt
            self.prompt = turnSnapshot.submittedPrompt.map(Prompt.init(record:))
            self.plan = turnSnapshot.currentPlan.map(Plan.init(record:))
            self.completedCommands = turnSnapshot.completedCommands.map(Command.init(record:))
            self.visibleReasoningSummaries = turnSnapshot.visibleReasoningSummaries.map(ReasoningSummary.init(record:))
            self.fileChangeAttributions = turnSnapshot.fileChangeAttributions.map(FileChangeAttribution.init(record:))
        }

        var bridgePayload: [String: Any] {
            AgentSessionSmartSessionBridgeDictionary.compact([
                "turnId": turnID,
                "threadId": AgentSessionSmartSessionBridgeDictionary.optional(threadID),
                "provider": provider,
                "providerTurnId": providerTurnID,
                "status": status,
                "model": AgentSessionSmartSessionBridgeDictionary.optional(model),
                "startedAt": AgentSessionSmartSessionBridgeDictionary.optional(
                    AgentSessionSmartSessionBridgeDictionary.isoString(startedAt)
                ),
                "completedAt": AgentSessionSmartSessionBridgeDictionary.optional(
                    AgentSessionSmartSessionBridgeDictionary.isoString(completedAt)
                ),
                "updatedAt": AgentSessionSmartSessionBridgeDictionary.requiredISOString(updatedAt),
                "prompt": AgentSessionSmartSessionBridgeDictionary.optional(prompt?.bridgePayload),
                "plan": AgentSessionSmartSessionBridgeDictionary.optional(plan?.bridgePayload),
                "completedCommands": completedCommands.map(\.bridgePayload),
                "visibleReasoningSummaries": visibleReasoningSummaries.map(\.bridgePayload),
                "fileChangeAttributions": fileChangeAttributions.map(\.bridgePayload)
            ])
        }
    }

    struct TurnReference: Equatable, Sendable {
        let turnID: String
        let threadID: String?
        let provider: String
        let providerTurnID: String
        let status: String
        let startedAt: Date?
        let completedAt: Date?
        let updatedAt: Date

        init(reference: ProvenanceFactualSessionProjectionTurnReference) {
            self.turnID = reference.turnID
            self.threadID = reference.threadID
            self.provider = reference.provider
            self.providerTurnID = reference.providerTurnID
            self.status = reference.status
            self.startedAt = reference.startedAt
            self.completedAt = reference.completedAt
            self.updatedAt = reference.updatedAt
        }

        var bridgePayload: [String: Any] {
            AgentSessionSmartSessionBridgeDictionary.compact([
                "turnId": turnID,
                "threadId": AgentSessionSmartSessionBridgeDictionary.optional(threadID),
                "provider": provider,
                "providerTurnId": providerTurnID,
                "status": status,
                "startedAt": AgentSessionSmartSessionBridgeDictionary.optional(
                    AgentSessionSmartSessionBridgeDictionary.isoString(startedAt)
                ),
                "completedAt": AgentSessionSmartSessionBridgeDictionary.optional(
                    AgentSessionSmartSessionBridgeDictionary.isoString(completedAt)
                ),
                "updatedAt": AgentSessionSmartSessionBridgeDictionary.requiredISOString(updatedAt)
            ])
        }
    }

    struct Prompt: Equatable, Sendable {
        let promptID: String
        let text: String
        let submittedAt: Date
        let source: String
        let confidence: String

        init(record: ProvenanceCodingAgentPromptRecord) {
            self.promptID = record.id
            self.text = record.text
            self.submittedAt = record.submittedAt
            self.source = record.source.rawValue
            self.confidence = record.confidence.rawValue
        }

        var bridgePayload: [String: Any] {
            [
                "promptId": promptID,
                "text": text,
                "submittedAt": AgentSessionSmartSessionBridgeDictionary.requiredISOString(submittedAt),
                "source": source,
                "confidence": confidence
            ]
        }
    }

    struct Plan: Equatable, Sendable {
        let planID: String
        let explanation: String?
        let observedAt: Date
        let source: String
        let confidence: String
        let steps: [PlanStep]

        init(record: ProvenanceCodingAgentPlanUpdateRecord) {
            self.planID = record.id
            self.explanation = record.explanation
            self.observedAt = record.observedAt
            self.source = record.source.rawValue
            self.confidence = record.confidence.rawValue
            self.steps = record.steps.sorted { $0.order < $1.order }.map(PlanStep.init(record:))
        }

        var bridgePayload: [String: Any] {
            AgentSessionSmartSessionBridgeDictionary.compact([
                "planId": planID,
                "explanation": AgentSessionSmartSessionBridgeDictionary.optional(explanation),
                "observedAt": AgentSessionSmartSessionBridgeDictionary.requiredISOString(observedAt),
                "source": source,
                "confidence": confidence,
                "steps": steps.map(\.bridgePayload)
            ])
        }
    }

    struct PlanStep: Equatable, Sendable {
        let stepID: String
        let order: Int
        let text: String
        let status: String

        init(record: ProvenanceCodingAgentPlanStepRecord) {
            self.stepID = record.id
            self.order = record.order
            self.text = record.text
            self.status = record.status
        }

        var bridgePayload: [String: Any] {
            [
                "stepId": stepID,
                "order": order,
                "text": text,
                "status": status
            ]
        }
    }
}
