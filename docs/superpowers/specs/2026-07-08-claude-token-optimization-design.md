# Claude Token Optimization Design

## Context

cmux already has a command-output token optimization path for Codex. The Codex
wrapper installs a synchronous `PreToolUse` optimizer hook before telemetry. The
hook rewrites eligible shell commands to run through `cmux agent-token-proxy`,
which preserves the original command exit status while returning compact output
when `terminal.agentTokenOptimization.mode` is not `off`.

Claude Code is launched through `Resources/bin/cmux-claude-wrapper`, which
already injects Claude hooks through a merged `--settings` payload. Current
Claude hooks include a synchronous `PreToolUse` `CronCreate` guard, an async
general `PreToolUse` telemetry/status hook, and a synchronous
`PermissionRequest` Feed bridge.

Claude Code's current hook contract supports `PreToolUse` decisions with
`hookSpecificOutput.updatedInput`, including updated `Bash` tool input before a
command executes. This allows cmux to optimize Claude command output without
PATH shims or changes to Claude's permission UI.

## Decision

Claude token optimization will use the same existing
`terminal.agentTokenOptimization.mode` setting as Codex. When the setting is
`off`, Claude optimizer hooks return `{}` and tool execution proceeds unchanged.
When the setting is enabled, only eligible Claude `Bash` commands are rewritten.

The Claude wrapper will inject a synchronous `PreToolUse` hook with matcher
`Bash` before the existing async general `PreToolUse` telemetry hook. The new
hook will call `cmux hooks claude optimize-pre-tool-use`.

`cmux hooks claude optimize-pre-tool-use` will:

1. Read the Claude hook JSON payload from stdin.
2. Return `{}` unless token optimization is enabled, the event is `PreToolUse`,
   the tool is `Bash`, and the payload has a non-empty command.
3. Reuse the existing command eligibility rules and `agent-token-proxy` command
   construction from the Codex path.
4. Return Claude-compatible JSON containing
   `hookSpecificOutput.hookEventName = "PreToolUse"`,
   `permissionDecision = "allow"`, and `updatedInput` with the rewritten
   command.
5. Return `{}` for commands already routed through `agent-token-proxy` to avoid
   recursive wrapping.

The existing async Claude `pre-tool-use` hook remains responsible for status,
needs-input fallback behavior, and Feed telemetry. The existing `CronCreate`
guard remains synchronous and unchanged.

## Rejected Alternatives

- PATH shims for commands such as `rg`, `grep`, and `git`: broader command
  coverage, but it can affect scripts and subprocesses outside a Claude tool
  call.
- Transcript-only compression: lower risk, but it does not reduce the command
  output that Claude receives in model context.
- A separate Claude-specific setting: more granular, but the approved product
  behavior is to use the existing shared agent token optimization setting.

## Test Plan

- Add wrapper regression coverage proving the Claude `PreToolUse` settings now
  include a synchronous `Bash` optimizer hook, while the `CronCreate` guard
  remains synchronous and the general status/telemetry `pre-tool-use` hook
  remains async.
- Add CLI hook regression coverage for an eligible Claude `Bash` payload that
  expects `updatedInput.command` to call `agent-token-proxy`.
- Add CLI hook regression coverage for disabled/off-mode and ineligible payloads
  returning `{}`.
- Keep Codex regressions passing, since Claude will reuse the shared proxy and
  eligibility helpers introduced for Codex.

## Risks

- Claude versions before `PreToolUse.updatedInput` support may ignore the
  optimizer response. In that case, the command should still proceed normally,
  and cmux should not rely on PATH-level interception.
- A synchronous hook adds one process spawn to eligible Bash calls. The hook is
  scoped to matcher `Bash`, returns quickly for ineligible commands, and leaves
  telemetry async.
- The optimizer must preserve Claude's existing permission semantics. Returning
  `permissionDecision = "allow"` with updated input follows Claude's documented
  pre-tool input rewrite path and does not bypass deny rules.
