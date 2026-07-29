import { ExecutionTelemetryFanout } from "../executionTelemetryFanout";
import {
  liveSessionProjectionPayload,
  replayLiveSessionProjection,
  LiveSessionProjection,
  LiveSessionProjectionStore,
} from "../executionTelemetryLiveProjection";
import type { AgentEvent } from "../types";
import type { TelemetryEventEnvelope, TelemetryEvent } from "../executionTelemetryTypes";

function assert(cond: unknown, message: string): asserts cond {
  if (!cond) throw new Error(message);
}

function envelope(
  sequence: number,
  event: TelemetryEvent,
  overrides: Partial<TelemetryEventEnvelope> = {},
): TelemetryEventEnvelope {
  return {
    schema: "bmux.execution-event.v1",
    eventId: `event-${sequence}`,
    sessionId: "session-live",
    sequence,
    capturedAtMs: 10_000 + sequence,
    source: "provider",
    provider: "codex",
    event,
    ...overrides,
  };
}

{
  const projection = new LiveSessionProjection();

  projection.apply(envelope(1, {
    type: "session.started",
    cwd: "/tmp/project",
    title: "live projection",
  }, { source: "sidecar" }));

  projection.apply(envelope(2, {
    type: "session.provider-linked",
    providerSessionId: "thread-live",
  }, {
    providerSessionId: "thread-live",
    providerEvent: { method: "thread/start" },
  }));

  projection.apply(envelope(3, {
    type: "prompt.submitted",
    text: "build the live state",
  }, { source: "sidecar" }));

  projection.apply(envelope(4, {
    type: "turn.started",
    turnId: "turn-live",
    model: "gpt-5",
  }, {
    providerSessionId: "thread-live",
    providerTurnId: "turn-live",
    providerEvent: { method: "turn/started", turnId: "turn-live" },
  }));

  projection.apply(envelope(5, {
    type: "tool.started",
    operationId: "op-shell",
    toolKind: "command",
    name: "shell",
    inputSummary: "npm test",
  }, {
    providerSessionId: "thread-live",
    providerTurnId: "turn-live",
  }));

  const blocked = projection.apply(envelope(6, {
    type: "approval.requested",
    approvalId: "approval-1",
    approvalKind: "command",
    operationId: "op-shell",
    summary: "npm test",
    requestedAtMs: 10_006,
  }, {
    providerSessionId: "thread-live",
    providerTurnId: "turn-live",
  }));

  assert(blocked.sessionId === "session-live", "snapshot session id changed");
  assert(blocked.provider === "codex", "snapshot provider changed");
  assert(blocked.providerSessionId === "thread-live", "provider session id should be projected");
  assert(blocked.currentProviderTurnId === "turn-live", "current provider turn id should be projected");
  assert(blocked.lifecycleState === "running", `expected running lifecycle: ${blocked.lifecycleState}`);
  assert(blocked.activeOperationCount === 1, `expected one active operation: ${blocked.activeOperationCount}`);
  assert(blocked.latestActivityAtMs === 10_006, "latest activity should follow replayed envelope timestamp");
  assert(blocked.approvalBlocked.blocked, "pending approval should block the session projection");
  assert(blocked.approvalBlocked.pendingCount === 1, "pending approval count changed");
  assert(blocked.approvalBlocked.approvalId === "approval-1", "pending approval id changed");
  assert(blocked.approvalBlocked.operationId === "op-shell", "pending approval operation id changed");

  projection.apply(envelope(7, {
    type: "approval.resolved",
    approvalId: "approval-1",
    decision: "approved",
    respondedAtMs: 10_007,
  }, {
    providerSessionId: "thread-live",
    providerTurnId: "turn-live",
  }));

  projection.apply(envelope(8, {
    type: "usage.updated",
    turnId: "turn-live",
    usage: {
      inputTokens: 11,
      cachedInputTokens: 3,
      outputTokens: 17,
      reasoningOutputTokens: 5,
      totalTokens: 28,
      contextWindowTokens: 128_000,
      model: "gpt-5",
    },
  }, {
    providerSessionId: "thread-live",
    providerTurnId: "turn-live",
  }));

  projection.apply(envelope(9, {
    type: "files.changed",
    source: "provider",
    files: [
      { path: "src/a.ts", status: "modified", additions: 3, deletions: 1 },
      { path: "src/b.ts", status: "added", additions: 10 },
    ],
  }, {
    providerSessionId: "thread-live",
    providerTurnId: "turn-live",
  }));

  projection.apply(envelope(10, {
    type: "tool.completed",
    operationId: "op-shell",
    toolKind: "command",
    name: "shell",
    status: "succeeded",
    outputSummary: "passed",
  }, {
    providerSessionId: "thread-live",
    providerTurnId: "turn-live",
  }));

  projection.apply(envelope(11, {
    type: "diagnostic",
    level: "warning",
    message: "provider checkpoint",
    code: "checkpoint.warning",
  }, {
    providerSessionId: "thread-live",
    providerTurnId: "turn-live",
  }));

  const completed = projection.apply(envelope(12, {
    type: "turn.completed",
    turnId: "turn-live",
    durationMs: 1200,
    usage: {
      inputTokens: 13,
      outputTokens: 21,
      totalTokens: 34,
    },
  }, {
    providerSessionId: "thread-live",
    providerTurnId: "turn-live",
  }));

  assert(completed.lifecycleState === "idle", `completed turn should return to idle: ${completed.lifecycleState}`);
  assert(completed.currentProviderTurnId === undefined, "completed turn should clear the current provider turn");
  assert(completed.activeOperationCount === 0, "completed turn should clear active operations");
  assert(!completed.approvalBlocked.blocked, "resolved approval should unblock projection");
  assert(completed.approvalBlocked.pendingCount === 0, "resolved approval should clear pending count");
  assert(completed.latestUsageSummary?.turnId === "turn-live", "latest usage turn id changed");
  assert(completed.latestUsageSummary?.inputTokens === 13, "completion usage should replace standalone usage");
  assert(completed.latestUsageSummary?.outputTokens === 21, "completion usage output changed");
  assert(completed.latestUsageSummary?.totalTokens === 34, "completion usage total changed");
  assert(completed.latestUsageSummary?.observedAtMs === 10_012, "usage observation timestamp changed");
  assert(completed.latestDiagnostic?.code === "checkpoint.warning", "latest diagnostic code changed");
  assert(completed.latestDiagnostic?.message === "provider checkpoint", "latest diagnostic message changed");
  assert(completed.filesChanged?.hasChanges === true, "files-changed indicator should be present");
  assert(completed.filesChanged.count === 2, `files-changed count changed: ${completed.filesChanged?.count}`);
}

{
  const failed = replayLiveSessionProjection([
    envelope(1, { type: "prompt.submitted", text: "run" }, { source: "sidecar" }),
    envelope(2, { type: "turn.started", turnId: "turn-fail" }, { providerTurnId: "turn-fail" }),
    envelope(3, {
      type: "turn.failed",
      turnId: "turn-fail",
      error: { message: "failed", code: "boom" },
    }, { providerTurnId: "turn-fail" }),
  ]);

  assert(failed.lifecycleState === "failed", `failed turn should project failed lifecycle: ${failed.lifecycleState}`);
  assert(failed.currentProviderTurnId === undefined, "failed turn should clear current provider turn");
  assert(failed.activeOperationCount === 0, "failed turn should clear active operations");
}

{
  let threw = false;
  try {
    replayLiveSessionProjection([
      envelope(1, { type: "prompt.submitted", text: "run" }, { source: "sidecar" }),
      envelope(2, { type: "prompt.submitted", text: "other" }, { sessionId: "other-session" }),
    ]);
  } catch {
    threw = true;
  }
  assert(threw, "mixed session replay should be rejected");
}

{
  const agentEvents: AgentEvent[] = [];
  const fanout = new ExecutionTelemetryFanout({
    sessionId: "session-sidecar",
    provider: "codex",
    nowMs: () => 50_000,
    idFactory: ({ sequence }) => `sidecar-event-${sequence}`,
    emitAgentEvent: (event) => {
      agentEvents.push(event);
    },
  });
  const store = new LiveSessionProjectionStore();
  store.attach((subscriber) => fanout.subscribe(subscriber));

  const initialPayload = liveSessionProjectionPayload("session-sidecar", store);
  assert(initialPayload.sessionId === "session-sidecar", "live projection payload session id changed");
  assert(initialPayload.snapshot === null, "live projection read surface should be empty before telemetry");

  fanout.publish({
    source: "sidecar",
    event: {
      type: "prompt.submitted",
      text: "sidecar read",
    },
  });
  fanout.publish({
    source: "provider",
    providerSessionId: "thread-sidecar",
    providerTurnId: "turn-sidecar",
    event: {
      type: "turn.started",
      turnId: "turn-sidecar",
    },
  });
  fanout.publish({
    source: "provider",
    providerSessionId: "thread-sidecar",
    providerTurnId: "turn-sidecar",
    event: {
      type: "usage.updated",
      turnId: "turn-sidecar",
      usage: {
        inputTokens: 20,
        outputTokens: 30,
        totalTokens: 50,
      },
    },
  });

  const payload = liveSessionProjectionPayload("session-sidecar", store);
  assert(payload.snapshot !== null, "live projection read surface should expose the latest snapshot");
  assert(payload.snapshot.sessionId === "session-sidecar", "sidecar projection session id changed");
  assert(payload.snapshot.provider === "codex", "sidecar projection provider changed");
  assert(payload.snapshot.providerSessionId === "thread-sidecar", "sidecar projection provider session id changed");
  assert(payload.snapshot.currentProviderTurnId === "turn-sidecar", "sidecar projection current turn changed");
  assert(payload.snapshot.lifecycleState === "running", "sidecar projection should track running lifecycle");
  assert(payload.snapshot.latestUsageSummary?.totalTokens === 50, "sidecar projection usage summary changed");
  assert(payload.snapshot.latestActivityAtMs === 50_000, "sidecar projection activity timestamp should use assigned envelope time");
  assert(agentEvents.length === 1 && agentEvents[0].kind === "user", "live projection subscription should not change AgentEvent projection behavior");

  payload.snapshot.latestUsageSummary!.totalTokens = 999;
  assert(store.snapshot()?.latestUsageSummary?.totalTokens === 50, "live projection snapshots should be defensive copies");
}

console.log("execution telemetry live projection assertions passed");
