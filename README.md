# bmux

bmux is a public fork of [cmux](https://github.com/manaflow-ai/cmux), a Ghostty-based macOS terminal built for running many AI coding-agent sessions side by side.

This fork keeps the core cmux model: native Swift/AppKit UI, libghostty terminal rendering, vertical workspace tabs, split panes, an embedded browser, notifications, CLI automation, and agent-aware workspace metadata. It is rebranded around bmux and carries current local agent-workflow changes.

## Improvements In This Fork

- **bmux rebrand**: project references, bundle identifiers, CLI names, config names, packages, scripts, docs, tests, and workflow files use bmux naming.
- **Tron working spinner**: workspace tabs use the Tron-style working indicator when visible terminal output shows an AI agent is actively working.
- **More reliable busy detection**: visible agent status lines can mark a workspace busy even when a stale lifecycle hook reports idle.
- **Interrupt-aware stale-state clearing**: explicit agent interrupts suppress stale "Working" status lines until the next real input or lifecycle update.
- **Agent title cleanup**: terminal/process title handling is sanitized before it can rename workspaces.
- **Auto-naming improvements**: workspace and tab naming includes newer agent-title, PR-title, and summarization updates from the latest local work.
- **Token/transcript workflow updates**: includes local changes for token optimization, raw output capture, and transcript-aware agent automation.
- **Sidebar observation updates**: workspace sidebar state observes agent work changes more directly, including lifecycle and interrupt state.

## Core Features

- Native macOS terminal app using Swift, AppKit, and libghostty.
- Vertical workspace tabs plus horizontal and vertical split panes.
- Agent-aware notifications, unread state, and jump-to-latest-unread workflows.
- Embedded browser panes with automation hooks for AI agents.
- CLI and socket APIs for workspaces, panes, browser automation, status, notifications, and scripting.
- Ghostty config compatibility for themes, fonts, and colors.
- SSH workspace support with remote-aware browser routing.
- Custom command and shortcut configuration through `bmux.json`.

## Roadmap

The canonical bmux roadmap is `docs/roadmap.md`. Cross-repository bmux to provenance-engine adoption milestones are canonical in the provenance-engine shared integration roadmap linked from `docs/provenance-integration.md`.

Documentation authority and generated current status:

- `docs/README.md`
- `docs/generated/project-status.md`

## Install

There is no public bmux release artifact yet.

For local development, use the normal tagged debug workflow:

```bash
./scripts/setup.sh
./scripts/reload.sh --tag bmux-dev
```

The reload script prints the built `.app` path when the build succeeds.

## Configuration

bmux-owned settings use `bmux.json` naming after the fork rename. Existing cmux user configuration may need a one-time manual migration before this fork can read it consistently.

Common surfaces include:

- user config under `~/.config/bmux/`
- local project config named `bmux.json`
- CLI commands under `bmux`
- debug sockets and logs using `bmux` prefixes

## Upstream

bmux is forked from cmux and should be treated as a downstream fork unless or until the fork establishes its own release, docs, and Homebrew distribution. Keep upstream attribution in this README, and review upstream changes before merging them because this fork intentionally renames product identifiers and config paths.
