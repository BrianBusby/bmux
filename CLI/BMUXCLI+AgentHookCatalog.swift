import Foundation

extension BMUXCLI {
    // MARK: Agent definitions

    static let agentDefs: [AgentHookDef] = [
        AgentHookDef(
            name: "codex", displayName: "Codex", statusKey: "codex",
            configDir: ".codex", configFile: "hooks.json", configDirEnvOverride: "CODEX_HOME",
            sessionStoreSuffix: "codex", disableEnvVar: "BMUX_CODEX_HOOKS_DISABLED",
            hookMarker: "bmux hooks codex", format: .nested(timeoutMs: 5),
            events: [
                .init(agentEvent: "SessionStart", bmuxSubcommand: "session-start"),
                .init(agentEvent: "UserPromptSubmit", bmuxSubcommand: "prompt-submit"),
                .init(agentEvent: "Stop", bmuxSubcommand: "stop"),
            ],
            feedHookEvents: [
                "PreToolUse",
                "PermissionRequest",
                "PostToolUse",
                "PreCompact",
                "PostCompact",
                "SubagentStart",
                "SubagentStop",
            ],
            postInstallAction: .codexConfigToml
        ),
        AgentHookDef(
            name: "grok", displayName: "Grok", statusKey: "grok",
            configDir: ".grok/hooks", configFile: "bmux-session.json",
            configDirEnvOverride: "GROK_HOME", configDirEnvOverrideSubpath: "hooks",
            createConfigDirIfMissing: true,
            sessionStoreSuffix: "grok", disableEnvVar: "BMUX_GROK_HOOKS_DISABLED",
            hookMarker: "bmux hooks grok", format: .nested(timeoutMs: 5000),
            events: [
                .init(agentEvent: "SessionStart", bmuxSubcommand: "session-start"),
                .init(agentEvent: "UserPromptSubmit", bmuxSubcommand: "prompt-submit"),
                .init(agentEvent: "Stop", bmuxSubcommand: "stop"),
                .init(agentEvent: "Notification", bmuxSubcommand: "notification"),
                .init(agentEvent: "SessionEnd", bmuxSubcommand: "session-end"),
            ],
            publishesStopNotification: false,
            sessionEndIsTurnBoundary: true,
            feedHookEvents: ["PreToolUse"]
        ),
        AgentHookDef(
            name: "opencode", displayName: "OpenCode", statusKey: "opencode",
            configDir: ".config/opencode", configFile: "plugins/bmux-session.js", configDirEnvOverride: "OPENCODE_CONFIG_DIR",
            sessionStoreSuffix: "opencode", disableEnvVar: "BMUX_OPENCODE_HOOKS_DISABLED",
            hookMarker: "bmux hooks opencode", format: .flat,
            events: []
        ),
        AgentHookDef(
            name: "pi", displayName: "Pi", statusKey: "pi",
            configDir: ".pi/agent", configFile: "extensions/bmux-session.ts", configDirEnvOverride: "PI_CODING_AGENT_DIR",
            sessionStoreSuffix: "pi", disableEnvVar: "BMUX_PI_HOOKS_DISABLED",
            hookMarker: "bmux hooks pi", format: .flat,
            events: []
        ),
        AgentHookDef(
            name: "omp", displayName: "OMP", statusKey: "omp",
            configDir: ".omp/agent", configFile: "extensions/bmux-omp-session.ts",
            createConfigDirIfMissing: true,
            configDirResolver: { BMUXCLI.resolvedOmpAgentDirectory().path },
            sessionStoreSuffix: "omp", disableEnvVar: "BMUX_OMP_HOOKS_DISABLED",
            hookMarker: "bmux hooks omp", format: .flat,
            events: []
        ),
        AgentHookDef(
            name: "amp", displayName: "Amp", statusKey: "amp",
            configDir: ".config/amp", configFile: "plugins/bmux-session.ts",
            sessionStoreSuffix: "amp", disableEnvVar: "BMUX_AMP_HOOKS_DISABLED",
            hookMarker: "bmux hooks amp", format: .flat,
            events: []
        ),
        AgentHookDef(
            name: "cursor", displayName: "Cursor", statusKey: "cursor",
            configDir: ".cursor", configFile: "hooks.json", binaryName: "cursor-agent",
            sessionStoreSuffix: "cursor", disableEnvVar: "BMUX_CURSOR_HOOKS_DISABLED",
            hookMarker: "bmux hooks cursor", format: .flat,
            events: [
                .init(agentEvent: "beforeSubmitPrompt", bmuxSubcommand: "prompt-submit"),
                .init(agentEvent: "stop", bmuxSubcommand: "stop"),
                .init(agentEvent: "afterAgentResponse", bmuxSubcommand: "agent-response"),
                .init(agentEvent: "beforeShellExecution", bmuxSubcommand: "shell-exec"),
                .init(agentEvent: "afterShellExecution", bmuxSubcommand: "shell-done"),
            ],
            feedHookEvents: ["beforeShellExecution"]
        ),
        AgentHookDef(
            name: "gemini", displayName: "Gemini", statusKey: "gemini",
            configDir: ".gemini", configFile: "settings.json",
            sessionStoreSuffix: "gemini", disableEnvVar: "BMUX_GEMINI_HOOKS_DISABLED",
            hookMarker: "bmux hooks gemini", format: .nested(timeoutMs: 10000),
            events: [
                .init(agentEvent: "SessionStart", bmuxSubcommand: "session-start"),
                .init(agentEvent: "BeforeAgent", bmuxSubcommand: "prompt-submit"),
                .init(agentEvent: "AfterAgent", bmuxSubcommand: "stop"),
                .init(agentEvent: "SessionEnd", bmuxSubcommand: "session-end"),
            ],
            feedHookEvents: ["PreToolUse"]
        ),
        AgentHookDef(
            name: "kiro", displayName: "Kiro", statusKey: "kiro",
            configDir: ".kiro/agents", configFile: "bmux.json",
            configDirEnvOverride: "KIRO_HOME", configDirEnvOverrideSubpath: "agents",
            createConfigDirIfMissing: true, binaryName: "kiro-cli",
            sessionStoreSuffix: "kiro", disableEnvVar: "BMUX_KIRO_HOOKS_DISABLED",
            hookMarker: "bmux hooks kiro", format: .kiroAgentJSON(timeoutMs: 5000),
            events: [
                .init(agentEvent: "agentSpawn", bmuxSubcommand: "session-start"),
                .init(agentEvent: "userPromptSubmit", bmuxSubcommand: "prompt-submit"),
                .init(agentEvent: "stop", bmuxSubcommand: "stop"),
            ],
            feedHookEvents: ["preToolUse", "postToolUse"],
            postInstallNote: String(
                localized: "cli.hooks.kiro.postInstallNote",
                defaultValue: "Kiro applies these hooks only when run as the bmux agent. Start Kiro with `kiro-cli chat --agent bmux`, or make it the default with `kiro-cli settings chat.defaultAgent bmux`."
            )
        ),
        AgentHookDef(
            name: "antigravity", displayName: "Antigravity", statusKey: "antigravity",
            configDir: ".gemini/config", configFile: "hooks.json",
            createConfigDirIfMissing: true, binaryName: "agy",
            sessionStoreSuffix: "antigravity", disableEnvVar: "BMUX_ANTIGRAVITY_HOOKS_DISABLED",
            hookMarker: "bmux hooks antigravity", format: .antigravityJSON(timeoutSeconds: 10),
            events: [
                .init(agentEvent: "SessionStart", bmuxSubcommand: "session-start"),
                .init(agentEvent: "PreInvocation", bmuxSubcommand: "prompt-submit"),
                .init(agentEvent: "Stop", bmuxSubcommand: "stop"),
                .init(agentEvent: "turn-completion", bmuxSubcommand: "stop"),
                .init(agentEvent: "Notification", bmuxSubcommand: "notification"),
                .init(agentEvent: "SessionEnd", bmuxSubcommand: "session-end"),
            ],
            aliases: ["agy"],
            sessionEndIsTurnBoundary: true,
            feedHookEvents: ["PreToolUse", "PostToolUse"]
        ),
        AgentHookDef(
            name: "rovodev", displayName: "Rovo Dev", statusKey: "rovodev",
            configDir: ".rovodev", configFile: "config.yml", binaryName: "acli",
            sessionStoreSuffix: "rovodev", disableEnvVar: "BMUX_ROVODEV_HOOKS_DISABLED",
            hookMarker: "bmux hooks rovodev", format: .rovoDevYAML,
            events: [
                .init(agentEvent: "on_complete", bmuxSubcommand: "stop"),
                .init(agentEvent: "on_error", bmuxSubcommand: "stop"),
                .init(agentEvent: "on_tool_permission", bmuxSubcommand: "prompt-submit"),
            ],
            aliases: ["rovo"]
        ),
        AgentHookDef(
            name: "hermes-agent", displayName: "Hermes Agent", statusKey: "hermes-agent",
            configDir: ".hermes", configFile: "config.yaml", configDirEnvOverride: "HERMES_HOME",
            binaryName: "hermes",
            sessionStoreSuffix: "hermes-agent", disableEnvVar: "BMUX_HERMES_AGENT_HOOKS_DISABLED",
            hookMarker: "bmux hooks hermes-agent", format: .hermesAgentYAML,
            events: [
                .init(agentEvent: "on_session_start", bmuxSubcommand: "session-start"),
                .init(agentEvent: "pre_llm_call", bmuxSubcommand: "prompt-submit"),
                .init(agentEvent: "post_llm_call", bmuxSubcommand: "agent-response"),
                .init(agentEvent: "pre_approval_request", bmuxSubcommand: "notification"),
                .init(agentEvent: "post_approval_response", bmuxSubcommand: "approval-response"),
                .init(agentEvent: "on_session_end", bmuxSubcommand: "session-end"),
                .init(agentEvent: "on_session_finalize", bmuxSubcommand: "session-finalize"),
                .init(agentEvent: "on_session_reset", bmuxSubcommand: "session-start"),
            ],
            sessionEndIsTurnBoundary: true,
            feedHookEvents: ["pre_tool_call", "post_tool_call", "pre_approval_request", "post_approval_response"]
        ),
        AgentHookDef(
            name: "copilot", displayName: "Copilot", statusKey: "copilot",
            configDir: ".copilot", configFile: "config.json", configDirEnvOverride: "COPILOT_HOME",
            sessionStoreSuffix: "copilot", disableEnvVar: "BMUX_COPILOT_HOOKS_DISABLED",
            hookMarker: "bmux hooks copilot", format: .nested(timeoutMs: 5000),
            events: [
                .init(agentEvent: "SessionStart", bmuxSubcommand: "session-start"),
                .init(agentEvent: "Stop", bmuxSubcommand: "stop"),
                .init(agentEvent: "Notification", bmuxSubcommand: "stop"),
                .init(agentEvent: "SessionEnd", bmuxSubcommand: "session-end"),
            ],
            feedHookEvents: ["PreToolUse"]
        ),
        AgentHookDef(
            name: "codebuddy", displayName: "CodeBuddy", statusKey: "codebuddy",
            configDir: ".codebuddy", configFile: "settings.json", configDirEnvOverride: "CODEBUDDY_CONFIG_DIR",
            sessionStoreSuffix: "codebuddy", disableEnvVar: "BMUX_CODEBUDDY_HOOKS_DISABLED",
            hookMarker: "bmux hooks codebuddy", format: .nested(timeoutMs: 5000),
            events: [
                .init(agentEvent: "SessionStart", bmuxSubcommand: "session-start"),
                .init(agentEvent: "Stop", bmuxSubcommand: "stop"),
                .init(agentEvent: "Notification", bmuxSubcommand: "stop"),
                .init(agentEvent: "SessionEnd", bmuxSubcommand: "session-end"),
            ],
            feedHookEvents: ["PreToolUse"]
        ),
        AgentHookDef(
            name: "factory", displayName: "Factory", statusKey: "factory",
            configDir: ".factory", configFile: "settings.json", binaryName: "droid",
            sessionStoreSuffix: "factory", disableEnvVar: "BMUX_FACTORY_HOOKS_DISABLED",
            hookMarker: "bmux hooks factory", format: .nested(timeoutMs: 5000),
            events: [
                .init(agentEvent: "SessionStart", bmuxSubcommand: "session-start"),
                .init(agentEvent: "Stop", bmuxSubcommand: "stop"),
                .init(agentEvent: "Notification", bmuxSubcommand: "stop"),
                .init(agentEvent: "SessionEnd", bmuxSubcommand: "session-end"),
            ],
            feedHookEvents: ["PreToolUse"]
        ),
        AgentHookDef(
            name: "qoder", displayName: "Qoder", statusKey: "qoder",
            configDir: ".qoder", configFile: "settings.json", configDirEnvOverride: "QODER_CONFIG_DIR", binaryName: "qodercli",
            sessionStoreSuffix: "qoder", disableEnvVar: "BMUX_QODER_HOOKS_DISABLED",
            hookMarker: "bmux hooks qoder", format: .nested(timeoutMs: 5000),
            events: [
                .init(agentEvent: "SessionStart", bmuxSubcommand: "session-start"),
                .init(agentEvent: "Stop", bmuxSubcommand: "stop"),
                .init(agentEvent: "SessionEnd", bmuxSubcommand: "session-end"),
            ],
            feedHookEvents: ["PreToolUse"]
        ),
        AgentHookDef(
            name: "kimi", displayName: "Kimi Code", statusKey: "kimi",
            configDir: ".kimi-code", configFile: "config.toml", configDirEnvOverride: "KIMI_CODE_HOME",
            binaryName: "kimi",
            sessionStoreSuffix: "kimi", disableEnvVar: "BMUX_KIMI_HOOKS_DISABLED",
            hookMarker: "bmux hooks kimi", format: .tomlArrayTable,
            events: [
                .init(agentEvent: "SessionStart", bmuxSubcommand: "session-start"),
                .init(agentEvent: "UserPromptSubmit", bmuxSubcommand: "prompt-submit"),
                .init(agentEvent: "PermissionRequest", bmuxSubcommand: "notification"),
                .init(agentEvent: "Stop", bmuxSubcommand: "stop"),
                .init(agentEvent: "StopFailure", bmuxSubcommand: "notification"),
                .init(agentEvent: "Interrupt", bmuxSubcommand: "stop"),
                .init(agentEvent: "SessionEnd", bmuxSubcommand: "session-end"),
            ],
            feedHookEvents: ["PreToolUse", "PostToolUse", "PermissionRequest"]
        ),
    ]

    static func agentDef(named name: String) -> AgentHookDef? {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return agentDefs.first { $0.name == normalized || $0.aliases.contains(normalized) }
    }
}
