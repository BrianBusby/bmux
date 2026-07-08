# bmux-vault

`bmux-vault` discovers local coding-agent session transcripts and syncs them to
bmux Vault cloud storage. Round 1 supports Claude Code, Codex, and pi.

## Install

```bash
go build ./cmd/bmux-vault
```

## Commands

```bash
bmux-vault login
bmux-vault scan
bmux-vault sync
bmux-vault resume <session-id>
bmux-vault status
bmux-vault logout
```

`login` starts a device-code flow, prints a verification URL and user code, and
stores Stack Auth tokens in `~/.config/bmux-vault/auth.json` with mode `0600`.
`sync` uploads changed transcripts directly to S3-compatible object storage via
presigned URLs. `resume` restores a missing transcript from cloud storage and
prints the command the agent expects.

Useful flags:

```bash
bmux-vault --json scan
bmux-vault sync --agent codex --dry-run
bmux-vault sync --limit 25
bmux-vault resume --agent claude <session-id>
bmux-vault resume --force <session-id>
```

## Environment

- `BMUX_VAULT_API_BASE`: web API base URL. Defaults to `https://bmux.com`.
- `BMUX_VAULT_CONFIG_DIR`: override the auth token directory.
- `BMUX_VAULT_STATE_DIR`: override the sync state directory.
- `CLAUDE_CONFIG_DIR`: override Claude Code config discovery.
- `CODEX_HOME`: override Codex discovery.

Default local state lives in `~/.local/state/bmux-vault/state.json`.
