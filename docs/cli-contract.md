# bmux CLI Contract

This document is the compatibility contract for migrating `CLI/bmux.swift` to
Swift ArgumentParser. The migration should preserve command names, aliases,
global flags, exit behavior, socket routing, and no-socket help behavior unless
a PR explicitly calls out an intentional contract change.

The current implementation is a hand-rolled parser. This spec is deliberately
written around user-visible behavior so the implementation can change behind it.

## Migration Rules

- Keep `bmux --help`, `bmux -h`, `bmux --version`, and `bmux -v` working without
  connecting to the bmux socket.
- Keep documented `bmux <command> --help` probes working without a socket where
  they already do.
- Keep `--socket`, `--password`, and `--window` as global options before the
  command. Keep presentation options `--json` and `--id-format` accepted either
  before or after the command.
- Keep UUIDs, refs such as `workspace:2`, and indexes accepted wherever the
  command accepts a window, workspace, pane, surface, or tab handle.
- Keep text output stable for scripting commands unless a command already
  documents JSON as the scripting interface.
- Keep hidden/internal commands available until their callers have migrated.

## Global Invocation

| Form | Contract |
| --- | --- |
| `bmux <path>` | Open a directory or file parent in bmux through the app's file-open path, without requiring control-socket access. Relative paths resolve from the current working directory. |
| `bmux [global-options] <command> [options]` | Run a named command. Presentation options may appear before or after the command. |
| `bmux --help`, `bmux -h` | Print top-level usage without a socket. |
| `bmux help` | Print top-level usage without a socket. |
| `bmux --version`, `bmux -v`, `bmux version` | Print version summary without a socket. |

Global options:

| Option | Contract |
| --- | --- |
| `--socket <path>` | Override the socket path for this invocation. |
| `--password <value>` | Use an explicit socket password. Takes precedence over `BMUX_SOCKET_PASSWORD`. |
| `--json` | Prefer machine-readable JSON output for commands that support it. |
| `--id-format <refs\|uuids\|both>` | Select handle format in JSON and supported text output. |
| `--window <id\|ref\|index>` | Route the command through a specific window when supported. |

Environment:

| Variable | Contract |
| --- | --- |
| `BMUX_SOCKET_PATH` | Canonical socket path override. |
| `BMUX_SOCKET` | Deprecated compatibility alias for `BMUX_SOCKET_PATH`. New scripts should use `BMUX_SOCKET_PATH`; if both variables are set and differ, the CLI fails before socket commands. |
| `BMUX_SOCKET_PASSWORD` | Socket password fallback when `--password` is absent. |
| `BMUX_WORKSPACE_ID` | Default workspace context inside bmux terminals. |
| `BMUX_SURFACE_ID` | Default surface context inside bmux terminals. |
| `BMUX_TAB_ID` | Default tab context for tab commands. |

## Top-Level Commands

| Command | Contract |
| --- | --- |
| `welcome` | Print the welcome screen. |
| `docs` | Print canonical docs URLs, raw GitHub resources, and useful commands for a topic. |
| `settings` | Open Settings, print bmux.json paths, or print settings docs. |
| `config` | Validate bmux.json syntax, print config references, or reload config. |
| `shortcuts` | Open Settings to Keyboard Shortcuts. |
| `disable-browser` | Disable bmux browser creation and link interception until re-enabled. |
| `enable-browser` | Re-enable bmux browser creation and link interception. |
| `browser-status` | Print whether bmux browser creation and link interception are enabled. |
| `agent-hibernation` | Enable or disable Agent Hibernation. |
| `restore-session` | Restore the previously saved bmux session. |
| `open` | Open files, directories, or URLs in bmux. |
| `feedback` | Open feedback UI or submit feedback with `--email`, `--body`, and repeated `--image`. |
| `feed` | Open the keyboard-first Feed TUI or manage persisted Feed workstream history. |
| `themes` | List, set, clear, or interactively pick Ghostty themes. |
| `claude-teams` | Launch Claude Code with bmux/tmux-style agent team integration. |
| `codex-teams` | Launch Codex with bmux-managed subagent panes. |
| `omo` | Launch OpenCode with oh-my-openagent integration. |
| `omx` | Launch Oh My Codex with bmux pane integration. |
| `omc` | Launch Oh My Claude Code with bmux pane integration. |
| `hooks` | Install, uninstall, and run agent hook integrations under one namespace. |
| `codex` | Compatibility alias for installing or uninstalling Codex hooks. |
| `provenance` | Inspect Provenance Engine state and bounded retrieval projections without requiring a live bmux socket. Supports `--json` on adopted reads. |
| `ping` | Check socket connectivity. |
| `capabilities` | Print server capabilities as JSON. |
| `events` | Stream reconnectable bmux events as newline-delimited JSON. |
| `auth` | Manage auth status, login, and logout through the app. |
| `vm`, `cloud` | Manage cloud VMs. `cloud` is an alias for `vm`. |
| `remotes`, `remote` | Manage remote Macs in the team device registry so they appear in the iOS app's device list. `remote` is an alias for `remotes`. |
| `rpc` | Call a raw v2 socket method with optional JSON params. |
| `identify` | Print server identity and caller context. |
| `list-windows` | List windows. |
| `current-window` | Print the selected window ID. |
| `new-window` | Create a new window. |
| `focus-window` | Focus a window by handle. |
| `close-window` | Close a window by handle. |
| `window displays` | List connected displays (name, index, main flag). |
| `window display <name\|index>` | Move the instance's window(s) onto a display by name (exact, substring) or index, preserving size. Does not steal focus. With `--window`, targets that window; otherwise moves all main windows. `--list` aliases `window displays`. |
| `window default-display [<name>\|--clear]` | Set, show (no arg), or clear (`--clear`) the shared, cross-tag default display that DEBUG dev builds open new windows on, stored in `~/.config/bmux/bmux.json` under `app.devWindowDisplay`. No running app required; applied at window creation. Also settable in Debug > Debug Windows > Dev Window Display. |
| `move-workspace-to-window` | Move a workspace into a target window. |
| `reorder-workspace` | Reorder a workspace inside a window. |
| `reorder-workspaces` | Atomically reorder workspaces inside pinned and unpinned groups. |
| `workspace-action` | Run workspace context-menu actions from the CLI. |
| `workspace` | Namespace for workspace verbs: `list`, `create`, `env`, `close`, `rename`, `select`, `reconnect`, `disconnect`, `group`. `workspace env` prints a workspace's configured environment variables (see [Workspace environment variables](#workspace-environment-variables)); pass `--mask` to redact the values. `workspace reconnect` manually reconnects a remote (SSH) workspace — including one whose automatic reconnect suspended because the host was unreachable — and `workspace disconnect` stops its remote connection. `env`, `reconnect`, and `disconnect` accept a positional workspace handle or `--workspace <id\|ref\|index>`, defaulting to the caller's workspace, then the selected one. |
| `move-tab-to-new-workspace` | Move a tab or surface into a newly created workspace. |
| `list-workspaces` | List workspaces. |
| `new-workspace` | Create a workspace, optionally with cwd, command, description, layout, and per-workspace environment variables (`--env KEY=VALUE` repeatable, `--env-file <path>`). See [Workspace environment variables](#workspace-environment-variables). |
| `ssh` | Open an SSH-backed workspace. Preserves the caller's live `SSH_AUTH_SOCK` for app-launched OpenSSH processes so `ForwardAgent yes` from ssh_config works normally. Supports `-A` / `--forward-agent` to request forwarding and `-a` / `--no-forward-agent` to disable forwarding for a workspace. Agent forwarding remains opt-in because forwarded agents can be used by processes on the remote host while the SSH session is active. |
| `remote-daemon-status` | Print bundled remote daemon version, asset, checksum, and cache status. |
| `ssh-session-list` | List persisted SSH PTY sessions for one remote workspace or all remote workspaces. Supports `--json`. |
| `ssh-session-attach` | Create a local terminal surface that reattaches to an existing persisted SSH PTY session. |
| `ssh-session-cleanup` | Close one or all persisted SSH PTY sessions. Supports `--json`. |
| `new-split` | Split from a surface in a direction. |
| `list-panes` | List panes in a workspace. |
| `list-pane-surfaces` | List surfaces in a pane. |
| `tree` | Print a window, workspace, pane, and surface tree. |
| `top` | Print process/resource usage for bmux windows, workspaces, panes, and surfaces. |
| `focus-pane` | Focus a pane. |
| `new-pane` | Create a pane with terminal or browser content. |
| `new-surface` | Create a surface inside a pane. |
| `close-surface` | Close a surface. |
| `move-surface` | Move a surface to another pane, workspace, window, or index. |
| `split-off` | Move a surface into a new split without changing focus by default. |
| `reorder-surface` | Reorder a surface within its pane. |
| `tab-action` | Run horizontal tab context-menu actions. |
| `rename-tab` | Rename a tab. Compatibility wrapper for `tab-action rename`. |
| `drag-surface-to-split` | Move a surface into a split direction. |
| `refresh-surfaces` | Ask the app to refresh terminal surfaces. |
| `reload-config` | Ask bmux to reload configuration. |
| `surface-health` | Print terminal surface health information. |
| `debug-terminals` | Print debug terminal state. |
| `trigger-flash` | Trigger a visual flash on a workspace or surface. |
| `list-panels` | List panels. Compatibility alias over pane/surface data. |
| `focus-panel` | Focus a panel. Compatibility alias over surface focus. |
| `close-workspace` | Close a workspace. |
| `select-workspace` | Select a workspace. |
| `rename-workspace`, `rename-window` | Rename a workspace. `rename-window` is a compatibility alias. |
| `current-workspace` | Print current workspace information. |
| `read-screen` | Read terminal text from a surface. |
| `send` | Send text to a terminal surface. |
| `send-key` | Send one key to a terminal surface. |
| `send-panel` | Send text to a panel/surface. |
| `send-key-panel` | Send one key to a panel/surface. |
| `notify` | Send a notification to a workspace/surface. |
| `list-notifications` | List queued notifications, including `created_at` and `tab_title`. |
| `dismiss-notification` | Remove one notification, or remove already-read notifications with `--all-read`. |
| `mark-notification-read` | Mark one notification, a workspace/surface scope, or all notifications read. |
| `open-notification` | Focus the notification's workspace/surface and mark it read. |
| `jump-to-unread` | Focus the latest unread notification. |
| `clear-notifications` | Clear queued notifications. |
| `right-sidebar` | Control right sidebar visibility, mode, focus, and state reads. |
| `set-status` | Set a sidebar status pill. |
| `clear-status` | Remove a sidebar status pill. |
| `list-status` | List sidebar status pills. |
| `set-progress` | Set sidebar progress. |
| `clear-progress` | Clear sidebar progress. |
| `log` | Append a sidebar log entry. |
| `clear-log` | Clear sidebar log entries. |
| `list-log` | List sidebar log entries. |
| `sidebar-state` | Dump sidebar metadata state. |
| `claude-hook` | Compatibility alias for Claude Code hook events from stdin JSON. |
| `set-app-focus` | Override app focus state for tests. |
| `simulate-app-active` | Trigger app-active handling for tests. |
| `browser` | Run browser automation commands. |
| `open-browser` | Legacy alias for `browser open`. |
| `navigate` | Legacy alias for `browser navigate`. |
| `browser-back` | Legacy alias for `browser back`. |
| `browser-forward` | Legacy alias for `browser forward`. |
| `browser-reload` | Legacy alias for `browser reload`. |
| `get-url` | Legacy alias for `browser get-url`. |
| `focus-webview` | Legacy alias for `browser focus-webview`. |
| `is-webview-focused` | Legacy alias for `browser is-webview-focused`. |
| `markdown` | Open a markdown file in a formatted viewer panel with live reload. |
| `vm-pty-attach` | Internal VM PTY attach command. |
| `vm-ssh-attach` | Hidden compatibility alias for older VM workspaces. |
| `vm-pty-connect` | Internal helper that connects to a VM PTY from a config file. |
| `ssh-pty-attach` | Internal helper used by SSH terminal startup scripts to bridge a local terminal surface to a remote PTY session. |
| `ssh-session-end` | Internal helper that clears remote SSH session state. |
| `__tmux-compat` | Internal tmux compatibility dispatcher. |

## Command Families

Auth subcommands:

| Command | Contract |
| --- | --- |
| `auth status` | Print signed-in state. Supports `--json`. |
| `auth login` | Begin sign-in through the app and wait for completion. |
| `auth logout` | Clear the current session. |

VM subcommands:

| Command | Contract |
| --- | --- |
| `vm ls`, `vm list` | List VMs. |
| `vm new`, `vm create` | Create a VM. Supports `--image`, `--provider`, `--detach`, and `-d`. |
| `vm shell`, `vm attach` | Open an interactive shell for an existing VM. |
| `vm rm`, `vm destroy`, `vm delete` | Destroy a VM. |
| `vm ssh` | Open a bmux-managed SSH workspace for an existing VM. |
| `vm ssh-info` | Print SSH connection info. |
| `vm ssh-attach` | Internal attach helper. |
| `vm exec` | Run a shell command inside a VM. |

Remotes subcommands:

| Command | Contract |
| --- | --- |
| `remotes list`, `remotes ls` | List the team's registered remotes (name, deviceId, routes, tag, last seen). Supports `--json`. |
| `remotes add <name>` | Register or update a remote with one or more `--route <host:port>`. Supports `--tag` and `--json`. Idempotent on `<name>` (re-adding updates routes). The host must be a Tailscale address the phone can authenticate to (CGNAT `100.64.x.x`-`100.127.x.x` or `*.ts.net`); loopback, plain LAN IPs, and bare hostnames are rejected. |
| `remotes remove <name-or-deviceId>` | Remove a remote you registered. Aliases `rm`, `delete`. Supports `--json`. |

Provenance subcommands:

| Command | Contract |
| --- | --- |
| `provenance explain <path>` | Explain file-level provenance for a path in the current Git worktree. Supports `--database <path>` and `--json`. |
| `provenance context current` | Print the current PE context snapshot. Supports `--database <path>` and `--json`. |
| `provenance worktrees list` | List PE-observed worktrees. Supports `--database <path>` and `--json`. |
| `provenance sessions tree <session-id>` | Read the PE session tree for an explicit PE session id. Supports `--database <path>` and `--json`. |
| `provenance sessions related <pe-session-id>` | Read the bounded related-session projection for an explicit target PE session id through `ProvenanceEngineClient.relatedSessions(...)`. Supports `--limit`, `--exclusion-limit`, `--updated-after`, `--revision`, `--database`, and `--json`. |
| `provenance sessions collisions <pe-session-id>` | Read bounded artifact-collision candidates for an explicit target PE session id through `ProvenanceEngineClient.artifactCollisions(...)`. Supports `--limit`, `--related-session-limit`, `--exclusion-limit`, `--artifact-path`, `--updated-after`, `--stale-before`, `--revision`, `--database`, and `--json`. |
| `provenance turn outcome <turn-id>` | Read an exact or latest Turn Outcome projection. Supports `--revision <revision-id>`, `--database <path>`, and `--json`. |
| `provenance session outcome <session-id>` | Read an exact or latest Session Outcome projection. Supports `--revision <revision-id>`, `--database <path>`, and `--json`. |
| `provenance import codex-transcripts` | Replay historical Codex JSONL transcripts into PE using canonical evidence IDs. Supports `--path <path>`, `--limit <count>`, `--database <path>`, and `--json`. |

Provenance retrieval commands use explicit PE session ids. A provider thread id,
workspace id, surface id, or focused tab is not a substitute. Agents can find PE
session ids through `provenance context current`, `provenance worktrees list`,
`provenance sessions tree`, and existing session/outcome reads, then pass the
chosen id explicitly.

Retrieval defaults and bounds are finite. `related --limit` defaults to `10` and
allows `0...25`; `related --exclusion-limit` defaults to `10` and allows
`0...50`. `collisions --limit` defaults to `10` and allows `0...25`;
`--related-session-limit` defaults to `50` and allows `0...100`;
`--exclusion-limit` defaults to `10` and allows `0...50`. Timestamp filters
accept RFC 3339, such as `2026-08-31T05:44:25Z`, or Unix epoch seconds.
Malformed arguments fail with non-zero exit status and diagnostics on stderr.

`--revision` is an exact historical read. An unknown revision returns a valid
not-found payload (`found: false`, `reason: no_revision`) rather than falling
back to latest. Missing sessions and missing databases are also distinct from
valid empty results. With an explicit `--database`, a missing database returns
`found: false`, `reason: no_database` and does not create an empty database just
to satisfy the read.

Artifact-collision retrieval starts with the target session's recorded changed
artifacts and compares those against bounded related sessions. `--artifact-path`
only narrows those overlap candidates; it is not arbitrary file-history search
before the target has touched the file. An empty result for a path therefore does
not prove nobody else has worked on that path. Same normalized path in another
repository is not an artifact collision.

Theme subcommands:

| Command | Contract |
| --- | --- |
| `themes` | In a TTY, open the interactive picker. Outside a TTY, list themes. |
| `themes list` | List available themes and current light/dark defaults. |
| `themes set <theme>` | Set the same theme for light and dark appearance. |
| `themes set --light <theme>` | Set the light appearance theme. |
| `themes set --dark <theme>` | Set the dark appearance theme. |
| `themes clear` | Remove the bmux theme override. |

Workspace and tab action names:

| Command | Actions |
| --- | --- |
| `workspace-action` | `pin`, `unpin`, `rename`, `clear-name`, `set-description`, `clear-description`, `move-up`, `move-down`, `move-top`, `close-others`, `close-above`, `close-below`, `mark-read`, `mark-unread`, `set-color`, `clear-color` |
| `tab-action` | `rename`, `clear-name`, `close-left`, `close-right`, `close-others`, `new-terminal-right`, `new-browser-right`, `reload`, `duplicate`, `pin`, `unpin`, `mark-unread` |

### Workspace environment variables

A workspace can carry a set of user-defined environment variables that every
shell spawned in it inherits.

Setting them:

- CLI: `bmux new-workspace --env KEY=VALUE [--env ...] [--env-file <path>]`
  (and the same flags on `bmux workspace create`). `--env` is repeatable;
  `--env-file` reads `KEY=VALUE` lines (blank lines and `#` comments ignored, an
  optional leading `export ` stripped). When both are given, `--env` overrides a
  value from a file.
- Project config (`bmux.json`): an `env` object on a workspace definition, e.g.
  `{ "name": "Build", "cwd": ".", "env": { "AWS_PROFILE": "prod" } }`.
- Socket: the `workspace_env` param on `workspace.create`.

Inspecting them: `bmux workspace env [<handle>] [--mask] [--json]` prints the
configured set. `--mask` redacts the values so secrets are not echoed in full.
The env set is intentionally omitted from `workspace list` output so a plain
listing never leaks secrets.

Semantics:

- **Inheritance.** The variables apply to the workspace's initial shell and to
  every pane, surface, and split created later in that workspace — no per-pane
  re-export. They are also re-applied to every shell recreated on session
  restore.
- **Persistence.** They are stored on the workspace in the session manifest, so
  they survive app restart, daemon restart, and session restore.
- **Precedence.** Workspace env overlays the inherited process environment. It is
  applied as the shell's startup environment, so it is visible to login-shell
  init files (`~/.zprofile`, `~/.zshrc`) as they run, but any `export` those
  files perform for the same key wins for the interactive session (they run after
  the variable is seeded). An explicit per-surface environment (a layout
  `surfaces[].env`, SSH startup env) overrides the workspace value for that
  surface.
- **Protected `BMUX_*` variables.** Workspace env can never override the managed
  variables bmux injects (e.g. `BMUX_WORKSPACE_ID`, `BMUX_SURFACE_ID`,
  `BMUX_SOCKET_PATH`, `BMUX_SOCKET_PASSWORD`) or the terminal identity variables
  (`TERM`, `COLORTERM`, `TERM_PROGRAM`); those keys are protected at spawn time
  and silently win.
- **Secrets.** Values may be secrets. They are never logged, are masked by
  `--mask`, and are kept out of `workspace list`. Prefer `--env-file` so secrets
  do not land in shell history. Note that values stored in the session manifest
  live on disk in plaintext.

tmux compatibility commands:

| Command | Contract |
| --- | --- |
| `capture-pane` | Read pane text. |
| `resize-pane` | Resize a pane with direction flags. |
| `pipe-pane` | Pipe pane text to a shell command. |
| `wait-for` | Signal or wait on a named synchronization point. |
| `swap-pane` | Swap two panes. |
| `break-pane` | Move a pane into a new workspace. |
| `join-pane` | Join a pane into another pane. |
| `next-window`, `previous-window`, `last-window` | Move workspace selection. |
| `last-pane` | Focus the last pane. |
| `find-window` | Find a workspace by title or content. |
| `clear-history` | Clear terminal scrollback. |
| `set-hook` | Manage tmux-compat hook definitions. |
| `popup` | Placeholder, currently unsupported. |
| `bind-key`, `unbind-key`, `copy-mode` | Placeholders, currently unsupported. |
| `set-buffer` | Set a tmux-compat buffer. |
| `paste-buffer` | Paste a tmux-compat buffer. |
| `list-buffers` | List tmux-compat buffers. |
| `respawn-pane` | Send a restart command to a surface. |
| `display-message` | Print or display a message. |

Browser subcommands:

| Command | Contract |
| --- | --- |
| `browser open`, `browser open-split`, `browser new` | Create or open a browser surface. |
| `browser goto`, `browser navigate` | Navigate to a URL. |
| `browser back`, `browser forward`, `browser reload` | Navigate browser history or reload. |
| `browser url`, `browser get-url` | Print current URL. |
| `browser focus-webview`, `browser is-webview-focused` | Focus or query webview focus. |
| `browser snapshot` | Print a DOM snapshot. |
| `browser eval` | Evaluate JavaScript. |
| `browser wait` | Wait for selector, text, URL, load state, or JS predicate. |
| `browser click`, `browser dblclick`, `browser hover`, `browser focus`, `browser check`, `browser uncheck`, `browser scroll-into-view` | Run element interaction. |
| `browser type`, `browser fill` | Type into or set an input. |
| `browser press`, `browser key`, `browser keydown`, `browser keyup` | Send keyboard input. |
| `browser select` | Select an option. |
| `browser scroll` | Scroll page or element. |
| `browser screenshot` | Save a screenshot. |
| `browser get` | Read URL, title, text, HTML, value, attr, count, box, or styles. |
| `browser is` | Check visible, enabled, or checked state. |
| `browser find` | Find by role, text, label, placeholder, alt, title, testid, first, last, or nth. |
| `browser frame` | Select frame context. |
| `browser dialog` | Accept or dismiss dialogs. |
| `browser download` | Wait for or save downloads. |
| `browser profiles` | List, add, rename, clear, or delete bmux browser profiles. `clear` refuses to wipe active profiles unless `--force` is passed. |
| `browser import` | Open the browser import wizard. In detected coding-agent environments, defaults to non-interactive cookie import; pass `--interactive` to force the wizard. Non-interactive import supports `--from`, `--profile`, `--all-profiles`, `--to-profile`, `--create-profile`, and `--domain`. |
| `browser cookies` | Get, set, or clear cookies. |
| `browser storage` | Get, set, or clear local/session storage. |
| `browser tab` | Create, list, switch, or close browser tabs. |
| `browser console`, `browser errors` | List or clear console messages and errors. |
| `browser highlight` | Highlight an element. |
| `browser state` | Save or load browser state. |
| `browser addinitscript`, `browser addscript`, `browser addstyle` | Inject scripts or CSS. |
| `browser viewport` | Set viewport size. |
| `browser geolocation`, `browser geo` | Set geolocation. |
| `browser offline` | Toggle offline state. |
| `browser trace` | Start or stop trace capture. |
| `browser network` | Route, unroute, or list requests. |
| `browser screencast` | Start or stop screencast. |
| `browser input`, `browser input_mouse`, `browser input_keyboard`, `browser input_touch` | Send low-level input. |
| `browser identify` | Identify browser surface context. |

Hook subcommands:

| Command | Contract |
| --- | --- |
| `hooks setup` | Install hooks for all supported agents whose binaries are on `PATH`. Supports `--agent <name>`, positional agent filters such as `bmux hooks setup rovo`, and `--yes`. |
| `hooks uninstall` | Remove hooks for all supported agents. Supports `--agent <name>`, positional agent filters such as `bmux hooks uninstall rovo`, and `--yes`. |
| `hooks <agent> install` | Install hooks for one supported agent. `opencode` also supports `--project` for the project-local Feed plugin. |
| `hooks <agent> uninstall` | Remove hooks for one supported agent. |
| `hooks claude <event>` | Handle Claude Code hook events. `claude-hook <event>` remains as the main-compatibility alias. |
| `hooks codex <event>` | Handle Codex hook events. `codex install-hooks` remains as the main-compatibility installer alias. |
| `hooks feed --source <agent>` | Convert agent hook events into Feed context. |
| `hooks <agent> <event>` | Generic hook surface for `grok`, `opencode`, `pi`, `amp`, `cursor`, `gemini`, `kimi`, `rovodev`, `copilot`, `codebuddy`, `factory`, and `qoder`. |

Right sidebar commands:

| Command | Contract |
| --- | --- |
| `right-sidebar toggle`, `right-sidebar show`, `right-sidebar hide` | Change right-sidebar visibility without printing on success. |
| `right-sidebar focus` | Focus the current right-sidebar mode. |
| `right-sidebar set <files\|find\|vault\|sessions\|feed\|dock>` | Show the right sidebar, switch mode, and focus it unless `--no-focus` is passed. |
| `right-sidebar files`, `right-sidebar find`, `right-sidebar vault`, `right-sidebar sessions`, `right-sidebar feed`, `right-sidebar dock` | Short aliases for `right-sidebar set <mode>` with focus. |
| `right-sidebar mode` | Print JSON with `visible` and `mode`. |
| `--workspace <id\|ref\|index>` | Target the window containing a workspace. Refs and indexes resolve before the V1 socket command is sent. |
| `--window <id\|ref\|index>` | Target a window. Refs and indexes resolve before the V1 socket command is sent. |
| `--no-focus` | Only valid with `set`; switches mode without moving focus. |

Custom sidebar commands:

| Command | Contract |
| --- | --- |
| `sidebar validate [name]` | Validate all custom sidebars, or one named sidebar, under `~/.config/bmux/sidebars`. |
| `sidebar reload [name]` | Validate all custom sidebars, then request a reload for every valid one. |
| `sidebar select <name>` | Validate and activate one custom sidebar in the sidebar picker. |
| `sidebar open <name>` | Validate and open one custom sidebar as a normal Bonsplit pane tab, preferring the right-side split from the focused surface. |

Docs topics:

| Command | Contract |
| --- | --- |
| `docs` | List docs topics without a socket. |
| `docs settings` | Print the configuration docs URL, raw schema URL, bmux.json paths, backup reminder, and reload command. |
| `docs shortcuts` | Print shortcut docs and raw shortcut data resources. |
| `docs api` | Print API docs and raw CLI contract resources. |
| `docs browser` | Print browser automation docs and raw browser skill resources. |
| `docs agents` | Print agent integration docs and raw integration resources. |

Settings subcommands:

| Command | Contract |
| --- | --- |
| `settings` | Open the Settings window, launching bmux if needed. |
| `settings open [target]` | Open Settings to an optional target section. |
| `settings path` | Print bmux.json paths, docs URL, schema URL, backup reminder, and reload command without a socket. |
| `settings docs` | Print the same output as `docs settings` without a socket. |
| `settings <target>` | Open Settings to a target section. Supported aliases include `shortcuts`, `json`, `bmux-json`, `browser`, and `automation`. |

Config subcommands:

| Command | Contract |
| --- | --- |
| `config doctor [--path <file>]`, `config check`, `config validate` | Validate JSONC syntax for config files. When `--path` is absent, default discovery checks the primary config, project-level `.bmux/bmux.json` or `bmux.json`, and legacy config files. `--path <file>` may be repeated to validate multiple explicit files. Exits 0 on success and 1 on any error. Supports `--json`. Works without a socket. |
| `config path`, `config paths` | Print bmux.json paths, docs URL, schema URL, backup reminder, and reload command without a socket. |
| `config docs`, `config documentation` | Print the same output as `docs settings` without a socket. |
| `config reload` | Ask the running bmux app to reload configuration. Requires a socket. |
| `config get sidebar-font-size` | Print the effective sidebar text size. |
| `config set sidebar-font-size <points>` | Write the sidebar text size to bmux's editable Ghostty config and reload the running app when available. |
| `config sidebar-font-size [points]` | Get the sidebar text size, or set it when a point size is provided. |
| `config get surface-tab-bar-font-size` | Print the effective workspace tab bar text size. |
| `config set surface-tab-bar-font-size <points>` | Write the workspace tab bar text size to bmux's editable Ghostty config and reload the running app when available. |
| `config surface-tab-bar-font-size [points]` | Get the workspace tab bar text size, or set it when a point size is provided. |
| `config get <key>`, `config set <key> <points>` | Generic get/set for `sidebar-font-size` and `surface-tab-bar-font-size`. |

`config doctor --json` outputs an object with `ok`, `error_count`,
`findings`, `reload_command`, `docs_url`, and `schema_url`. Each finding includes
`label`, `display_path`, `path`, `status`, `ok`, `keys`, and, when available,
`message` and `bytes`.

Events command:

| Option | Contract |
| --- | --- |
| `--after <seq>`, `--after-seq <seq>` | Subscribe to retained events after a sequence number. |
| `--cursor-file <path>` | Read the starting sequence from a file and update it after every event. |
| `--name <event>` | Filter by event name. Repeatable. |
| `--category <name>` | Filter by category. Repeatable. |
| `--reconnect` | Reconnect and resume from the last received sequence until interrupted. |
| `--limit <n>` | Exit after printing `n` event frames. |
| `--no-ack` | Suppress the initial ack frame in stdout. |
| `--no-heartbeat`, `--no-heartbeats` | Suppress heartbeat frames in stdout. |

`events.stream` is a v2 socket method advertised by `capabilities`. The first
response frame is an `ack`; sequence resume metadata lives under `ack.resume` as
`after_seq`, `oldest_seq`, `latest_seq`, `next_seq`, and `gap`. Event frames
carry a process-local monotonic `seq` and a stable `id` for dedupe. Clients
should persist `seq` after processing each event and reconnect with that value.
See [events.md](events.md) for the full protocol and event catalog. Every emitted event is also appended to
`~/.bmuxterm/events.jsonl`, including model lifecycle events for window
creation, close, focus, key-window state, workspace selection, pane focus, and
surface selection, focus, creation, or closure. The stream is bounded: bmux keeps
4,096 replay events in memory, caps each encoded event frame at 16 KiB, closes
slow subscribers after 1,024 pending events, and rotates `events.jsonl` with one
16 MiB archive at `events.jsonl.1`.

## No-Socket Help Probes

The following probes are executable contract checks. They must exit 0 and print
the expected text without connecting to a bmux socket.

<!-- cli-contract-help-probes:start -->
- `bmux --help` -> `bmux - control bmux via Unix socket`
- `bmux --help` -> `open <path-or-url>...`
- `bmux help` -> `bmux - control bmux via Unix socket`
- `bmux ping --help` -> `Usage: bmux ping`
- `bmux capabilities --help` -> `Usage: bmux capabilities`
- `bmux events --help` -> `Usage: bmux events [options]`
- `bmux auth --help` -> `Usage: bmux auth <status|login|logout>`
- `bmux vm --help` -> `Usage: bmux vm <base|new|ls|status|snapshot|fork|restore|rm|exec|shell|attach|ssh|ssh-info> [args...]`
- `bmux cloud --help` -> `Usage: bmux cloud <base|new|ls|status|snapshot|fork|restore|rm|exec|shell|attach|ssh|ssh-info> [args...]`
- `bmux remotes --help` -> `Usage: bmux remotes <list|add|remove> [options]`
- `bmux remote --help` -> `Usage: bmux remotes <list|add|remove> [options]`
- `bmux provenance --help` -> `bmux provenance sessions related <pe-session-id>`
- `bmux provenance sessions --help` -> `Usage: bmux provenance sessions <tree|related|collisions> [...]`
- `bmux provenance sessions tree --help` -> `bmux provenance sessions tree <session-id>`
- `bmux provenance sessions related --help` -> `Usage: bmux provenance sessions related <pe-session-id>`
- `bmux provenance sessions collisions --help` -> `Usage: bmux provenance sessions collisions <pe-session-id>`
- `bmux provenance turn outcome --help` -> `bmux provenance turn outcome <turn-id>`
- `bmux provenance session outcome --help` -> `bmux provenance session outcome <session-id>`
- `bmux provenance explain --help` -> `bmux provenance explain <path>`
- `bmux rpc --help` -> `Usage: bmux rpc <method> [json-params]`
- `bmux help --help` -> `Usage: bmux help`
- `bmux docs --help` -> `Usage: bmux docs [settings|shortcuts|api|browser|agents|dock]`
- `bmux docs` -> `Topics:`
- `bmux docs settings` -> `Config files:`
- `bmux docs dock` -> `dock: Custom right-sidebar terminal controls`
- `bmux settings --help` -> `Usage: bmux settings [open [target]|path|docs|<target>]`
- `bmux settings path` -> `Config files:`
- `bmux settings docs` -> `Config files:`
- `bmux config --help` -> `Usage: bmux config <doctor|check|validate|path|paths|docs|documentation|reload|get|set|sidebar-font-size|surface-tab-bar-font-size>`
- `bmux config path` -> `Config files:`
- `bmux config docs` -> `Config files:`
- `bmux welcome --help` -> `Usage: bmux welcome`
- `bmux welcome` -> `Toggle Left Sidebar`
- `bmux welcome` -> `Toggle Right Sidebar`
- `bmux shortcuts --help` -> `Usage: bmux shortcuts`
- `bmux disable-browser --help` -> `Usage: bmux disable-browser [--json]`
- `bmux enable-browser --help` -> `Usage: bmux enable-browser [--json]`
- `bmux browser-status --help` -> `Usage: bmux browser-status [--json]`
- `bmux agent-hibernation --help` -> `Usage: bmux agent-hibernation <on|off> [--json]`
- `bmux restore-session --help` -> `Usage: bmux restore-session`
- `bmux open --help` -> `Usage: bmux open <path-or-url>...`
- `bmux feedback --help` -> `Usage: bmux feedback`
- `bmux feed --help` -> `Usage: bmux feed tui [--opentui|--legacy]`
- `bmux hooks --help` -> `Usage: bmux hooks setup [agent] [--agent <name>] [--yes|-y]`
- `bmux codex --help` -> `Usage: bmux codex <install-hooks|uninstall-hooks|token-audit>`
- `bmux themes --help` -> `Usage: bmux themes`
- `bmux omo --help` -> `Usage: bmux omo [opencode-args...]`
- `bmux omx --help` -> `Usage: bmux omx [omx-args...]`
- `bmux omc --help` -> `Usage: bmux omc [omc-args...]`
- `bmux identify --help` -> `Usage: bmux identify`
- `bmux list-windows --help` -> `Usage: bmux list-windows`
- `bmux current-window --help` -> `Usage: bmux current-window`
- `bmux new-window --help` -> `Usage: bmux new-window`
- `bmux focus-window --help` -> `Usage: bmux focus-window --window <id|ref|index>`
- `bmux close-window --help` -> `Usage: bmux close-window --window <id|ref|index>`
- `bmux move-workspace-to-window --help` -> `Usage: bmux move-workspace-to-window`
- `bmux move-surface --help` -> `Usage: bmux move-surface`
- `bmux split-off --help` -> `Usage: bmux split-off`
- `bmux reorder-surface --help` -> `Usage: bmux reorder-surface`
- `bmux reorder-workspace --help` -> `Usage: bmux reorder-workspace`
- `bmux reorder-workspaces --help` -> `Usage: bmux reorder-workspaces`
- `bmux workspace-action --help` -> `Usage: bmux workspace-action --action <name>`
- `bmux move-tab-to-new-workspace --help` -> `Usage: bmux move-tab-to-new-workspace`
- `bmux tab-action --help` -> `Usage: bmux tab-action --action <name>`
- `bmux rename-tab --help` -> `Usage: bmux rename-tab`
- `bmux new-workspace --help` -> `Usage: bmux new-workspace`
- `bmux list-workspaces --help` -> `Usage: bmux list-workspaces`
- `bmux ssh --help` -> `Usage: bmux ssh <destination>`
- `bmux ssh --help` -> `--forward-agent`
- `bmux ssh-session-list --help` -> `Usage: bmux ssh-session-list`
- `bmux ssh-session-attach --help` -> `Usage: bmux ssh-session-attach --session-id <id>`
- `bmux ssh-session-cleanup --help` -> `Usage: bmux ssh-session-cleanup`
- `bmux new-split --help` -> `Usage: bmux new-split`
- `bmux list-panes --help` -> `Usage: bmux list-panes`
- `bmux list-pane-surfaces --help` -> `Usage: bmux list-pane-surfaces`
- `bmux tree --help` -> `Usage: bmux tree`
- `bmux top --help` -> `Usage: bmux top`
- `bmux focus-pane --help` -> `Usage: bmux focus-pane`
- `bmux new-pane --help` -> `Usage: bmux new-pane`
- `bmux new-surface --help` -> `Usage: bmux new-surface`
- `bmux close-surface --help` -> `Usage: bmux close-surface`
- `bmux drag-surface-to-split --help` -> `Usage: bmux drag-surface-to-split`
- `bmux refresh-surfaces --help` -> `Usage: bmux refresh-surfaces`
- `bmux reload-config --help` -> `Usage: bmux reload-config`
- `bmux surface-health --help` -> `Usage: bmux surface-health`
- `bmux debug-terminals --help` -> `Usage: bmux debug-terminals`
- `bmux trigger-flash --help` -> `Usage: bmux trigger-flash`
- `bmux list-panels --help` -> `Usage: bmux list-panels`
- `bmux focus-panel --help` -> `Usage: bmux focus-panel`
- `bmux close-workspace --help` -> `Usage: bmux close-workspace`
- `bmux select-workspace --help` -> `Usage: bmux select-workspace`
- `bmux rename-workspace --help` -> `Usage: bmux rename-workspace`
- `bmux rename-window --help` -> `Usage: bmux rename-workspace`
- `bmux current-workspace --help` -> `Usage: bmux current-workspace`
- `bmux capture-pane --help` -> `Usage: bmux capture-pane`
- `bmux resize-pane --help` -> `Usage: bmux resize-pane`
- `bmux pipe-pane --help` -> `Usage: bmux pipe-pane`
- `bmux wait-for --help` -> `Usage: bmux wait-for`
- `bmux swap-pane --help` -> `Usage: bmux swap-pane`
- `bmux break-pane --help` -> `Usage: bmux break-pane`
- `bmux join-pane --help` -> `Usage: bmux join-pane`
- `bmux next-window --help` -> `Usage: bmux next-window`
- `bmux previous-window --help` -> `Usage: bmux previous-window`
- `bmux last-window --help` -> `Usage: bmux last-window`
- `bmux last-pane --help` -> `Usage: bmux last-pane`
- `bmux find-window --help` -> `Usage: bmux find-window`
- `bmux clear-history --help` -> `Usage: bmux clear-history`
- `bmux set-hook --help` -> `Usage: bmux set-hook`
- `bmux popup --help` -> `Usage: bmux popup`
- `bmux bind-key --help` -> `Usage: bmux bind-key`
- `bmux unbind-key --help` -> `Usage: bmux unbind-key`
- `bmux copy-mode --help` -> `Usage: bmux copy-mode`
- `bmux set-buffer --help` -> `Usage: bmux set-buffer`
- `bmux paste-buffer --help` -> `Usage: bmux paste-buffer`
- `bmux list-buffers --help` -> `Usage: bmux list-buffers`
- `bmux respawn-pane --help` -> `Usage: bmux respawn-pane`
- `bmux display-message --help` -> `Usage: bmux display-message`
- `bmux read-screen --help` -> `Usage: bmux read-screen`
- `bmux send --help` -> `Usage: bmux send`
- `bmux send-key --help` -> `Usage: bmux send-key`
- `bmux send-panel --help` -> `Usage: bmux send-panel`
- `bmux send-key-panel --help` -> `Usage: bmux send-key-panel`
- `bmux notify --help` -> `Usage: bmux notify`
- `bmux list-notifications --help` -> `Usage: bmux list-notifications`
- `bmux dismiss-notification --help` -> `Usage: bmux dismiss-notification`
- `bmux mark-notification-read --help` -> `Usage: bmux mark-notification-read`
- `bmux open-notification --help` -> `Usage: bmux open-notification`
- `bmux jump-to-unread --help` -> `Usage: bmux jump-to-unread`
- `bmux clear-notifications --help` -> `Usage: bmux clear-notifications`
- `bmux right-sidebar --help` -> `Usage: bmux right-sidebar <command> [flags]`
- `bmux set-status --help` -> `Usage: bmux set-status`
- `bmux clear-status --help` -> `Usage: bmux clear-status`
- `bmux list-status --help` -> `Usage: bmux list-status`
- `bmux set-progress --help` -> `Usage: bmux set-progress`
- `bmux clear-progress --help` -> `Usage: bmux clear-progress`
- `bmux log --help` -> `Usage: bmux log`
- `bmux clear-log --help` -> `Usage: bmux clear-log`
- `bmux list-log --help` -> `Usage: bmux list-log`
- `bmux sidebar-state --help` -> `Usage: bmux sidebar-state`
- `bmux set-app-focus --help` -> `Usage: bmux set-app-focus`
- `bmux simulate-app-active --help` -> `Usage: bmux simulate-app-active`
- `bmux claude-hook --help` -> `Usage: bmux claude-hook`
- `bmux browser --help` -> `Usage: bmux browser`
- `bmux open-browser --help` -> `Legacy alias for 'bmux browser open'`
- `bmux navigate --help` -> `Legacy alias for 'bmux browser navigate'`
- `bmux browser-back --help` -> `Legacy alias for 'bmux browser back'`
- `bmux browser-forward --help` -> `Legacy alias for 'bmux browser forward'`
- `bmux browser-reload --help` -> `Legacy alias for 'bmux browser reload'`
- `bmux get-url --help` -> `Legacy alias for 'bmux browser get-url'`
- `bmux focus-webview --help` -> `Legacy alias for 'bmux browser focus-webview'`
- `bmux is-webview-focused --help` -> `Legacy alias for 'bmux browser is-webview-focused'`
- `bmux markdown --help` -> `Usage: bmux markdown open <path>`
<!-- cli-contract-help-probes:end -->

## No-Socket Negative Help Probes

The following probes must not print help. They protect argument forwarding after
`--`, where a forwarded `--help` token belongs to the command payload.

<!-- cli-contract-negative-help-probes:start -->
- `bmux vm exec demo -- --help` !> `Usage: bmux vm`
<!-- cli-contract-negative-help-probes:end -->

## Current Help Caveats

These are current contracts to preserve until a follow-up PR intentionally
changes them:

- `bmux version --help` currently prints the version summary because `version`
  is handled before subcommand help dispatch.
- `bmux claude-teams --help` is handled by the command launcher, not by the
  pre-socket help dispatcher.
- `bmux codex-teams --help` is handled by the command launcher, not by the
  pre-socket help dispatcher.
- `bmux remote-daemon-status --help` currently prints status because the command
  runs before subcommand help dispatch.

## ArgumentParser Migration Sequence

1. Keep this contract file and `tests/test_cli_contract_help.py` green.
2. Add Swift ArgumentParser as a dependency without changing behavior.
3. Introduce a parse-only facade that maps ArgumentParser command structs onto
   existing `BMUXCLI` runner methods.
4. Move one command family at a time into small files, starting with no-socket
   commands (`version`, `themes`, hook installers), then socket commands, then
   browser and tmux compatibility.
5. After each family moves, run the contract probes plus targeted socket tests in
   GitHub Actions.
6. When all command families are migrated, remove the manual global parser and
   legacy helper code that no longer owns behavior.
