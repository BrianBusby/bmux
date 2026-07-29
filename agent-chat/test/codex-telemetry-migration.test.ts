import { ExecutionTelemetryFanout } from "../executionTelemetryFanout";
import { emitCodexPromptSubmitted, emitCodexProviderSessionLinked } from "../adapters/codexTelemetry";
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
    emitTelemetry(evt) {
      return fanout.publish(evt);
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

  assert(agentEvents.length === 2, `legacy AgentEvent fallback changed: ${JSON.stringify(agentEvents)}`);
  assert(agentEvents[0].kind === "user" && agentEvents[0].text === "fallback prompt", "legacy prompt fallback changed");
  assert(
    agentEvents[1].kind === "meta" && agentEvents[1].providerSessionId === "thread-fallback",
    "legacy provider link fallback changed",
  );
}

console.log("codex telemetry migration assertions passed");

export {};
