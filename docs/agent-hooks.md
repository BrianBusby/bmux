# Agent hook integrations

bmux uses agent hooks to show running state, Feed approvals, notifications, and to restore agent sessions after a normal app relaunch.

Claude Code is handled by the bmux Claude wrapper when Claude Code integration is enabled in Settings. Other agents are installed with:

```bash
bmux hooks setup
bmux hooks setup <agent>
bmux hooks setup --agent <agent>
bmux hooks uninstall <agent>
```

Supported agent names are `codex`, `grok`, `opencode`, `pi`, `omp`, `amp`, `cursor`, `gemini`, `kimi`, `kiro`, `rovodev` (or `rovo`), `copilot`, `codebuddy`, `factory`, and `qoder`. `bmux hooks setup` skips agents whose binary is not on `PATH` and prints a summary.

## Integrations

| Agent | Binary checked | Installed file | Session restore | Feed bridge |
| --- | --- | --- | --- | --- |
| Claude Code | `claude` through wrapper | wrapper-injected settings | `claude --resume <id>` | PermissionRequest |
| Codex | `codex` | `~/.codex/hooks.json`, `~/.codex/config.toml` | `codex resume <id>` | PreToolUse, PermissionRequest telemetry |
| Grok | `grok` | `~/.grok/hooks/bmux-session.json` | `grok -r <id>` | PreToolUse |
| OpenCode | `opencode` | `~/.config/opencode/plugins/bmux-session.js`, `~/.config/opencode/plugins/bmux-feed.js` | `opencode --session <id>` | plugin event bus |
| Pi | `pi` | `~/.pi/agent/extensions/bmux-session.ts` | `pi --session <id>` | tool_execution_start / tool_execution_end telemetry |
| OMP | `omp` | `~/.omp/agent/extensions/bmux-omp-session.ts` or `$PI_CODING_AGENT_DIR/extensions/bmux-omp-session.ts` | `omp --session <id>` | none |
| Amp | `amp` | `~/.config/amp/plugins/bmux-session.ts` | `amp threads continue <id>` | none |
| Cursor CLI | `cursor-agent` | `~/.cursor/hooks.json` | `cursor-agent --resume <id>` | beforeShellExecution |
| Gemini | `gemini` | `~/.gemini/settings.json` | `gemini --resume <id>` | PreToolUse |
| Kiro CLI | `kiro-cli` | `~/.kiro/agents/bmux.json` or `$KIRO_HOME/agents/bmux.json` | `kiro-cli chat --resume-id <id>` | preToolUse, postToolUse |
| Rovo Dev | `acli` | `~/.rovodev/config.yml` | `acli rovodev run --restore <id>` | none |
| Copilot | `copilot` | `~/.copilot/config.json` | `copilot --resume <id>` | PreToolUse |
| CodeBuddy | `codebuddy` | `~/.codebuddy/settings.json` | `codebuddy --resume <id>` | PreToolUse |
| Factory | `droid` | `~/.factory/settings.json` | `droid --resume <id>` | PreToolUse |
| Qoder | `qodercli` | `~/.qoder/settings.json` | `qodercli --resume <id>` | PreToolUse |
| Kimi Code | `kimi` | `~/.kimi-code/config.toml` | not yet | PreToolUse, PostToolUse, PermissionRequest |

OpenCode also supports project-local Feed installation:

```bash
bmux hooks opencode install --project
```

That writes `.opencode/plugins/bmux-feed.js` in the current directory.

## What the hooks record

Session hooks write `~/.bmuxterm/<agent>-hook-sessions.json`. Each entry stores the agent session ID, bmux workspace ID, surface ID, cwd, process ID when available, current lifecycle (`running`, `idle`, `needsInput`, or `unknown`), and a sanitized launch command. On app relaunch, bmux rebuilds each workspace and runs the agent's native resume command with the saved session ID.

The sanitizer preserves model, sandbox, config, and cwd-related flags. It drops prompts, credentials, old session selectors, and noninteractive commands so relaunch resumes the session instead of starting a new task or leaking secrets.

Claude Code's `PushNotification` tool (model-initiated "notify the user now" pushes) is bridged through a `PostToolUse` hook into bmux notifications. The tool normally delivers via a raw OSC desktop notification, which bmux suppresses on surfaces running a hook-integrated agent, so the bridge is what makes those pushes visible inside bmux. It mirrors the tool's own outcome: a push the tool reports as skipped (user active, channel disabled) is not duplicated.

Grok uses its `Notification` hook for user-facing completion messages. bmux records `Stop` as idle state, but leaves the visible notification text to the `Notification` payload so repeated turns keep Grok's own message instead of a generic completion fallback.

## Workspace auto-naming

When the opt-in `automation.workspaceAutoNaming` setting is enabled, turn-end hooks also drive AI naming of workspaces and tabs. Supported adapters are Claude Code, Codex, Grok, OpenCode, Pi, and OMP; each adapter gates on the live setting over the socket, reuses the session store above for throttle state, summarizes with that agent's own CLI in a no-tools or isolated headless mode, and never overwrites a name the user set. Gemini, Amp, Cursor, Antigravity, Kiro, Rovo Dev, Hermes Agent, Copilot, CodeBuddy, Factory, and Qoder are skipped until they have both a verified conversation source and a safe cheap non-interactive summarizer runner. See [workspace-auto-naming.md](workspace-auto-naming.md).

## Agent Hibernation

Agent Hibernation kills idle background agent processes to free their RAM and CPU, then resumes each one with its saved session when you return to its tab. It is opt-in and off by default. bmux knows which process belongs to which terminal because the agent hooks associate each session ID with its surface (see the session-restore section above), so it can terminate the right process and bring back the right session.

### When a terminal hibernates

A live terminal is only ever a candidate when all of these hold:

- it has a saved restorable agent session, and the saved launch data can build a resume command
- the agent lifecycle is `idle` (not running, not waiting on input)
- the terminal is in the background (its panel is not currently visible)
- you have more live restorable agent terminals than the live-terminal limit (`maxLiveTerminals`, default `12`)
- the terminal has had no output, input, or lifecycle change for at least the idle window (`idleSeconds`, default `5`)

The live-terminal limit is the first gate. Under the limit, nothing hibernates no matter how long it sits idle. Once you are over the limit, bmux frees only the oldest-idle background terminals, just enough to get back under the limit. Visible terminals are never touched.

Before killing, bmux watches the terminal tail. It samples the last lines of output and a fingerprint of the process, and waits a short confirmation window (`confirmationSeconds`, ~60s) during which the output and process must stay unchanged. Any new output, input, lifecycle change, or PID change cancels the pending hibernation. This is why a small `idleSeconds` is safe: a freshly idle agent that resumes work on its own is never killed mid-task.

So with the defaults, hibernation only affects power users running more than 12 agents at once, and even then only ~1 minute after an agent has gone quiet off-screen.

### What gets killed and how it comes back

bmux sends `SIGTERM` to the agent's process group (scoped to that workspace and surface), then swaps the live terminal for a lightweight placeholder, releasing the terminal's memory and CPU. When you visit the tab again, bmux runs the agent's native resume command with the saved session ID, so the session continues where it left off. The placeholder also shows a Resume button as a manual fallback.

### Enable and configure

Enable from the command palette (`⌘⇧P` -> **Enable Agent Hibernation**), from **Settings > Terminal > Agent Hibernation**, or from the CLI:

```bash
bmux agent-hibernation on
bmux agent-hibernation off
```

Tune the idle window and live-terminal limit from Settings, or set them in `~/.config/bmux/bmux.json`:

```json
{
  "terminal": {
    "agentHibernation": {
      "enabled": true,
      "idleSeconds": 5,
      "maxLiveTerminals": 12
    }
  }
}
```

- `idleSeconds` (default `5`, range `5`-`604800`): how long a background idle agent terminal must be quiet before it can hibernate. Raise it to keep agents alive longer; lower it to reclaim resources sooner. The `confirmationSeconds` settle window still applies on top of this.
- `maxLiveTerminals` (default `12`, range `1`-`256`): how many live restorable agent terminals to keep before bmux hibernates the oldest idle background ones. Lower it to hibernate more aggressively; raise it to keep more agents live.

## Custom surface resume commands

Use `bmux surface resume set --shell <command>` to attach a resume command to the current terminal surface. Public CLI and socket-created commands are kept for inspection and manual restore by default. To auto-run one on restore, approve the prompt or change its signed command prefix in **Settings > Terminal > Resume Commands**.

Approvals are prefix-based and signed by bmux. They also bind the working directory and exact environment values when present. A process can propose a command, but it cannot make that command sticky without the user choosing Auto-Restore or Ask Each Time in bmux.

## Disable automatic resume

To restore panes without automatically restarting saved agent sessions, turn off
**Settings > Terminal > Resume Agent Sessions on Reopen**.

You can also set the same preference in `~/.config/bmux/bmux.json`:

```json
{
  "terminal": {
    "autoResumeAgentSessions": false
  }
}
```

When this is off, bmux still restores the saved window, workspace, pane, scrollback,
and browser state. Restored agent terminals stay idle until you resume them manually.

## Environment overrides

| Agent | Config directory override | Disable bmux hooks for one process |
| --- | --- | --- |
| Codex | `CODEX_HOME` | `BMUX_CODEX_HOOKS_DISABLED=1` |
| Grok | `GROK_HOME` | `BMUX_GROK_HOOKS_DISABLED=1` |
| OpenCode | `OPENCODE_CONFIG_DIR` | `BMUX_OPENCODE_HOOKS_DISABLED=1` |
| Pi | `PI_CODING_AGENT_DIR` | `BMUX_PI_HOOKS_DISABLED=1` |
| OMP | `PI_CODING_AGENT_DIR` for the full agent directory; otherwise `PI_CONFIG_DIR` for the config root | `BMUX_OMP_HOOKS_DISABLED=1` |
| Amp | none | `BMUX_AMP_HOOKS_DISABLED=1` |
| Cursor CLI | none | `BMUX_CURSOR_HOOKS_DISABLED=1` |
| Gemini | none | `BMUX_GEMINI_HOOKS_DISABLED=1` |
| Kiro CLI | `KIRO_HOME` | `BMUX_KIRO_HOOKS_DISABLED=1` |
| Kimi Code | `KIMI_CODE_HOME` | `BMUX_KIMI_HOOKS_DISABLED=1` |
| Rovo Dev | none | `BMUX_ROVODEV_HOOKS_DISABLED=1` |
| Copilot | `COPILOT_HOME` | `BMUX_COPILOT_HOOKS_DISABLED=1` |
| CodeBuddy | `CODEBUDDY_CONFIG_DIR` | `BMUX_CODEBUDDY_HOOKS_DISABLED=1` |
| Factory | none | `BMUX_FACTORY_HOOKS_DISABLED=1` |
| Qoder | `QODER_CONFIG_DIR` | `BMUX_QODER_HOOKS_DISABLED=1` |

Pi uses Pi's extension system, not the legacy Pi hooks API. The installed extension is auto-discovered from `~/.pi/agent/extensions/` or `$PI_CODING_AGENT_DIR/extensions/`.

OMP uses OMP's native extension system. OMP native extension discovery scans `${PI_CODING_AGENT_DIR:-~/${PI_CONFIG_DIR:-.omp}/agent}/extensions/`, so bmux installs OMP's extension with a distinct `bmux-omp-session.ts` filename and does not reuse Pi's `bmux-session.ts`.

Kiro stores hooks inside agent configuration files. The bmux installer creates or updates a `bmux` agent config with lifecycle, tool, and completion hooks; merge the generated `hooks` block into another Kiro agent config if you want the same bmux notifications on that agent.

Kiro Feed verbosity follows **Settings > Automation > Kiro Notification Level** or `automation.kiroNotificationLevel` in `bmux.json`. `minimal` keeps actionable approval cards only, `standard` also keeps mutating tool events, and `verbose` keeps every Kiro tool event.

## Troubleshooting

Run `bmux hooks <agent> install --yes` to reinstall one integration. Run `bmux hooks <agent> uninstall --yes` before editing generated files by hand.

If Feed shows nothing, confirm the terminal has `BMUX_SURFACE_ID` and the hook file contains a `bmux hooks feed --source <agent>` command, generated extension bridge, or OpenCode feed plugin. Pi reports non-blocking tool execution telemetry through its generated extension. OMP and Rovo Dev currently provide lifecycle and restore hooks only, so they do not create Feed approval cards. Amp's bundled plugin reports live tab-status updates (idle / thinking / running / reading / done / error / interrupted) and lifecycle restore but does not create Feed approval cards.

If relaunch does not resume an agent, check `~/.bmuxterm/<agent>-hook-sessions.json` for the saved session and verify the agent's resume command still works outside bmux.
