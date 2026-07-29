import { ExecutionTelemetryFanout } from "../executionTelemetryFanout";
import { codexHandleServerMessageForTest } from "../adapters/codex";
import {
  emitCodexMessageCompleted,
  emitCodexMessageDelta,
  emitCodexPromptSubmitted,
  emitCodexProviderSessionLinked,
  emitCodexTurnCompleted,
  emitCodexTurnFailed,
  emitCodexTurnStarted,
} from "../adapters/codexTelemetry";
import type { AgentEvent, SessionCtx, SessionStatus } from "../types";
import type { TelemetryEventEnvelope } from "../executionTelemetryTypes";

function assert(cond: unknown, message: string): asserts cond {
  if (!cond) throw new Error(message);
}

function makeCodexSession(): { sess: SessionCtx; agentEvents: AgentEvent[]; telemetryEvents: TelemetryEventEnvelope[] } {
  const agentEvents: AgentEvent[] = [];
  const telemetryEvents: TelemetryEventEnvelope[] = [];
  let sess!: SessionCtx;
  const fanout = new ExecutionTelemetryFanout({
    sessionId: "codex-session",
    provider: "codex",
    nowMs: () => 456_000,
    idFactory: ({ sequence }) => `codex-event-${sequence}`,
    emitAgentEvent: (event) => sess.emit(event),
  });
  fanout.subscribe((event) => {
    telemetryEvents.push(event);
  });
  sess = {
    id: "codex-session",
    provider: "codex",
    cwd: "/tmp",
    title: "codex test",
    autoApprove: true,
    startOptions: {},
    status: "idle",
    events: agentEvents,
    internal: {},
    emit(evt) {
      agentEvents.push(evt);
    },
    emitTelemetry(evt, projection) {
      return fanout.publish(evt, projection);
    },
    subscribeTelemetry(subscriber) {
      return fanout.subscribe(subscriber);
    },
    setStatus(status: SessionStatus) {
      this.status = status;
    },
  };
  return { sess, agentEvents, telemetryEvents };
}

function codexTokenUsage(inputTokens: number, outputTokens: number, totalTokens: number, modelContextWindow: number) {
  return {
    last: {
      cachedInputTokens: 0,
      inputTokens,
      outputTokens,
      reasoningOutputTokens: 0,
      totalTokens,
    },
    modelContextWindow,
    total: {
      cachedInputTokens: 0,
      inputTokens,
      outputTokens,
      reasoningOutputTokens: 0,
      totalTokens,
    },
  };
}

{
  const { sess, agentEvents, telemetryEvents } = makeCodexSession();

  emitCodexPromptSubmitted(sess, "hello Codex");
  emitCodexProviderSessionLinked(sess, "thread-123", "thread/start");

  assert(agentEvents.length === 2, `React AgentEvent projection changed: ${JSON.stringify(agentEvents)}`);
  assert(agentEvents[0].kind === "user" && agentEvents[0].text === "hello Codex", "prompt should still project to user event");
  assert(
    agentEvents[1].kind === "meta" && agentEvents[1].providerSessionId === "thread-123",
    "provider link should still project to meta event",
  );

  assert(telemetryEvents.length === 2, `expected two telemetry envelopes: ${JSON.stringify(telemetryEvents)}`);
  assert(telemetryEvents[0].eventId === "codex-event-1" && telemetryEvents[0].sequence === 1, "prompt telemetry ordering changed");
  assert(telemetryEvents[0].source === "sidecar", `prompt source should be sidecar: ${telemetryEvents[0].source}`);
  assert(telemetryEvents[0].event.type === "prompt.submitted", "prompt should publish prompt.submitted telemetry");
  assert(telemetryEvents[0].event.text === "hello Codex", "prompt telemetry text changed");

  assert(telemetryEvents[1].eventId === "codex-event-2" && telemetryEvents[1].sequence === 2, "link telemetry ordering changed");
  assert(telemetryEvents[1].source === "provider", `provider link source should be provider: ${telemetryEvents[1].source}`);
  assert(telemetryEvents[1].providerSessionId === "thread-123", "provider session id was not preserved on envelope");
  assert(telemetryEvents[1].providerEvent?.method === "thread/start", "provider method was not preserved");
  assert(telemetryEvents[1].event.type === "session.provider-linked", "provider link should publish session.provider-linked telemetry");
  assert(telemetryEvents[1].event.providerSessionId === "thread-123", "provider link telemetry id changed");
}

{
  const { sess, agentEvents, telemetryEvents } = makeCodexSession();

  emitCodexTurnStarted(sess, {
    providerSessionId: "thread-123",
    turnId: "turn-1",
    model: "gpt-5",
    effort: "high",
  });
  emitCodexTurnCompleted(sess, {
    providerSessionId: "thread-123",
    turnId: "turn-1",
    durationMs: 1250,
    usage: {
      inputTokens: 3,
      outputTokens: 5,
      totalTokens: 8,
      ignoredNestedPayload: { raw: true },
    },
    generation: 7,
  });
  emitCodexTurnFailed(sess, {
    providerSessionId: "thread-123",
    turnId: "turn-2",
    durationMs: 2000,
    message: "turn exploded",
    code: "boom",
    generation: 8,
  });

  assert(agentEvents.length === 3, `turn lifecycle AgentEvent projection changed: ${JSON.stringify(agentEvents)}`);
  assert(agentEvents[0].kind === "done" && agentEvents[0].stats === "3 in · 5 out · 1.3s", "turn completion done stats changed");
  assert((agentEvents[0] as any).generation === 7, "turn completion generation should stay available to server projection");
  assert(agentEvents[1].kind === "error" && agentEvents[1].message === "turn exploded", "turn failure error projection changed");
  assert(agentEvents[2].kind === "done", "turn failure should still close the UI turn");
  assert((agentEvents[2] as any).generation === 8, "turn failure generation should stay available to server projection");

  assert(telemetryEvents.length === 3, `expected three turn telemetry envelopes: ${JSON.stringify(telemetryEvents)}`);
  assert(telemetryEvents[0].event.type === "turn.started", "turn start should publish turn.started telemetry");
  assert(telemetryEvents[0].providerSessionId === "thread-123", "turn start provider session id was not preserved");
  assert(telemetryEvents[0].providerTurnId === "turn-1", "turn start provider turn id was not preserved");
  assert(telemetryEvents[0].providerEvent?.method === "turn/started", "turn start provider method was not preserved");
  assert(telemetryEvents[0].event.model === "gpt-5" && telemetryEvents[0].event.effort === "high", "turn settings changed");

  assert(telemetryEvents[1].event.type === "turn.completed", "turn completion should publish turn.completed telemetry");
  assert(telemetryEvents[1].providerEvent?.method === "turn/completed", "turn completion provider method was not preserved");
  assert(telemetryEvents[1].event.durationMs === 1250, "turn completion duration changed");
  assert(telemetryEvents[1].event.usage?.inputTokens === 3, "turn completion input tokens changed");
  assert(telemetryEvents[1].event.usage?.outputTokens === 5, "turn completion output tokens changed");
  assert(telemetryEvents[1].event.usage?.totalTokens === 8, "turn completion total tokens changed");
  assert(!("ignoredNestedPayload" in (telemetryEvents[1].event.usage as any)), "turn completion usage should stay bounded");
  assert(!("generation" in telemetryEvents[1]), "server projection generation must not be stored on telemetry envelope");

  assert(telemetryEvents[2].event.type === "turn.failed", "turn failure should publish turn.failed telemetry");
  assert(telemetryEvents[2].providerEvent?.method === "turn/failed", "turn failure provider method was not preserved");
  assert(telemetryEvents[2].event.durationMs === 2000, "turn failure duration changed");
  assert(telemetryEvents[2].event.error.message === "turn exploded", "turn failure message changed");
  assert(telemetryEvents[2].event.error.code === "boom", "turn failure code changed");
  assert(!("generation" in telemetryEvents[2]), "server projection generation must not be stored on failed telemetry envelope");
}

{
  const { sess, agentEvents, telemetryEvents } = makeCodexSession();
  sess.internal.threadId = "thread-usage";

  codexHandleServerMessageForTest(sess, {
    method: "turn/started",
    params: { threadId: "thread-usage", turn: { id: "turn-without-usage" } },
  });
  codexHandleServerMessageForTest(sess, {
    method: "thread/tokenUsage/updated",
    params: {
      threadId: "thread-usage",
      turnId: "other-turn",
      tokenUsage: codexTokenUsage(50, 60, 110, 128_000),
    },
  });
  codexHandleServerMessageForTest(sess, {
    method: "turn/completed",
    params: { threadId: "thread-usage", turn: { id: "turn-without-usage", durationMs: 1000 } },
  });

  codexHandleServerMessageForTest(sess, {
    method: "turn/started",
    params: { threadId: "thread-usage", turn: { id: "turn-with-usage" } },
  });
  codexHandleServerMessageForTest(sess, {
    method: "thread/tokenUsage/updated",
    params: {
      threadId: "thread-usage",
      turnId: "turn-with-usage",
      tokenUsage: codexTokenUsage(7, 11, 18, 256_000),
    },
  });
  codexHandleServerMessageForTest(sess, {
    method: "turn/completed",
    params: { threadId: "thread-usage", turn: { id: "turn-with-usage", durationMs: 2000 } },
  });

  const completed = telemetryEvents.filter((event) => event.event.type === "turn.completed");
  assert(completed.length === 2, `expected two completed turn telemetry events: ${JSON.stringify(telemetryEvents)}`);
  assert(completed[0].event.type === "turn.completed" && completed[0].event.usage === undefined, "mismatched turn usage should not attach");
  assert(completed[1].event.type === "turn.completed", "second completion should be turn.completed");
  assert(completed[1].providerTurnId === "turn-with-usage", "matching usage completion should preserve provider turn id");
  assert(completed[1].event.usage?.inputTokens === 7, "matching usage input tokens changed");
  assert(completed[1].event.usage?.outputTokens === 11, "matching usage output tokens changed");
  assert(completed[1].event.usage?.totalTokens === 18, "matching usage total tokens changed");
  assert(completed[1].event.usage?.contextWindowTokens === 256_000, "modelContextWindow should map to contextWindowTokens");

  const doneEvents = agentEvents.filter((event) => event.kind === "done");
  assert(doneEvents.length === 2, `expected two projected done events: ${JSON.stringify(agentEvents)}`);
  assert(doneEvents[0].stats === "1.0s", "completion without matching usage should only project duration stats");
  assert(doneEvents[1].stats === "7 in · 11 out · 2.0s", "completion with matching usage should project matching usage stats");
}

{
  const { sess, agentEvents, telemetryEvents } = makeCodexSession();
  sess.internal.threadId = "thread-message";

  codexHandleServerMessageForTest(sess, {
    method: "turn/started",
    params: { threadId: "thread-message", turn: { id: "turn-message" } },
  });
  codexHandleServerMessageForTest(sess, {
    method: "item/agentMessage/delta",
    params: { threadId: "thread-message", itemId: "msg-streamed", delta: "hello " },
  });
  codexHandleServerMessageForTest(sess, {
    method: "item/reasoning/summaryTextDelta",
    params: { threadId: "thread-message", itemId: "reasoning-1", delta: "thinking" },
  });
  codexHandleServerMessageForTest(sess, {
    method: "item/completed",
    params: { threadId: "thread-message", item: { id: "msg-streamed", type: "agentMessage", text: "hello world" } },
  });
  codexHandleServerMessageForTest(sess, {
    method: "item/completed",
    params: { threadId: "thread-message", item: { id: "msg-completed", type: "agentMessage", text: "full answer" } },
  });

  assert(agentEvents.length === 3, `message lifecycle AgentEvent projection changed: ${JSON.stringify(agentEvents)}`);
  assert(agentEvents[0].kind === "delta" && agentEvents[0].text === "hello ", "assistant delta projection changed");
  assert(agentEvents[1].kind === "thinking" && agentEvents[1].text === "thinking", "reasoning delta projection changed");
  assert(agentEvents[2].kind === "assistant" && agentEvents[2].text === "full answer", "completed assistant projection changed");

  const messageEvents = telemetryEvents.filter((event) => event.event.type === "message.delta" || event.event.type === "message.completed");
  assert(messageEvents.length === 3, `expected three message telemetry envelopes: ${JSON.stringify(telemetryEvents)}`);

  assert(messageEvents[0].event.type === "message.delta", "assistant delta should publish message.delta telemetry");
  assert(messageEvents[0].providerTurnId === "turn-message", "assistant delta provider turn id was not preserved");
  assert(messageEvents[0].providerEvent?.method === "item/agentMessage/delta", "assistant delta provider method changed");
  assert(messageEvents[0].providerEvent?.itemId === "msg-streamed", "assistant delta provider item id changed");
  assert(messageEvents[0].event.stream === "assistant" && messageEvents[0].event.text === "hello ", "assistant delta telemetry changed");

  assert(messageEvents[1].event.type === "message.delta", "reasoning delta should publish message.delta telemetry");
  assert(messageEvents[1].providerEvent?.method === "item/reasoning/summaryTextDelta", "reasoning delta provider method changed");
  assert(messageEvents[1].event.stream === "reasoning" && messageEvents[1].event.text === "thinking", "reasoning delta telemetry changed");

  assert(messageEvents[2].event.type === "message.completed", "completed assistant should publish message.completed telemetry");
  assert(messageEvents[2].providerEvent?.method === "item/completed", "completed assistant provider method changed");
  assert(messageEvents[2].event.itemId === "msg-completed", "completed assistant item id changed");
  assert(messageEvents[2].event.text === "full answer", "completed assistant text changed");
}

{
  const agentEvents: AgentEvent[] = [];
  const sess: SessionCtx = {
    id: "legacy-codex-session",
    provider: "codex",
    cwd: "/tmp",
    title: "legacy codex test",
    autoApprove: true,
    startOptions: {},
    status: "idle",
    events: agentEvents,
    internal: {},
    emit(evt) {
      agentEvents.push(evt);
    },
    setStatus(status: SessionStatus) {
      this.status = status;
    },
  };

  emitCodexPromptSubmitted(sess, "fallback prompt");
  emitCodexProviderSessionLinked(sess, "thread-fallback", "thread/fork");
  emitCodexTurnStarted(sess, { providerSessionId: "thread-fallback", turnId: "turn-fallback" });
  emitCodexTurnCompleted(sess, {
    providerSessionId: "thread-fallback",
    turnId: "turn-fallback",
    durationMs: 500,
    usage: { inputTokens: 1, outputTokens: 2 },
    generation: 3,
  });
  emitCodexTurnFailed(sess, {
    providerSessionId: "thread-fallback",
    turnId: "turn-failed",
    message: "fallback failed",
    generation: 4,
  });
  emitCodexMessageDelta(sess, {
    providerSessionId: "thread-fallback",
    turnId: "turn-fallback",
    itemId: "msg-fallback",
    method: "item/agentMessage/delta",
    stream: "assistant",
    text: "fallback delta",
  });
  emitCodexMessageDelta(sess, {
    providerSessionId: "thread-fallback",
    turnId: "turn-fallback",
    itemId: "reasoning-fallback",
    method: "item/reasoning/delta",
    stream: "reasoning",
    text: "fallback thinking",
  });
  emitCodexMessageCompleted(sess, {
    providerSessionId: "thread-fallback",
    turnId: "turn-fallback",
    itemId: "msg-completed-fallback",
    stream: "assistant",
    text: "fallback assistant",
  });

  assert(agentEvents.length === 8, `legacy AgentEvent fallback changed: ${JSON.stringify(agentEvents)}`);
  assert(agentEvents[0].kind === "user" && agentEvents[0].text === "fallback prompt", "legacy prompt fallback changed");
  assert(
    agentEvents[1].kind === "meta" && agentEvents[1].providerSessionId === "thread-fallback",
    "legacy provider link fallback changed",
  );
  assert(agentEvents[2].kind === "done" && agentEvents[2].stats === "1 in · 2 out · 0.5s", "legacy turn completion fallback changed");
  assert((agentEvents[2] as any).generation === 3, "legacy turn completion generation changed");
  assert(agentEvents[3].kind === "error" && agentEvents[3].message === "fallback failed", "legacy turn failure fallback changed");
  assert(agentEvents[4].kind === "done", "legacy turn failure fallback should close the UI turn");
  assert((agentEvents[4] as any).generation === 4, "legacy turn failure generation changed");
  assert(agentEvents[5].kind === "delta" && agentEvents[5].text === "fallback delta", "legacy assistant delta fallback changed");
  assert(agentEvents[6].kind === "thinking" && agentEvents[6].text === "fallback thinking", "legacy reasoning delta fallback changed");
  assert(agentEvents[7].kind === "assistant" && agentEvents[7].text === "fallback assistant", "legacy assistant completed fallback changed");
}

console.log("codex telemetry migration assertions passed");

export {};
