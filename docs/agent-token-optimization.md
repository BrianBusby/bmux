# Agent Token Optimization

cmux has a native token optimization layer for agent terminal output. The goal is
to keep complete terminal output available to users while sending shorter,
classified output through transcript consumers.

## Architecture

The shared entrypoint is `TokenOptimizationLayer` in `CmuxAgentChat`.
Callers provide:

- a stable message id
- the command
- complete raw output
- the exit code, when known

The layer returns:

- optimized output text
- classification and byte/line metadata
- a `ChatRawTerminalOutputRecord` containing the complete raw output

Raw output persistence is deliberately separate from compression. Transcript
tailers write raw records to the local raw-output store, while chat messages keep
only the optimized text plus a `rawOutputRef`. UI clients can use that reference
to expand or copy the full output.

## Compression Modes

`terminal.agentTokenOptimization.mode` controls the mode for new transcript
tailers:

- `off`: keep raw output unchanged.
- `conservative`: compress only low-risk repetitive success output.
- `balanced`: default native compression for recognized command categories.
- `aggressive`: currently follows balanced behavior; reserved for stronger
  reducers once they are proven safe.

## Current Coverage

The native compressor recognizes common terminal output categories:

- Git status/log/branch-style output
- passing and failing test output
- TypeScript diagnostics
- package installation progress
- search/listing commands such as `rg`, `grep`, `find`, `tree`, and `ls -R`

Errors are preserved preferentially. Repetitive successes and progress chatter
are compressed first.

## Codex Integration Boundary

Today this layer optimizes cmux's transcript and session-display path. It
preserves raw terminal output locally and reduces what cmux stores or forwards
through those chat surfaces.

Actual Codex model-token reduction requires a Codex-side hook where cmux can
replace terminal tool-result payloads before Codex consumes them. The current
Codex app-server integration observes command-output deltas and answers approval
requests, but it does not execute tools or rewrite tool-result payloads. That is
the remaining integration target.

## RTK Adapter

RTK can still be evaluated behind the same boundary. A future adapter should
implement the same shape as `TokenOptimizationLayer`: raw output in, optimized
text plus raw-output record out. Native compression remains the default because
it can preserve cmux and Codex workflow semantics directly.
