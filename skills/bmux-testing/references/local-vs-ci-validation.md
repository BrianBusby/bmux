# Local vs CI Validation

## Iteration cadence

Use focused tests as the primary loop while designing or fixing a slice. They are
faster, compile the relevant test targets, and keep failures close to the
behavior being changed.

Before pushing a PR update that changes production app/runtime behavior, run the
focused tests for the affected surface plus:

```bash
./scripts/reload.sh --tag <branch-slug>
```

Before dogfood or handoff of runtime behavior, run a tagged reload and then use
targeted CLI/socket dogfood against that tag when relevant.

For test-only stabilization, do not run a tagged reload unless production code
changed.

## `reload.sh`

`reload.sh` builds the Debug app for a tag. It does not compile the test target.

A successful reload proves the app target built. It does not prove:

- `bmuxTests` compile
- `bmuxUITests` compile
- package test targets compile
- test-only imports still resolve

For package/refactor work, treat reload as insufficient by itself.

## Unit test target

`xcodebuild -scheme bmux-unit` is safe because it does not launch the app. Prefer CI when practical, but use `bmux-unit` when package/refactor changes can break tests while the app target still builds.

Use a tagged derived data path:

```bash
xcodebuild -project bmux.xcodeproj -scheme bmux-unit -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/bmux-<tag> build
```

For `bmuxApp` or `AppDelegate` churn, include the repo's known GlobalISel workaround flag if required by current project instructions.

## E2E and UI tests

E2E and UI tests run via GitHub Actions or on the VM. Trigger E2E/UI through:

```bash
gh workflow run test-e2e.yml
```

Do not launch an untagged app locally to satisfy socket/UI tests.

## Python socket tests

Python socket tests under `tests_v2/` connect to a running bmux instance socket. If they must be run locally, use a tagged build socket:

```bash
BMUX_SOCKET_PATH=/tmp/bmux-debug-<tag>.sock
```

Never launch or target an untagged `bmux DEV.app` for these tests. It can conflict with the user's running debug instance.
