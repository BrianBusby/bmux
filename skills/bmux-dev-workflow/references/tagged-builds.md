# Tagged Builds

Tagged builds isolate app name, bundle ID, socket, and DerivedData path so multiple agents and the user's normal app do not collide.

## Cadence

Use focused tests while designing or fixing a slice. Before pushing a PR update
that changes production app/runtime behavior, run focused tests plus a tagged
reload. Before dogfood or handoff of runtime behavior, run a tagged reload and
targeted CLI/socket dogfood against that tag when relevant. For test-only
stabilization, skip tagged reload unless production code changed.

## Reload

Use:

```bash
./scripts/reload.sh --tag <tag>
```

`reload.sh` builds but does not launch by default. It terminates any running app with the same tag after a successful build, so opening the printed app path launches the fresh binary.

Use:

```bash
./scripts/reload.sh --tag <tag> --launch
```

only when the task requires launching.

## App path links

`reload.sh` prints:

```text
App path:
  /absolute/path/to/bmux DEV <tag>.app
```

Build chat links from that exact path. Prepend `file://` and URL-encode spaces as `%20`. Do not hardcode DerivedData paths and never use `/tmp/bmux-<tag>/...` app links in chat output.

## Tagged CLI and socket

For CLI or socket dogfood against a tagged Debug app, use:

```bash
BMUX_TAG=<tag> scripts/bmux-debug-cli.sh list-workspaces
BMUX_TAG=<tag> scripts/bmux-debug-cli.sh send --workspace workspace:1 --surface surface:1 "echo ok"
```

Do not use `/tmp/bmux-cli` for tagged dogfood. That symlink points at the most recently reloaded build and can target the user's main app socket.

The helper:

- refuses to run without `BMUX_TAG`
- targets `/tmp/bmux-debug-<tag>.sock`
- uses the matching tagged CLI from DerivedData
- scrubs ambient bmux terminal context
- sets `BMUX_SOCKET_PATH`, `BMUX_BUNDLE_ID`, and `BMUX_BUNDLED_CLI_PATH`

## Cleanup

Before launching a new tagged run, clean up older tags started in the same session:

- quit old tagged app
- remove its `/tmp` socket if stale
- remove derived data only when you are sure no active task needs it

Do not open an untagged `bmux DEV.app` from DerivedData. It shares the default debug socket and bundle ID with other agents.
