import Foundation

struct RepoAgentLauncherParameterCatalog {
    func definitions(for agent: BmuxConfigAgentKind) -> [RepoAgentLauncherParameterDefinition] {
        switch agent {
        case .codex:
            return codexDefinitions()
        case .claudeCode:
            return claudeDefinitions()
        case .opencode, .custom:
            return []
        }
    }

    private func codexDefinitions() -> [RepoAgentLauncherParameterDefinition] {
        [
            definition(
                .codex,
                "--add-dir",
                "parameter.repoAgentLauncher.codex.addDir",
                "Extra writable dir.",
                .text(placeholder: "/path/to/dir")
            ),
            definition(
                .codex,
                "--ask-for-approval",
                "parameter.repoAgentLauncher.codex.askForApproval",
                "Approval policy.",
                .choice([
                    option("on-request"),
                    option("untrusted"),
                    option("never"),
                ])
            ),
            definition(
                .codex,
                "--config",
                "parameter.repoAgentLauncher.codex.config",
                "Config override.",
                .text(placeholder: "model=\"gpt-5\"")
            ),
            definition(
                .codex,
                "--dangerously-bypass-approvals-and-sandbox",
                "parameter.repoAgentLauncher.codex.dangerouslyBypass",
                "No prompts or sandbox.",
                .none
            ),
            definition(
                .codex,
                "--model",
                "parameter.repoAgentLauncher.codex.model",
                "Model name.",
                .text(placeholder: "gpt-5")
            ),
            definition(
                .codex,
                "--sandbox",
                "parameter.repoAgentLauncher.codex.sandbox",
                "Sandbox mode.",
                .choice([
                    option("workspace-write"),
                    option("read-only"),
                    option("danger-full-access"),
                ])
            ),
        ].sorted { $0.flag.localizedStandardCompare($1.flag) == .orderedAscending }
    }

    private func claudeDefinitions() -> [RepoAgentLauncherParameterDefinition] {
        [
            definition(
                .claudeCode,
                "--add-dir",
                "parameter.repoAgentLauncher.claude.addDir",
                "Extra tool dir.",
                .text(placeholder: "/path/to/dir")
            ),
            definition(
                .claudeCode,
                "--allowed-tools",
                "parameter.repoAgentLauncher.claude.allowedTools",
                "Allowed tools.",
                .text(placeholder: "Bash,Edit")
            ),
            definition(
                .claudeCode,
                "--dangerously-skip-permissions",
                "parameter.repoAgentLauncher.claude.dangerouslySkip",
                "Bypass permissions.",
                .none
            ),
            definition(
                .claudeCode,
                "--effort",
                "parameter.repoAgentLauncher.claude.effort",
                "Effort level.",
                .choice([
                    option("low"),
                    option("medium"),
                    option("high"),
                    option("xhigh"),
                    option("max"),
                ])
            ),
            definition(
                .claudeCode,
                "--model",
                "parameter.repoAgentLauncher.claude.model",
                "Model alias.",
                .text(placeholder: "sonnet")
            ),
            definition(
                .claudeCode,
                "--permission-mode",
                "parameter.repoAgentLauncher.claude.permissionMode",
                "Permission mode.",
                .choice([
                    option("acceptEdits"),
                    option("auto"),
                    option("bypassPermissions"),
                    option("manual"),
                    option("dontAsk"),
                    option("plan"),
                ])
            ),
            definition(
                .claudeCode,
                "--safe-mode",
                "parameter.repoAgentLauncher.claude.safeMode",
                "Disable customizations.",
                .none
            ),
        ].sorted { $0.flag.localizedStandardCompare($1.flag) == .orderedAscending }
    }

    private func definition(
        _ agent: BmuxConfigAgentKind,
        _ flag: String,
        _ key: String,
        _ defaultValue: String,
        _ valueKind: RepoAgentLauncherParameterValueKind
    ) -> RepoAgentLauncherParameterDefinition {
        RepoAgentLauncherParameterDefinition(
            agent: agent,
            flag: flag,
            comment: localizedComment(key, defaultValue: defaultValue),
            valueKind: valueKind
        )
    }

    private func option(_ value: String) -> RepoAgentLauncherParameterOption {
        RepoAgentLauncherParameterOption(value: value, label: value)
    }

    private func localizedComment(_ key: String, defaultValue: String) -> String {
        switch key {
        case "parameter.repoAgentLauncher.codex.addDir":
            return String(localized: "parameter.repoAgentLauncher.codex.addDir", defaultValue: "Extra writable dir.")
        case "parameter.repoAgentLauncher.codex.askForApproval":
            return String(localized: "parameter.repoAgentLauncher.codex.askForApproval", defaultValue: "Approval policy.")
        case "parameter.repoAgentLauncher.codex.config":
            return String(localized: "parameter.repoAgentLauncher.codex.config", defaultValue: "Config override.")
        case "parameter.repoAgentLauncher.codex.dangerouslyBypass":
            return String(localized: "parameter.repoAgentLauncher.codex.dangerouslyBypass", defaultValue: "No prompts or sandbox.")
        case "parameter.repoAgentLauncher.codex.model":
            return String(localized: "parameter.repoAgentLauncher.codex.model", defaultValue: "Model name.")
        case "parameter.repoAgentLauncher.codex.sandbox":
            return String(localized: "parameter.repoAgentLauncher.codex.sandbox", defaultValue: "Sandbox mode.")
        case "parameter.repoAgentLauncher.claude.addDir":
            return String(localized: "parameter.repoAgentLauncher.claude.addDir", defaultValue: "Extra tool dir.")
        case "parameter.repoAgentLauncher.claude.allowedTools":
            return String(localized: "parameter.repoAgentLauncher.claude.allowedTools", defaultValue: "Allowed tools.")
        case "parameter.repoAgentLauncher.claude.dangerouslySkip":
            return String(localized: "parameter.repoAgentLauncher.claude.dangerouslySkip", defaultValue: "Bypass permissions.")
        case "parameter.repoAgentLauncher.claude.effort":
            return String(localized: "parameter.repoAgentLauncher.claude.effort", defaultValue: "Effort level.")
        case "parameter.repoAgentLauncher.claude.model":
            return String(localized: "parameter.repoAgentLauncher.claude.model", defaultValue: "Model alias.")
        case "parameter.repoAgentLauncher.claude.permissionMode":
            return String(localized: "parameter.repoAgentLauncher.claude.permissionMode", defaultValue: "Permission mode.")
        case "parameter.repoAgentLauncher.claude.safeMode":
            return String(localized: "parameter.repoAgentLauncher.claude.safeMode", defaultValue: "Disable customizations.")
        default:
            return defaultValue
        }
    }
}
