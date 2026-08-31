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
}
