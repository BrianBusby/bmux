import Foundation

extension AgentSessionWebRendererCoordinator {
    static var connectedChatCopy: [String: String] {
        [
            "chatTurnProgress": String(localized: "agentSession.chat.turnProgress", defaultValue: "Turn progress"),
            "chatNoPlanReported": String(localized: "agentSession.chat.noPlanReported", defaultValue: "No plan reported"),
            "chatPlanNotLoaded": String(localized: "agentSession.chat.planNotLoaded", defaultValue: "Plan data not loaded"),
            "chatPlanDone": String(localized: "agentSession.chat.planDone", defaultValue: "done"),
            "chatPlanActive": String(localized: "agentSession.chat.planActive", defaultValue: "In progress"),
            "chatPlanUpcoming": String(localized: "agentSession.chat.planUpcoming", defaultValue: "Upcoming"),
            "chatPlanBlocked": String(localized: "agentSession.chat.planBlocked", defaultValue: "Blocked"),
            "chatPlanSkipped": String(localized: "agentSession.chat.planSkipped", defaultValue: "Skipped"),
            "chatCurrentActivity": String(localized: "agentSession.chat.currentActivity", defaultValue: "Current activity"),
            "chatNoCommandRunning": String(localized: "agentSession.chat.noCommandRunning", defaultValue: "No command running"),
            "chatExitCode": String(localized: "agentSession.chat.exitCode", defaultValue: "exit"),
            "connectedPrompt": String(localized: "agentSession.chat.connectedPrompt", defaultValue: "Message Codex"),
            "connectedQueue": String(localized: "agentSession.chat.connectedQueue", defaultValue: "Send"),
            "connectedSteer": String(localized: "agentSession.chat.connectedSteer", defaultValue: "Steer current turn"),
            "connectedPending": String(localized: "agentSession.chat.connectedPending", defaultValue: "Awaiting provider acknowledgment…"),
            "connectedAccepted": String(localized: "agentSession.chat.connectedAccepted", defaultValue: "Accepted by Codex"),
            "connectedFailed": String(localized: "agentSession.chat.connectedFailed", defaultValue: "Not accepted. Your draft is preserved."),
            "connectedUncertain": String(localized: "agentSession.chat.connectedUncertain", defaultValue: "Delivery is uncertain. Check Terminal before sending again."),
            "connectedSlashCommands": String(localized: "agentSession.chat.connectedSlashCommands", defaultValue: "Use Terminal for Codex slash commands."),
            "connectedQueuePolicy": String(localized: "agentSession.chat.connectedQueuePolicy", defaultValue: "Follow-ups join the Codex queue. Terminal starts them after the current turn and owns queue editing, approvals, settings, and interruption."),
            "connectedUnavailable": String(localized: "agentSession.chat.connectedUnavailable", defaultValue: "The shared connection is unavailable. Continue in Terminal."),
            "connectedNewSession": String(localized: "agentSession.chat.connectedNewSession", defaultValue: "New connected Codex session"),
            "connectedStartFailed": String(localized: "agentSession.chat.connectedStartFailed", defaultValue: "Could not connect to Codex. Try again or continue in Terminal."),
        ]
    }
}
