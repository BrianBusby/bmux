---
name: bmux-diagnostics
description: "Run end-user bmux diagnostics. Use when bmux hooks, notifications, session restore, settings, browser automation, socket access, CLI control, or agent resume behavior is not working, or when the user asks for a bmux health check, doctor report, or support-safe debug summary."
---

# bmux Diagnostics

Use this skill to collect and interpret support-safe bmux diagnostics for end users. Default to read-only checks. Do not dump hook config files, session stores, prompt logs, tokens, or environment secrets.

## Quick Report

Run the bundled read-only diagnostic script first:

```bash
# From a bmux checkout
skills/bmux-diagnostics/scripts/bmux-diagnostics

# From an installed skill
~/.agents/skills/bmux-diagnostics/scripts/bmux-diagnostics

# From a Codex-only skills.sh install
~/.codex/skills/bmux-diagnostics/scripts/bmux-diagnostics
```

Use `--include-context` only when workspace names, cwd paths, and current bmux identifiers are relevant to the user-reported issue:

```bash
skills/bmux-diagnostics/scripts/bmux-diagnostics --include-context
```

## What to Check

1. CLI and socket health:

   ```bash
   command -v bmux
   bmux ping
   bmux capabilities --json
   ```

   If socket commands fail, check whether the agent is running inside a bmux terminal and whether socket automation is enabled.

2. Settings health:

   ```bash
   ~/.agents/skills/bmux-settings/scripts/bmux-settings validate
   ~/.agents/skills/bmux-settings/scripts/bmux-settings get terminal.autoResumeAgentSessions
   ```

   If the user installed with `skills.sh`, use `~/.codex/skills/bmux-settings/scripts/bmux-settings` instead.
   If `terminal.autoResumeAgentSessions` is false, bmux restores panes but will not automatically resume saved agent sessions.

3. Hook installation:

   ```bash
   bmux hooks setup --agent codex
   bmux hooks setup --agent opencode
   bmux hooks setup
   ```

   Only run install or uninstall commands after the user agrees. `bmux hooks setup` installs supported agents found on PATH and skips missing agents.

4. Session restore evidence:

   ```bash
   ls -lh ~/.bmuxterm/*-hook-sessions.json 2>/dev/null
   ```

   Missing session stores usually means the agent has not run inside bmux since hooks were installed, hooks are disabled, or the agent integration does not support resume capture.

5. Notification path:

   ```bash
   bmux notify "bmux diagnostic test"
   ```

   Use this only when the user is ready for a visible test notification.

## Interpretation

- `bmux` not found: the CLI is not installed or not on PATH for this shell.
- `bmux ping` fails: app is not reachable through the current socket path, the app is closed, or automation access is disabled.
- No `BMUX_WORKSPACE_ID` or `BMUX_SURFACE_ID`: the command is probably running outside a bmux terminal. Some hooks intentionally no-op outside bmux.
- Hook config exists but no session store: run one supported agent inside bmux after installing hooks, then re-check.
- Session store exists but restore does not launch agents: check `terminal.autoResumeAgentSessions` and whether the saved executable still exists on PATH.
- Settings validation fails: fix the config first. Invalid config can make later symptoms misleading.

## Rules

- Stay read-only until the user asks to fix something.
- Never print raw hook files, session JSON, prompt logs, shell history, tokens, or API keys.
- Summarize file presence, size, modified time, and marker presence instead of contents.
- Prefer narrow fixes such as `bmux hooks setup --agent codex` over reinstalling every integration.
- After a fix, rerun the diagnostic script and report the changed lines.
