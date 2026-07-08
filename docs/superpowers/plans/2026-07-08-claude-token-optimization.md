# Claude Token Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Route eligible Claude Code Bash tool calls through cmux's existing token optimization proxy using the shared `terminal.agentTokenOptimization.mode` setting.

**Architecture:** Add a synchronous Claude `PreToolUse` hook for `Bash` tool calls before the existing async telemetry hook. Reuse the Codex optimizer parsing, eligibility, proxy command construction, and proxy execution path by generalizing Codex-specific helpers into agent-neutral helpers. Preserve Claude's existing CronCreate guard, Feed telemetry, and permission semantics.

**Tech Stack:** Bash wrapper settings JSON, Swift CLI hook handling, Python regression tests, cmux `TokenOptimizationLayer`.

---

## File Structure

- Modify `tests/test_claude_wrapper_hooks.py`: assert the Claude wrapper injects a synchronous `Bash` optimizer hook while retaining the sync `CronCreate` guard and async status hook.
- Modify `tests/test_codex_feed_hooks.py`: add Claude optimizer hook CLI regressions next to the existing Codex optimizer/proxy tests, because this file already owns `resolve_cmux_cli`, fake socket helpers, and direct CLI hook execution.
- Modify `Resources/bin/cmux-claude-wrapper`: add the new `PreToolUse` matcher group for `Bash` before the async `pre-tool-use` telemetry group.
- Modify `CLI/CMUXCLI+CodexFireAndForgetHooks.swift`: generalize the existing Codex optimizer helpers and add `runClaudeOptimizePreToolUseHook()`.
- Modify `CLI/cmux.swift`: dispatch `cmux hooks claude optimize-pre-tool-use` and optionally update the hidden usage text.
- No localization updates are expected because no new user-facing text is added.

## Task 1: Wrapper Hook Regression

**Files:**
- Modify: `tests/test_claude_wrapper_hooks.py`
- Modify: `Resources/bin/cmux-claude-wrapper`

- [ ] **Step 1: Write the failing wrapper test**

In `test_live_socket_injects_supported_hooks_without_unlocking_bypass`, after the `cron_guard_groups` assertions and before the general async `pre-tool-use` assertion, add:

```python
    optimizer_groups = [group for group in pre_tool_use_groups if group.get("matcher") == "Bash"]
    expect(optimizer_groups, f"PreToolUse should install a Bash optimizer hook, got {pre_tool_use_groups}", failures)
    if optimizer_groups:
        optimizer_hooks = optimizer_groups[0].get("hooks", [])
        expect(
            any(
                h.get("command") == '"${CMUX_CLAUDE_HOOK_CMUX_BIN:-cmux}" hooks claude optimize-pre-tool-use'
                and h.get("async") is not True
                for h in optimizer_hooks
            ),
            f"Bash optimizer should synchronously call hooks claude optimize-pre-tool-use, got {optimizer_hooks}",
            failures,
        )
        bash_index = pre_tool_use_groups.index(optimizer_groups[0])
        telemetry_index = next(
            (
                idx
                for idx, group in enumerate(pre_tool_use_groups)
                if any("hooks claude pre-tool-use" in h.get("command", "") for h in group.get("hooks", []))
            ),
            -1,
        )
        expect(
            telemetry_index == -1 or bash_index < telemetry_index,
            f"Bash optimizer should run before async telemetry, got {pre_tool_use_groups}",
            failures,
        )
```

- [ ] **Step 2: Run wrapper test to verify failure**

Run:

```bash
PYTHONPYCACHEPREFIX=/private/tmp/cmux-pycache python3 tests/test_claude_wrapper_hooks.py
```

Expected: FAIL with a message containing `PreToolUse should install a Bash optimizer hook`.

- [ ] **Step 3: Add the wrapper hook**

In `Resources/bin/cmux-claude-wrapper`, update the `PreToolUse` section of `HOOKS_JSON` from:

```json
"PreToolUse":[{"matcher":"CronCreate","hooks":[{"type":"command","command":"\"${CMUX_CLAUDE_HOOK_CMUX_BIN:-cmux}\" hooks claude cron-create-guard","timeout":5}]},{"matcher":"","hooks":[{"type":"command","command":"\"${CMUX_CLAUDE_HOOK_CMUX_BIN:-cmux}\" hooks claude pre-tool-use","timeout":5,"async":true}]}]
```

to:

```json
"PreToolUse":[{"matcher":"CronCreate","hooks":[{"type":"command","command":"\"${CMUX_CLAUDE_HOOK_CMUX_BIN:-cmux}\" hooks claude cron-create-guard","timeout":5}]},{"matcher":"Bash","hooks":[{"type":"command","command":"\"${CMUX_CLAUDE_HOOK_CMUX_BIN:-cmux}\" hooks claude optimize-pre-tool-use","timeout":5}]},{"matcher":"","hooks":[{"type":"command","command":"\"${CMUX_CLAUDE_HOOK_CMUX_BIN:-cmux}\" hooks claude pre-tool-use","timeout":5,"async":true}]}]
```

Also update the nearby wrapper comment to mention that the synchronous Bash optimizer may rewrite eligible commands before execution.

- [ ] **Step 4: Run wrapper test to verify pass**

Run:

```bash
PYTHONPYCACHEPREFIX=/private/tmp/cmux-pycache python3 tests/test_claude_wrapper_hooks.py
```

Expected: PASS.

## Task 2: Claude Optimizer CLI Hook

**Files:**
- Modify: `tests/test_codex_feed_hooks.py`
- Modify: `CLI/CMUXCLI+CodexFireAndForgetHooks.swift`
- Modify: `CLI/cmux.swift`

- [ ] **Step 1: Write failing Claude optimizer tests**

In `tests/test_codex_feed_hooks.py`, add:

```python
CMUX_AGENT_OPTIMIZER_HOOK_SUBCOMMAND = "optimize-pre-tool-use"
```

Then add these test functions after `test_codex_optimize_pre_tool_use_ignores_ineligible_command`:

```python
def test_claude_optimize_pre_tool_use_rewrites_bash_command(cli_path: str, root: Path) -> None:
    payload = {
        "session_id": "claude-session",
        "cwd": str(root),
        "hook_event_name": "PreToolUse",
        "tool_name": "Bash",
        "tool_input": {"command": "rg token Sources", "description": "Search token references"},
    }
    env = os.environ.copy()
    env["CMUX_SURFACE_ID"] = FAKE_SURFACE_ID
    env["CMUX_BUNDLED_CLI_PATH"] = cli_path

    result = subprocess.run(
        [cli_path, "hooks", "claude", CMUX_AGENT_OPTIMIZER_HOOK_SUBCOMMAND],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
        check=False,
        env=env,
        timeout=10,
    )
    if result.returncode != 0:
        raise AssertionError(
            f"claude optimize-pre-tool-use failed exit={result.returncode}\nstdout={result.stdout}\nstderr={result.stderr}"
        )
    stdout = json.loads(result.stdout)
    hook_output = stdout.get("hookSpecificOutput")
    if not isinstance(hook_output, dict):
        raise AssertionError(f"missing hookSpecificOutput: {stdout!r}")
    if hook_output.get("hookEventName") != "PreToolUse":
        raise AssertionError(f"wrong hook event: {hook_output!r}")
    if hook_output.get("permissionDecision") != "allow":
        raise AssertionError(f"optimizer should allow the rewritten command: {hook_output!r}")
    updated_input = hook_output.get("updatedInput")
    if not isinstance(updated_input, dict):
        raise AssertionError(f"missing updatedInput: {hook_output!r}")
    if updated_input.get("description") != "Search token references":
        raise AssertionError(f"updatedInput should preserve other Bash fields, got {updated_input!r}")
    command = updated_input.get("command")
    if not isinstance(command, str) or "agent-token-proxy" not in command:
        raise AssertionError(f"expected proxy command, got {command!r}")
    if "rg token Sources" in command:
        raise AssertionError(f"original command should be hex-wrapped, got {command!r}")


def test_claude_optimize_pre_tool_use_ignores_ineligible_command(cli_path: str, root: Path) -> None:
    payload = {
        "session_id": "claude-session",
        "cwd": str(root),
        "hook_event_name": "PreToolUse",
        "tool_name": "Bash",
        "tool_input": {"command": "echo plain"},
    }
    env = os.environ.copy()
    env["CMUX_SURFACE_ID"] = FAKE_SURFACE_ID
    env["CMUX_BUNDLED_CLI_PATH"] = cli_path

    result = subprocess.run(
        [cli_path, "hooks", "claude", CMUX_AGENT_OPTIMIZER_HOOK_SUBCOMMAND],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
        check=False,
        env=env,
        timeout=10,
    )
    if result.returncode != 0:
        raise AssertionError(
            f"claude optimize-pre-tool-use failed exit={result.returncode}\nstdout={result.stdout}\nstderr={result.stderr}"
        )
    stdout = json.loads(result.stdout)
    if stdout != {}:
        raise AssertionError(f"ineligible Claude command should not be rewritten: {stdout!r}")
```

Call both tests from `main()` immediately after the Codex optimizer tests.

- [ ] **Step 2: Run CLI tests to verify failure**

Run with a built CLI:

```bash
CMUX_CLI_BIN="/Users/brianbusby/Library/Developer/Xcode/DerivedData/cmux-token-proxy/Build/Products/Debug/cmux DEV token-proxy.app/Contents/Resources/bin/cmux" PYTHONPYCACHEPREFIX=/private/tmp/cmux-pycache python3 tests/test_codex_feed_hooks.py
```

Expected: FAIL because `hooks claude optimize-pre-tool-use` is not dispatched.

- [ ] **Step 3: Generalize optimizer helpers and add Claude hook**

In `CLI/CMUXCLI+CodexFireAndForgetHooks.swift`, implement:

```swift
func runClaudeOptimizePreToolUseHook() throws {
    let env = ProcessInfo.processInfo.environment
    guard env["CMUX_SURFACE_ID"]?.isEmpty == false,
          env["CMUX_CLAUDE_HOOKS_DISABLED"] != "1",
          Self.currentAgentTokenOptimizationMode() != .off
    else {
        print("{}")
        return
    }

    let stdinData = FileHandle.standardInput.readDataToEndOfFile()
    guard !stdinData.isEmpty,
          let payload = try? JSONSerialization.jsonObject(with: stdinData) as? [String: Any]
    else {
        print("{}")
        return
    }

    let eventName = Self.agentHookString(in: payload, keys: ["hook_event_name", "event"]) ?? ""
    let toolName = Self.agentHookString(in: payload, keys: ["tool_name", "toolName"]) ?? ""
    guard eventName == "PreToolUse", toolName == "Bash" else {
        print("{}")
        return
    }

    guard var updatedInput = Self.agentHookToolInputDictionary(from: payload),
          let commandKey = Self.agentHookCommandKey(in: updatedInput),
          let command = updatedInput[commandKey] as? String,
          Self.agentHookCommandEligibleForTokenProxy(command)
    else {
        print("{}")
        return
    }

    let cwd = Self.agentHookString(in: payload, keys: ["cwd"])
        ?? Self.agentHookString(in: updatedInput, keys: ["cwd", "workdir", "working_directory"])
    updatedInput[commandKey] = Self.agentTokenProxyShellCommand(command: command, cwd: cwd)

    try Self.writeAgentHookJSONObject([
        "hookSpecificOutput": [
            "hookEventName": "PreToolUse",
            "permissionDecision": "allow",
            "updatedInput": updatedInput,
        ] as [String: Any],
        "decision": "approve",
    ] as [String: Any])
}
```

Rename the existing private helper methods so both Codex and Claude use them:

- `codexHookToolInputDictionary` -> `agentHookToolInputDictionary`
- `codexHookJSONDictionary` -> `agentHookJSONDictionary`
- `codexHookString` -> `agentHookString`
- `codexHookCommandKey` -> `agentHookCommandKey`
- `codexHookCommandEligibleForTokenProxy` -> `agentHookCommandEligibleForTokenProxy`
- `codexAgentTokenProxyShellCommand` -> `agentTokenProxyShellCommand`
- `writeCodexHookJSONObject` -> `writeAgentHookJSONObject`

Update `runCodexOptimizePreToolUseHook()` to call the renamed helpers.

- [ ] **Step 4: Dispatch the Claude hook**

In `CLI/cmux.swift`, inside the `runHooksPreSocketCommand` `case "claude"` handling, add a hidden branch for:

```swift
if subcommand == "optimize-pre-tool-use" {
    try runClaudeOptimizePreToolUseHook()
    return true
}
```

Place it before socket-requiring Claude hook handling so it can run without contacting the cmux socket, like the Codex optimizer hook.

- [ ] **Step 5: Run CLI tests to verify pass**

First build the tagged Debug app so the CLI includes the Swift changes:

```bash
./scripts/reload.sh --tag claude-token-proxy
```

Then run:

```bash
CMUX_CLI_BIN="/Users/brianbusby/Library/Developer/Xcode/DerivedData/cmux-claude-token-proxy/Build/Products/Debug/cmux DEV claude-token-proxy.app/Contents/Resources/bin/cmux" PYTHONPYCACHEPREFIX=/private/tmp/cmux-pycache python3 tests/test_codex_feed_hooks.py
```

Expected: PASS.

## Task 3: Verification and Build

**Files:**
- Verify all modified files.

- [ ] **Step 1: Run syntax checks**

Run:

```bash
PYTHONPYCACHEPREFIX=/private/tmp/cmux-pycache python3 -m py_compile tests/test_claude_wrapper_hooks.py tests/test_codex_feed_hooks.py
```

Expected: no output and exit 0.

- [ ] **Step 2: Run wrapper regression**

Run:

```bash
PYTHONPYCACHEPREFIX=/private/tmp/cmux-pycache python3 tests/test_claude_wrapper_hooks.py
```

Expected: PASS.

- [ ] **Step 3: Build tagged Debug app**

Run:

```bash
./scripts/reload.sh --tag claude-token-proxy
```

Expected: Debug build succeeds and prints an `App path:` for `cmux DEV claude-token-proxy.app`.

- [ ] **Step 4: Run CLI hook regression against built CLI**

Run with the CLI path from the tagged build:

```bash
CMUX_CLI_BIN="/Users/brianbusby/Library/Developer/Xcode/DerivedData/cmux-claude-token-proxy/Build/Products/Debug/cmux DEV claude-token-proxy.app/Contents/Resources/bin/cmux" PYTHONPYCACHEPREFIX=/private/tmp/cmux-pycache python3 tests/test_codex_feed_hooks.py
```

Expected: PASS.

- [ ] **Step 5: Run project consistency checks**

Run:

```bash
scripts/check-pbxproj.sh
git diff --check -- Resources/bin/cmux-claude-wrapper CLI/CMUXCLI+CodexFireAndForgetHooks.swift CLI/cmux.swift tests/test_claude_wrapper_hooks.py tests/test_codex_feed_hooks.py
```

Expected: both commands exit 0.

- [ ] **Step 6: Localization audit**

Confirm no new user-facing strings were added. If a new CLI-visible error string is introduced during implementation, add it to `Resources/Localizable.xcstrings` for English and Japanese and parse the JSON file.
