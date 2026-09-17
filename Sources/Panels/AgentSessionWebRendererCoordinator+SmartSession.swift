import Foundation

extension AgentSessionWebRendererCoordinator {
    static var smartSessionCopy: [String: String] {
        [
            "chatLoading": String(localized: "agentSession.chat.chatLoading", defaultValue: "Loading conversation"),
            "chatInterrupted": String(localized: "agentSession.chat.chatInterrupted", defaultValue: "Turn interrupted"),
            "chatAmbiguous": String(localized: "agentSession.chat.chatAmbiguous", defaultValue: "Multiple session bindings · select the conversation in Terminal"),
            "chatObserved": String(localized: "agentSession.chat.chatObserved", defaultValue: "Observed transcript · turn state unavailable"),
            "chatEnded": String(localized: "agentSession.chat.chatEnded", defaultValue: "Session ended"),
            "chatStale": String(localized: "agentSession.chat.chatStale", defaultValue: "Refresh failed · showing cached history"),
            "chatUnavailable": String(localized: "agentSession.chat.chatUnavailable", defaultValue: "Conversation unavailable"),
            "chatInteract": String(localized: "agentSession.chat.chatInteract", defaultValue: "Interact in Terminal"),
            "chatConversation": String(localized: "agentSession.chat.chatConversation", defaultValue: "Conversation"),
            "chatPartial": String(localized: "agentSession.chat.chatPartial", defaultValue: "Partial history · showing the latest 500 messages. Earlier content is outside this view."),
            "chatReadOnly": String(localized: "agentSession.chat.chatReadOnly", defaultValue: "Read-only · no verified control connection to this CLI. Use Terminal for prompts, approvals, and interruption."),
            "chatUser": String(localized: "agentSession.chat.chatUser", defaultValue: "You"),
            "chatAssistant": String(localized: "agentSession.chat.chatAssistant", defaultValue: "Assistant"),
            "chatActivity": String(localized: "agentSession.chat.chatActivity", defaultValue: "Activity"),
            "chatFailed": String(localized: "agentSession.chat.chatFailed", defaultValue: "Failed"),
            "chatCompleted": String(localized: "agentSession.chat.chatCompleted", defaultValue: "Completed"),
            "chatAwaitingResult": String(localized: "agentSession.chat.chatAwaitingResult", defaultValue: "Awaiting result"),
            "chatUnknown": String(localized: "agentSession.chat.chatUnknown", defaultValue: "Status unknown"),
            "terminalView": String(
                localized: "agentSession.viewMode.chat",
                defaultValue: "Chat"
            ),
            "sessionView": String(
                localized: "agentSession.web.view.session",
                defaultValue: "Session"
            ),
            "smartSessionRefresh": String(
                localized: "agentSession.web.smartSession.refresh",
                defaultValue: "Refresh"
            ),
            "smartSessionLoading": String(
                localized: "agentSession.web.smartSession.loading",
                defaultValue: "Loading session"
            ),
            "smartSessionNoSession": String(
                localized: "agentSession.web.smartSession.noSession",
                defaultValue: "No linked session"
            ),
            "smartSessionUnavailable": String(
                localized: "agentSession.web.smartSession.unavailable",
                defaultValue: "Session data unavailable"
            ),
            "smartSessionNoSupportedAgent": String(
                localized: "agentSession.web.smartSession.noSupportedAgent",
                defaultValue: "No supported coding agent detected"
            ),
            "smartSessionAwaitingFirstPrompt": String(
                localized: "agentSession.web.smartSession.awaitingFirstPrompt",
                defaultValue: "Coding agent detected. Waiting for a prompt."
            ),
            "smartSessionAssociationPending": String(
                localized: "agentSession.web.smartSession.associationPending",
                defaultValue: "Prompt observed. Linking session."
            ),
            "smartSessionProjectionPending": String(
                localized: "agentSession.web.smartSession.projectionPending",
                defaultValue: "Session linked. Building facts."
            ),
            "smartSessionIngestionFailed": String(
                localized: "agentSession.web.smartSession.ingestionFailed",
                defaultValue: "Session evidence ingestion failed"
            ),
            "smartSessionIdentityReconciliationFailed": String(
                localized: "agentSession.web.smartSession.identityReconciliationFailed",
                defaultValue: "Could not reconcile session identity"
            ),
            "smartSessionProjectionFailed": String(
                localized: "agentSession.web.smartSession.projectionFailed",
                defaultValue: "Could not read session facts"
            ),
            "smartSessionUnsupportedOrUnassociated": String(
                localized: "agentSession.web.smartSession.unsupportedOrUnassociated",
                defaultValue: "No associated supported session"
            ),
            "smartSessionNotFound": String(
                localized: "agentSession.web.smartSession.notFound",
                defaultValue: "Session not found"
            ),
            "smartSessionFailed": String(
                localized: "agentSession.web.smartSession.failed",
                defaultValue: "Session refresh failed"
            ),
            "smartSessionUnknown": String(
                localized: "agentSession.web.smartSession.unknown",
                defaultValue: "Unknown"
            ),
            "smartSessionIdentity": String(
                localized: "agentSession.web.smartSession.identity",
                defaultValue: "Identity"
            ),
            "smartSessionPurpose": String(
                localized: "agentSession.web.smartSession.purpose",
                defaultValue: "Purpose"
            ),
            "smartSessionCurrentTurn": String(
                localized: "agentSession.web.smartSession.currentTurn",
                defaultValue: "Current turn"
            ),
            "smartSessionCurrentActivity": String(
                localized: "agentSession.web.smartSession.currentActivity",
                defaultValue: "Current activity"
            ),
            "smartSessionPhase": String(
                localized: "agentSession.web.smartSession.phase",
                defaultValue: "Phase"
            ),
            "smartSessionPrompt": String(
                localized: "agentSession.web.smartSession.prompt",
                defaultValue: "Prompt"
            ),
            "smartSessionPlan": String(
                localized: "agentSession.web.smartSession.plan",
                defaultValue: "Plan"
            ),
            "smartSessionEvidence": String(
                localized: "agentSession.web.smartSession.evidence",
                defaultValue: "Evidence"
            ),
            "smartSessionCommands": String(
                localized: "agentSession.web.smartSession.commands",
                defaultValue: "Commands"
            ),
            "smartSessionFiles": String(
                localized: "agentSession.web.smartSession.files",
                defaultValue: "Files"
            ),
            "smartSessionReasoning": String(
                localized: "agentSession.web.smartSession.reasoning",
                defaultValue: "Reasoning"
            ),
            "smartSessionFinalOutput": String(
                localized: "agentSession.web.smartSession.finalOutput",
                defaultValue: "Final output"
            ),
            "smartSessionPriorTurns": String(
                localized: "agentSession.web.smartSession.priorTurns",
                defaultValue: "Prior turns"
            ),
            "smartSessionNoPlan": String(
                localized: "agentSession.web.smartSession.noPlan",
                defaultValue: "No plan evidence"
            ),
            "smartSessionNoEvidence": String(
                localized: "agentSession.web.smartSession.noEvidence",
                defaultValue: "No evidence yet"
            ),
            "smartSessionSessionID": String(
                localized: "agentSession.web.smartSession.sessionID",
                defaultValue: "Session ID"
            ),
            "smartSessionRevision": String(
                localized: "agentSession.web.smartSession.revision",
                defaultValue: "Revision"
            ),
            "smartSessionThread": String(
                localized: "agentSession.web.smartSession.thread",
                defaultValue: "Thread"
            ),
            "smartSessionTurn": String(
                localized: "agentSession.web.smartSession.turn",
                defaultValue: "Turn"
            )
        ]
    }
}
