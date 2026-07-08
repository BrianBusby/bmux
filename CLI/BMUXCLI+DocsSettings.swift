import Foundation

extension BMUXCLI {
    static let settingsDocsURL = "https://bmux.com/docs/configuration#bmux-json"
    static let settingsSchemaURL = "https://raw.githubusercontent.com/manaflow-ai/bmux/main/web/data/bmux.schema.json"
    static let primarySettingsDisplayPath = "~/.config/bmux/bmux.json"
    static let legacySettingsDisplayPath = "~/.config/bmux/settings.json"
    static let fallbackSettingsDisplayPath = "~/Library/Application Support/com.bmuxterm.app/settings.json"
    static let ghosttyConfigDisplayPath = "~/.config/ghostty/config"

    private struct DocsResource {
        let label: String
        let url: String
    }

    private struct DocsReference {
        let topic: String
        let aliases: [String]
        let summary: String
        let webURL: String
        let rawResources: [DocsResource]
        let commands: [String]
    }

    private static let docsReferences: [DocsReference] = [
        DocsReference(
            topic: "settings",
            aliases: ["configuration", "config", "bmux-json", "settings-json", "settingsjson", "schema"],
            summary: "bmux-owned settings, bmux.json locations, schema, and reload flow.",
            webURL: settingsDocsURL,
            rawResources: [
                DocsResource(label: "settings schema", url: settingsSchemaURL),
                DocsResource(label: "bmux skill", url: "https://raw.githubusercontent.com/manaflow-ai/bmux/main/skills/bmux/SKILL.md"),
            ],
            commands: [
                "bmux settings path",
                "bmux settings bmux-json",
                "bmux config doctor",
                "bmux reload-config",
            ]
        ),
        DocsReference(
            topic: "shortcuts",
            aliases: ["keyboard", "keybindings", "keys"],
            summary: "bmux-owned keyboard shortcuts and two-step chord syntax.",
            webURL: "https://bmux.com/docs/keyboard-shortcuts",
            rawResources: [
                DocsResource(label: "shortcut data", url: "https://raw.githubusercontent.com/manaflow-ai/bmux/main/web/data/bmux-shortcuts.ts"),
                DocsResource(label: "settings schema", url: settingsSchemaURL),
            ],
            commands: [
                "bmux shortcuts",
                "bmux settings shortcuts",
                "bmux docs settings",
            ]
        ),
        DocsReference(
            topic: "api",
            aliases: ["cli", "socket", "automation", "handles"],
            summary: "CLI/socket API, handle model, windows, workspaces, panes, and surfaces.",
            webURL: "https://bmux.com/docs/api",
            rawResources: [
                DocsResource(label: "CLI contract", url: "https://raw.githubusercontent.com/manaflow-ai/bmux/main/docs/cli-contract.md"),
                DocsResource(label: "bmux skill", url: "https://raw.githubusercontent.com/manaflow-ai/bmux/main/skills/bmux/SKILL.md"),
            ],
            commands: [
                "bmux identify --json",
                "bmux tree --all",
            ]
        ),
        DocsReference(
            topic: "browser",
            aliases: ["browser-automation", "webview"],
            summary: "Browser panel automation commands and snapshot-driven web interaction.",
            webURL: "https://bmux.com/docs/browser-automation",
            rawResources: [
                DocsResource(label: "browser skill", url: "https://raw.githubusercontent.com/manaflow-ai/bmux/main/skills/bmux-browser/SKILL.md"),
                DocsResource(label: "browser commands", url: "https://raw.githubusercontent.com/manaflow-ai/bmux/main/skills/bmux-browser/references/commands.md"),
            ],
            commands: [
                "bmux browser --help",
                "bmux browser snapshot",
            ]
        ),
        DocsReference(
            topic: "agents",
            aliases: ["integrations", "agent-integrations"],
            summary: "Agent hook integrations, Feed approvals, notifications, and session restore.",
            webURL: "https://bmux.com/docs/agent-integrations/oh-my-codex",
            rawResources: [
                DocsResource(label: "agent hook docs", url: "https://raw.githubusercontent.com/manaflow-ai/bmux/main/docs/agent-hooks.md"),
                DocsResource(label: "feed docs", url: "https://raw.githubusercontent.com/manaflow-ai/bmux/main/docs/feed.md"),
                DocsResource(label: "notifications docs", url: "https://raw.githubusercontent.com/manaflow-ai/bmux/main/docs/notifications.md"),
            ],
            commands: [
                "bmux hooks setup",
                "bmux hooks setup <agent>",
                "bmux hooks hermes-agent install",
                "bmux hooks hermes-agent uninstall",
                "bmux hooks <agent> uninstall",
            ]
        ),
        DocsReference(
            topic: "dock",
            aliases: ["doc", "controls", "right-sidebar", "dock-json"],
            summary: "Custom right-sidebar terminal controls from .bmux/dock.json or ~/.config/bmux/dock.json.",
            webURL: "https://bmux.com/docs/dock",
            rawResources: [
                DocsResource(label: "dock docs", url: "https://raw.githubusercontent.com/manaflow-ai/bmux/main/docs/dock.md"),
                DocsResource(label: "dock web copy", url: "https://raw.githubusercontent.com/manaflow-ai/bmux/main/web/messages/en.json"),
            ],
            commands: [
                "bmux docs dock",
                "bmux docs dock --json",
                "python3 -m json.tool .bmux/dock.json",
            ]
        ),
        DocsReference(
            topic: "sidebars",
            aliases: ["sidebar", "custom-sidebar", "custom-sidebars", "vibe-sidebar"],
            summary: "Vibe-code a custom sidebar: a runtime-interpreted SwiftUI-style file in ~/.config/bmux/sidebars/ (beta).",
            webURL: "https://bmux.com/docs/custom-sidebars",
            rawResources: [
                DocsResource(label: "custom sidebar authoring guide", url: "https://raw.githubusercontent.com/manaflow-ai/bmux/main/docs/custom-sidebars.md"),
            ],
            commands: [
                "mkdir -p ~/.config/bmux/sidebars",
                "cat > ~/.config/bmux/sidebars/mine.swift   # write a SwiftUI-style view, then right-click the sidebar button to pick it",
                "bmux docs api   # discover bmux() action methods/params",
            ]
        ),
    ]

    func runDocsCommand(commandArgs: [String], jsonOutput: Bool) throws {
        let parsedArgs = docsSettingsArguments(commandArgs)
        let wantsJSON = jsonOutput || parsedArgs.head.contains("--json")
        let args = parsedArgs.arguments

        if hasHelpRequest(beforeSeparator: parsedArgs.head) {
            print(docsUsage())
            return
        }

        guard let topic = args.first?.lowercased() else {
            if wantsJSON {
                print(jsonString(["topics": Self.docsReferences.map { docsPayload($0) }]))
            } else {
                printDocsIndex()
            }
            return
        }

        guard args.count == 1 else {
            throw CLIError(message: "Usage: bmux docs [settings|shortcuts|api|browser|agents|dock]")
        }

        if topic == "list" || topic == "all" {
            if wantsJSON {
                print(jsonString(["topics": Self.docsReferences.map { docsPayload($0) }]))
            } else {
                printDocsIndex()
            }
            return
        }

        guard let reference = docsReference(for: topic) else {
            throw CLIError(message: "Unknown docs topic '\(topic)'. Run 'bmux docs' for topics.")
        }

        if wantsJSON {
            print(jsonString(docsPayload(reference)))
        } else {
            printDocsReference(reference)
        }
    }

    func docsUsage() -> String {
        return """
        Usage: bmux docs [settings|shortcuts|api|browser|agents|dock]

        Print the canonical docs URL, raw GitHub resources, and useful commands for a bmux topic.
        This command does not require a running bmux app or socket.

        Agents:
          Use `bmux docs settings` before editing ~/.config/bmux/bmux.json.
          Use `bmux docs dock` before creating or editing .bmux/dock.json.
          Back up any existing bmux.json file to a timestamped .bak copy before editing so the user can revert.
          Fetch raw resources with the printed curl commands when you need the latest schema.
        """
    }

    private func docsReference(for topic: String) -> DocsReference? {
        let normalized = topic.replacingOccurrences(of: "_", with: "-")
        return Self.docsReferences.first { reference in
            reference.topic == normalized || reference.aliases.contains(normalized)
        }
    }

    private func docsPayload(_ reference: DocsReference) -> [String: Any] {
        var payload: [String: Any] = [
            "topic": reference.topic,
            "aliases": reference.aliases,
            "summary": reference.summary,
            "web_url": reference.webURL,
            "raw_resources": reference.rawResources.map { resource in
                [
                    "label": resource.label,
                    "url": resource.url,
                    "fetch": "curl -fsSL \(resource.url)",
                ]
            },
            "commands": reference.commands,
        ]
        if reference.topic == "settings" {
            payload["settings_files"] = [
                "primary": Self.primarySettingsDisplayPath,
                "legacy": Self.legacySettingsDisplayPath,
                "fallback": Self.fallbackSettingsDisplayPath,
            ]
            payload["ghostty_config"] = [
                "path": Self.ghosttyConfigDisplayPath,
                "note": "Not bmux-owned, but bmux reads it. Use for terminal transparency (background-opacity), blur, font, theme, etc.",
            ]
            payload["backup"] = "Back up any existing bmux.json file to a timestamped .bak copy before editing so the user can revert."
            payload["reload_command"] = "bmux reload-config"
            payload["reload_scope"] = "Reloads Ghostty config + bmux.json and refreshes terminals in place. No app restart needed."
        }
        return payload
    }

    private func printDocsIndex() {
        print("bmux docs")
        print()
        print("Topics:")
        for reference in Self.docsReferences {
            print("  \(reference.topic.padding(toLength: 10, withPad: " ", startingAt: 0)) \(reference.summary)")
        }
        print()
        print("Run `bmux docs <topic>` for URLs, raw resources, and next commands.")
    }

    private func printDocsReference(_ reference: DocsReference) {
        print("\(reference.topic): \(reference.summary)")
        print()
        print("Web:")
        print("  \(reference.webURL)")
        if !reference.rawResources.isEmpty {
            print()
            print("Raw resources:")
            for resource in reference.rawResources {
                print("  \(resource.label): \(resource.url)")
            }
            print()
            print("Fetch:")
            for resource in reference.rawResources {
                print("  curl -fsSL \(resource.url)")
            }
        }
        if !reference.commands.isEmpty {
            print()
            print("Useful commands:")
            for command in reference.commands {
                print("  \(command)")
            }
        }
        if reference.topic == "settings" {
            print()
            print("Config files:")
            print("  primary: \(Self.primarySettingsDisplayPath)")
            print("  legacy config: \(Self.legacySettingsDisplayPath)")
            print("  legacy app support: \(Self.fallbackSettingsDisplayPath)")
            print()
            print("Related (not bmux-owned, but bmux reads it for terminal behavior):")
            print("  \(Self.ghosttyConfigDisplayPath)")
            print("  Use this for terminal transparency (background-opacity), blur, font, theme, etc.")
            print()
            print("Before editing bmux.json:")
            print("  Back up any existing bmux.json file to a timestamped .bak copy so the user can revert.")
            print()
            print("Reload after editing bmux.json or Ghostty config:")
            print("  bmux reload-config   (reloads BOTH and refreshes terminals; no app restart needed)")
        }
    }

    func runSettings(
        commandArgs: [String],
        socketPath: String,
        explicitPassword: String?,
        jsonOutput: Bool
    ) throws {
        let parsedArgs = docsSettingsArguments(commandArgs)
        let wantsJSON = jsonOutput || parsedArgs.head.contains("--json")
        let args = parsedArgs.arguments
        let subcommand = args.first?.lowercased() ?? "open"

        if hasHelpRequest(beforeSeparator: parsedArgs.head) {
            print(settingsUsage())
            return
        }

        switch subcommand {
        case "path", "paths":
            guard args.count == 1 else {
                throw CLIError(message: "Usage: bmux settings path")
            }
            printSettingsPaths(jsonOutput: wantsJSON)
            return
        case "docs", "documentation":
            guard args.count == 1 else {
                throw CLIError(message: "Usage: bmux settings docs")
            }
            if wantsJSON, let reference = docsReference(for: "settings") {
                print(jsonString(docsPayload(reference)))
            } else if let reference = docsReference(for: "settings") {
                printDocsReference(reference)
            }
            return
        case "open":
            let targetRaw: String?
            if args.count > 2 {
                throw CLIError(message: "Usage: bmux settings open [target]")
            } else if let rawTarget = args.dropFirst().first {
                guard let target = settingsTargetRawValue(for: rawTarget) else {
                    throw CLIError(message: "Unknown settings target '\(rawTarget)'. Run 'bmux settings --help'.")
                }
                targetRaw = target
            } else {
                targetRaw = nil
            }
            try openSettingsTarget(
                targetRaw,
                socketPath: socketPath,
                explicitPassword: explicitPassword,
                jsonOutput: wantsJSON
            )
            return
        default:
            guard let targetRaw = settingsTargetRawValue(for: subcommand) else {
                throw CLIError(message: "Unknown settings subcommand '\(subcommand)'. Run 'bmux settings --help'.")
            }
            guard args.count == 1 else {
                throw CLIError(message: "Usage: bmux settings [open [target]|path|docs|<target>]")
            }
            try openSettingsTarget(
                targetRaw,
                socketPath: socketPath,
                explicitPassword: explicitPassword,
                jsonOutput: wantsJSON
            )
        }
    }

    func settingsCommandDoesNotNeedSocket(_ commandArgs: [String]) -> Bool {
        let parsedArgs = docsSettingsArguments(commandArgs)
        let subcommand = parsedArgs.arguments.first?.lowercased() ?? "open"
        return hasHelpRequest(beforeSeparator: parsedArgs.head) ||
            ["path", "paths", "docs", "documentation"].contains(subcommand)
    }

    func settingsUsage() -> String {
        return """
        Usage: bmux settings [open [target]|path|docs|<target>]

        Open bmux Settings, print bmux.json paths, or show settings documentation.

        Subcommands:
          open [target]       Open Settings, optionally to a target section.
          path                Print bmux.json paths, docs URL, and schema URL.
          docs                Print the same output as `bmux docs settings`.

        Targets:
          account, app, terminal, sidebar-appearance, custom-sidebars,
          automation, browser, browser-import, global-hotkey,
          keyboard-shortcuts, shortcuts, workspace-colors, bmux-json,
          json, reset

        Config file:
          \(Self.primarySettingsDisplayPath)
          legacy config: \(Self.legacySettingsDisplayPath)
          legacy app support: \(Self.fallbackSettingsDisplayPath)

        Related (not bmux-owned, but bmux reads it for terminal behavior):
          \(Self.ghosttyConfigDisplayPath)

        Before editing bmux.json:
          Back up any existing bmux.json file to a timestamped .bak copy so the user can revert.

        Reload after editing bmux.json or Ghostty config:
          bmux reload-config   (reloads BOTH and refreshes terminals; no app restart needed)
        """
    }

    private func settingsTargetRawValue(for rawValue: String) -> String? {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")

        switch normalized {
        case "account":
            return "account"
        case "app", "general":
            return "app"
        case "terminal":
            return "terminal"
        case "sidebar", "sidebar-appearance", "sidebarappearance":
            return "sidebarAppearance"
        case "custom-sidebars", "customsidebars":
            return "customSidebars"
        case "automation":
            return "automation"
        case "browser":
            return "browser"
        case "browser-import", "browserimport", "import-browser-data":
            return "browserImport"
        case "global-hotkey", "globalhotkey", "hotkey":
            return "globalHotkey"
        case "keyboard-shortcuts", "keyboardshortcuts", "shortcuts", "keys", "keybindings":
            return "keyboardShortcuts"
        case "workspace-colors", "workspacecolors", "colors":
            return "workspaceColors"
        case "bmux-json", "bmuxjson", "settings-json", "settingsjson", "json", "file", "settings-file":
            return "settingsJSON"
        case "reset":
            return "reset"
        default:
            return nil
        }
    }

    private func openSettingsTarget(
        _ targetRaw: String?,
        socketPath: String,
        explicitPassword: String?,
        jsonOutput: Bool
    ) throws {
        let client = try connectClient(
            socketPath: socketPath,
            explicitPassword: explicitPassword,
            launchIfNeeded: true
        )
        defer { client.close() }

        var params: [String: Any] = ["activate": true]
        if let targetRaw {
            params["target"] = targetRaw
        }

        let response = try client.sendV2(method: "settings.open", params: params)
        if jsonOutput {
            print(jsonString(response))
        } else {
            let target = (response["target"] as? String) ?? targetRaw ?? "general"
            print("OK target=\(target)")
        }
    }

    func runShortcuts(
        commandArgs: [String],
        socketPath: String,
        explicitPassword: String?,
        jsonOutput: Bool
    ) throws {
        let remaining = commandArgs.filter { $0 != "--" }
        if let unknown = remaining.first {
            throw CLIError(message: "shortcuts: unknown flag '\(unknown)'")
        }

        let client = try connectClient(
            socketPath: socketPath,
            explicitPassword: explicitPassword,
            launchIfNeeded: true
        )
        defer { client.close() }

        let response = try client.sendV2(method: "settings.open", params: [
            "target": "keyboardShortcuts",
            "activate": true,
        ])
        if jsonOutput {
            print(jsonString(response))
        } else {
            print("OK")
        }
    }

    func docsSettingsArguments(_ commandArgs: [String]) -> (head: [String], arguments: [String]) {
        let separatorIndex = commandArgs.firstIndex(of: "--")
        let head = separatorIndex.map { Array(commandArgs[..<$0]) } ?? commandArgs
        let tail = separatorIndex.map { Array(commandArgs[commandArgs.index(after: $0)...]) } ?? []
        let headArguments = head.filter { $0 != "--json" }
        return (head, headArguments + tail)
    }

    func hasHelpRequest(beforeSeparator args: [String]) -> Bool {
        let positionalArgs = args.filter { $0 != "--json" }
        return args.contains("--help") || args.contains("-h") || positionalArgs.first?.lowercased() == "help"
    }
}
