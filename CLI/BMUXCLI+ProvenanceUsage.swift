extension BMUXCLI {
    func provenanceUsage() -> String {
        String(
            localized: "cli.provenance.usage",
            defaultValue: """
            Usage:
              bmux provenance explain <path> [--json]
              bmux provenance context current [--json]
              bmux provenance worktrees list [--json]
              bmux provenance sessions tree <session-id> [--json]
              bmux provenance sessions related <pe-session-id> [--limit <count>] [--exclusion-limit <count>] [--updated-after <timestamp>] [--revision <revision-id>] [--database <path>] [--json]
              bmux provenance sessions collisions <pe-session-id> [--limit <count>] [--related-session-limit <count>] [--exclusion-limit <count>] [--artifact-path <repo-relative-path>] [--updated-after <timestamp>] [--stale-before <timestamp>] [--revision <revision-id>] [--database <path>] [--json]
              bmux provenance turn outcome <turn-id> [--revision <revision-id>] [--database <path>] [--json]
              bmux provenance session outcome <session-id> [--revision <revision-id>] [--database <path>] [--json]
              bmux provenance import codex-transcripts [--path <path>] [--limit <count>] [--database <path>] [--json]
              bmux provenance traces lifecycle-ingestion [--run <pipeline-run-id>] [--parent-session <session-id>] [--child-session <session-id>] [--status <status>] [--json]
              bmux provenance diagnostics workspace-display --workspace <workspace-id> [--database <path>] [--json]
              bmux provenance diagnostics execution-telemetry-live <session-id> [--agent-chat-url <url>] [--repository <path>] [--database <path>] [--json]

            Inspect bmux work provenance without requiring a live app socket.
            Related-session retrieval uses explicit PE session ids. Artifact-collision retrieval starts from the target session's recorded changed artifacts; --artifact-path narrows those candidates only.
            """
        )
    }

    func provenanceSubcommandHelp(commandArgs: [String]) -> (command: String, text: String)? {
        let preSeparatorArgs = commandArgs.firstIndex(of: "--").map { commandArgs[..<$0] } ?? commandArgs[...]
        let tokens = preSeparatorArgs
            .filter { $0 != "--help" && $0 != "-h" }
            .map { $0.lowercased() }

        if tokens == ["sessions"] {
            return ("provenance sessions", provenanceSessionsUsage())
        }
        if tokens.count >= 2, tokens[0] == "sessions", tokens[1] == "related" {
            return ("provenance sessions related", provenanceSessionsRelatedUsage())
        }
        if tokens.count >= 2, tokens[0] == "sessions", tokens[1] == "collisions" {
            return ("provenance sessions collisions", provenanceSessionsCollisionsUsage())
        }
        return ("provenance", provenanceUsage())
    }
}
