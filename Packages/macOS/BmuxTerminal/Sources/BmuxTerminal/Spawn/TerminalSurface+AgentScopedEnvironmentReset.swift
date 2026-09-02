extension TerminalSurface {
    private static let staleAgentScopedEnvironmentKeys: Set<String> = [
        "BMUX_AGENT_LAUNCH_ARGV_B64",
        "BMUX_AGENT_LAUNCH_CWD",
        "BMUX_AGENT_LAUNCH_EXECUTABLE",
        "BMUX_AGENT_LAUNCH_KIND",
        "BMUX_AGENT_SESSION_ID",
        "BMUX_CODEX_HOOK_BMUX_BIN",
        "BMUX_CODEX_PID",
        "BMUX_CODEX_SESSION_ID",
        "BMUX_DEBUG_LOG",
        "BMUX_TAG",
        "CLAUDE_CODE",
        "CLAUDE_CODE_ENTRYPOINT",
        "CLAUDE_CODE_SESSION_ID",
        "CLAUDECODE",
        "CODEX_CI",
        "CODEX_MANAGED_BY_BUN",
        "CODEX_SANDBOX",
        "CODEX_SESSION_ID",
        "CODEX_THREAD_ID",
        "OPENCODE",
        "OPENCODE_PORT",
        "OPENCODE_SESSION_ID"
    ]

    /// Clears per-agent runtime variables that must not leak into a fresh shell.
    public static func applyManagedAgentScopedEnvironmentReset(
        to environment: inout [String: String],
        protectedKeys: inout Set<String>
    ) {
        for key in staleAgentScopedEnvironmentKeys {
            environment[key] = ""
            protectedKeys.insert(key)
        }
    }
}
