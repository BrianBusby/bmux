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
              bmux provenance turn outcome <turn-id> [--revision <revision-id>] [--database <path>] [--json]
              bmux provenance session outcome <session-id> [--revision <revision-id>] [--database <path>] [--json]
              bmux provenance import codex-transcripts [--path <path>] [--limit <count>] [--database <path>] [--json]
              bmux provenance traces lifecycle-ingestion [--run <pipeline-run-id>] [--parent-session <session-id>] [--child-session <session-id>] [--status <status>] [--json]
              bmux provenance diagnostics workspace-display --workspace <workspace-id> [--database <path>] [--json]
              bmux provenance diagnostics execution-telemetry-live <session-id> [--agent-chat-url <url>] [--repository <path>] [--database <path>] [--json]

            Inspect bmux work provenance without requiring a live app socket.
            """
        )
    }
}
