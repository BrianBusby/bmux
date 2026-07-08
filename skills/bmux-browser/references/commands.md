# Command Reference (bmux Browser)

This maps common `agent-browser` usage to `bmux browser` usage.

## Direct Equivalents

- `agent-browser open <url>` -> `bmux browser open <url>`
- `agent-browser goto|navigate <url>` -> `bmux browser <surface> goto|navigate <url>`
- `agent-browser snapshot -i` -> `bmux browser <surface> snapshot --interactive`
- `agent-browser click <ref>` -> `bmux browser <surface> click <ref>`
- `agent-browser fill <ref> <text>` -> `bmux browser <surface> fill <ref> <text>`
- `agent-browser type <ref> <text>` -> `bmux browser <surface> type <ref> <text>`
- `agent-browser select <ref> <value>` -> `bmux browser <surface> select <ref> <value>`
- `agent-browser get text <ref>` -> `bmux browser <surface> get text <ref-or-selector>`
- `agent-browser get url` -> `bmux browser <surface> get url`
- `agent-browser get title` -> `bmux browser <surface> get title`

## Core Command Groups

### Navigation

```bash
bmux browser open <url>                        # opens in caller's workspace (uses BMUX_WORKSPACE_ID)
bmux browser open <url> --workspace <id|ref>   # opens in a specific workspace
bmux browser <surface> goto <url>
bmux browser <surface> back|forward|reload
bmux browser <surface> get url|title
```

> **Workspace context:** `browser open` targets the workspace of the terminal where the command is run (via `BMUX_WORKSPACE_ID`), even if a different workspace is currently focused. Use `--workspace` to override.

### Snapshot and Inspection

```bash
bmux browser <surface> snapshot --interactive
bmux browser <surface> snapshot --interactive --compact --max-depth 3
bmux browser <surface> get text body
bmux browser <surface> get html body
bmux browser <surface> get value "#email"
bmux browser <surface> get attr "#email" --attr placeholder
bmux browser <surface> get count ".row"
bmux browser <surface> get box "#submit"
bmux browser <surface> get styles "#submit" --property color
bmux browser <surface> eval '<js>'
```

### Interaction

```bash
bmux browser <surface> click|dblclick|hover|focus <selector-or-ref>
bmux browser <surface> fill <selector-or-ref> [text]   # empty text clears
bmux browser <surface> type <selector-or-ref> <text>
bmux browser <surface> press|keydown|keyup <key>
bmux browser <surface> select <selector-or-ref> <value>
bmux browser <surface> check|uncheck <selector-or-ref>
bmux browser <surface> scroll [--selector <css>] [--dx <n>] [--dy <n>]
```

### Wait

```bash
bmux browser <surface> wait --selector "#ready" --timeout-ms 10000
bmux browser <surface> wait --text "Done" --timeout-ms 10000
bmux browser <surface> wait --url-contains "/dashboard" --timeout-ms 10000
bmux browser <surface> wait --load-state complete --timeout-ms 15000
bmux browser <surface> wait --function "document.readyState === 'complete'" --timeout-ms 10000
```

### Session/State

```bash
bmux browser <surface> cookies get|set|clear ...
bmux browser <surface> storage local|session get|set|clear ...
bmux browser <surface> tab list|new|switch|close ...
bmux browser <surface> state save|load <path>
```

### Diagnostics

```bash
bmux browser <surface> console list|clear
bmux browser <surface> errors list|clear
bmux browser <surface> highlight <selector>
bmux browser <surface> screenshot
bmux browser <surface> download wait --timeout-ms 10000
```

## Agent Reliability Tips

- Use `--snapshot-after` on mutating actions to return a fresh post-action snapshot.
- Re-snapshot after navigation, modal open/close, or major DOM changes.
- Prefer short handles in outputs by default (`surface:N`, `pane:N`, `workspace:N`, `window:N`).
- Use `--id-format both` only when a UUID must be logged/exported.

## Known WKWebView Gaps (`not_supported`)

- `browser.viewport.set`
- `browser.geolocation.set`
- `browser.offline.set`
- `browser.trace.start|stop`
- `browser.network.route|unroute|requests`
- `browser.screencast.start|stop`
- `browser.input_mouse|input_keyboard|input_touch`

See also:
- [snapshot-refs.md](snapshot-refs.md)
- [authentication.md](authentication.md)
- [session-management.md](session-management.md)
