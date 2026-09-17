extension AppDelegate {
    var agentChatTranscriptService: AgentChatTranscriptService { agentChatApplicationRuntime.transcript }

    func configureSessionPresentation(_ tabManager: TabManager) {
        tabManager.terminalChatReader = agentChatApplicationRuntime.terminal
        tabManager.workProvenanceRuntime = workProvenanceRuntime
    }
}
