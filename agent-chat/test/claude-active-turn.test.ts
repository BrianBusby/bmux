import { claudeHandleLineForTest, claudeProcessCloseForTest } from "../adapters/claude";
import { emitClaudePromptSubmitted } from "../adapters/claudeTelemetry";
import { ExecutionTelemetryFanout } from "../executionTelemetryFanout";
import type { AgentEvent, SessionCtx, SessionStatus } from "../types";
import type { TelemetryEventEnvelope } from "../executionTelemetryTypes";

function makeSession(activeTurn: boolean, withTelemetry = false): { sess: SessionCtx; events: AgentEvent[]; telemetryEvents: TelemetryEventEnvelope[] } {
  const events: AgentEvent[] = [];
  const telemetryEvents: TelemetryEventEnvelope[] = [];
  let sess!: SessionCtx;
  const fanout = new ExecutionTelemetryFanout({
    sessionId: "claude-test",
    provider: "claude",
    nowMs: () => 789_000,
    idFactory: ({ sequence }) => `claude-event-${sequence}`,
    emitAgentEvent: (event) => sess.emit(event),
  });
  fanout.subscribe((event) => telemetryEvents.push(event));
  sess = {
    id: "claude-test",
    provider: "claude",
    cwd: "/tmp",
    title: "claude test",
    autoApprove: true,
    startOptions: {},
    status: activeTurn ? "running" : "idle",
    events,
    internal: {
      claude: {
        nextRequest: 1,
        pending: new Map(),
        model: "claude-sonnet-5",
        modelChoices: [{ value: "claude-sonnet-5", label: "Claude Sonnet 5" }],
        modelMeta: new Map(),
        permissionMode: "acceptEdits",
        thinking: "0",
        effort: "medium",
        fastMode: false,
        context: "200k",
        initialApplied: true,
        commands: [],
        activeTurns: activeTurn ? 1 : 0,
        activeGenerations: activeTurn ? [1] : [],
      },
    },
    emit(evt) {
      events.push(evt);
    },
    emitTelemetry: withTelemetry ? ((event, projection) => fanout.publish(event, projection)) : undefined,
    subscribeTelemetry: withTelemetry ? ((subscriber) => fanout.subscribe(subscriber)) : undefined,
    setStatus(status: SessionStatus) {
      this.status = status;
    },
  };
  return { sess, events, telemetryEvents };
}

{
  const { sess, events, telemetryEvents } = makeSession(false, true);
  emitClaudePromptSubmitted(sess, "hello Claude");
  claudeHandleLineForTest(sess, JSON.stringify({
    type: "system",
    subtype: "init",
    session_id: "claude-provider-session",
    model: "claude-sonnet-5",
    slash_commands: [],
  }));
  if (events.length !== 2) throw new Error(`Claude prompt/init projection changed: ${JSON.stringify(events)}`);
  if (events[0].kind !== "user" || events[0].text !== "hello Claude") throw new Error("Claude prompt should still project to user");
  if (events[1].kind !== "meta" || events[1].model !== "claude-sonnet-5" || events[1].providerSessionId !== "claude-provider-session") {
    throw new Error(`Claude init should still project one meta event, got ${JSON.stringify(events)}`);
  }
  if (telemetryEvents[0].event.type !== "prompt.submitted" || telemetryEvents[0].source !== "sidecar") {
    throw new Error(`Claude prompt telemetry changed: ${JSON.stringify(telemetryEvents)}`);
  }
  if (telemetryEvents[1].event.type !== "session.provider-linked" || telemetryEvents[1].providerEvent?.method !== "system/init") {
    throw new Error(`Claude init telemetry changed: ${JSON.stringify(telemetryEvents)}`);
  }
}

{
  const { sess, events, telemetryEvents } = makeSession(true, true);
  sess.internal.providerSessionId = "claude-provider-session";
  claudeHandleLineForTest(sess, JSON.stringify({ type: "result", subtype: "success", duration_ms: 1200, total_cost_usd: 0.012, num_turns: 1 }));
  claudeProcessCloseForTest(sess);
  const done = events.filter((evt) => evt.kind === "done");
  const errors = events.filter((evt) => evt.kind === "error");
  if (done.length !== 1) throw new Error(`normal result should emit exactly one done, got ${JSON.stringify(events)}`);
  if (done[0].stats !== "$0.012 · 1.2s · 1 turn") throw new Error(`normal result stats changed, got ${JSON.stringify(done)}`);
  if (errors.length) throw new Error(`normal close after result should not emit an error, got ${JSON.stringify(events)}`);
  if (sess.status !== "idle") throw new Error(`normal close should leave session idle, got ${sess.status}`);
  if ((sess.internal.claude as any).activeTurns) throw new Error("normal result should clear claude active turn");
  if (telemetryEvents.length !== 1 || telemetryEvents[0].event.type !== "turn.completed") {
    throw new Error(`normal result should publish turn.completed telemetry, got ${JSON.stringify(telemetryEvents)}`);
  }
  if (telemetryEvents[0].providerSessionId !== "claude-provider-session" || telemetryEvents[0].providerEvent?.method !== "result") {
    throw new Error(`normal result telemetry identity changed, got ${JSON.stringify(telemetryEvents)}`);
  }
}

{
  const { sess, events, telemetryEvents } = makeSession(true, true);
  sess.internal.providerSessionId = "claude-provider-session";
  claudeHandleLineForTest(sess, JSON.stringify({
    type: "result",
    subtype: "error_max_turns",
    is_error: true,
    result: "maximum turns reached",
    duration_ms: 2500,
    total_cost_usd: 0.034,
    num_turns: 2,
  }));
  if (events.length !== 2 || events[0].kind !== "error" || events[1].kind !== "done") {
    throw new Error(`error result projection changed, got ${JSON.stringify(events)}`);
  }
  if (events[0].message !== "maximum turns reached" || events[1].stats !== "$0.034 · 2.5s · 2 turns") {
    throw new Error(`error result fields changed, got ${JSON.stringify(events)}`);
  }
  if (telemetryEvents.length !== 1 || telemetryEvents[0].event.type !== "turn.failed") {
    throw new Error(`error result should publish turn.failed telemetry, got ${JSON.stringify(telemetryEvents)}`);
  }
  if (telemetryEvents[0].providerEvent?.method !== "result" || telemetryEvents[0].event.error.code !== "claude.result_error") {
    throw new Error(`error result telemetry identity changed, got ${JSON.stringify(telemetryEvents)}`);
  }
}

{
  const { sess, events, telemetryEvents } = makeSession(true, true);
  sess.internal.providerSessionId = "claude-provider-session";
  claudeProcessCloseForTest(sess);
  const done = events.filter((evt) => evt.kind === "done");
  const errors = events.filter((evt) => evt.kind === "error");
  if (done.length !== 1) throw new Error(`mid-turn exit should emit exactly one done, got ${JSON.stringify(events)}`);
  if (!errors.some((evt) => /claude process exited mid-turn/.test(evt.message))) {
    throw new Error(`mid-turn exit should report the crash, got ${JSON.stringify(events)}`);
  }
  claudeProcessCloseForTest(sess);
  if (events.filter((evt) => evt.kind === "done").length !== 1) {
    throw new Error(`repeated close should not duplicate done, got ${JSON.stringify(events)}`);
  }
  if (sess.status !== "idle") throw new Error(`mid-turn exit should leave session idle, got ${sess.status}`);
  if (telemetryEvents.length !== 1 || telemetryEvents[0].event.type !== "turn.failed" || telemetryEvents[0].source !== "sidecar") {
    throw new Error(`mid-turn exit should publish sidecar turn.failed telemetry, got ${JSON.stringify(telemetryEvents)}`);
  }
  if (telemetryEvents[0].providerEvent?.method !== "process/exit" || telemetryEvents[0].event.error.code !== "claude.process_exited") {
    throw new Error(`mid-turn exit telemetry identity changed, got ${JSON.stringify(telemetryEvents)}`);
  }
}

{
  const { sess, events } = makeSession(true);
  const st = sess.internal.claude as any;
  st.activeTurns = 3;
  st.activeGenerations = [10, 11, 12];
  claudeProcessCloseForTest(sess);
  const done = events.filter((evt) => evt.kind === "done");
  const errors = events.filter((evt) => evt.kind === "error");
  const generations = done.map((evt) => (evt as any).generation).join("|");
  if (done.length !== 3) throw new Error(`queued close should emit one done per generation, got ${JSON.stringify(events)}`);
  if (errors.length !== 3) throw new Error(`queued close should emit one error per unfinished generation, got ${JSON.stringify(events)}`);
  if (generations !== "10|11|12") throw new Error(`queued close should preserve generation order, got ${generations}`);
  if (st.activeTurns || st.activeGenerations.length) throw new Error("queued close should clear all claude active turns");
}

console.log("claude active-turn assertions passed");

export {};
