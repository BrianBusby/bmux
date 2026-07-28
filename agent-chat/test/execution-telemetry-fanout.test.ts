import { ExecutionTelemetryFanout } from "../executionTelemetryFanout";
import type { AgentEvent } from "../types";
import type { TelemetryEventEnvelope } from "../executionTelemetryTypes";

function assert(cond: unknown, message: string): asserts cond {
  if (!cond) throw new Error(message);
}

const agentEvents: AgentEvent[] = [];
const telemetryEvents: TelemetryEventEnvelope[] = [];
const fanout = new ExecutionTelemetryFanout({
  sessionId: "session-a",
  provider: "codex",
  nowMs: () => 123_456,
  idFactory: ({ sequence }) => `event-${sequence}`,
  emitAgentEvent: (event) => {
    agentEvents.push(event);
  },
});

fanout.subscribe((event) => {
  telemetryEvents.push(event);
});

const first = fanout.publish({
  schema: "bmux.execution-event.v1",
  eventId: "provider-must-not-win",
  sessionId: "wrong-session",
  sequence: 99,
  capturedAtMs: 1,
  provider: "wrong-provider",
  source: "provider",
  providerSessionId: "thread-1",
  event: {
    type: "prompt.submitted",
    text: "hello",
  },
});

const second = fanout.publish({
  source: "provider",
  event: {
    type: "message.delta",
    stream: "assistant",
    itemId: "item-1",
    text: "world",
  },
});

const third = fanout.publish({
  source: "git-observer",
  event: {
    type: "files.changed",
    source: "git-observer",
    files: [
      { path: "src/a.ts", status: "modified", additions: 2 },
    ],
  },
});

assert(first.eventId === "event-1", `sidecar did not assign the first event id: ${first.eventId}`);
assert(first.sessionId === "session-a", `sidecar did not assign the session id: ${first.sessionId}`);
assert(first.sequence === 1, `sidecar did not assign sequence 1: ${first.sequence}`);
assert(first.capturedAtMs === 123_456, `sidecar did not assign capturedAtMs: ${first.capturedAtMs}`);
assert(first.provider === "codex", `sidecar did not assign provider: ${first.provider}`);
assert(first.providerSessionId === "thread-1", "bounded provider reference should be preserved");
assert(second.eventId === "event-2" && second.sequence === 2, "second event should advance id and sequence");
assert(third.eventId === "event-3" && third.sequence === 3, "third event should advance id and sequence");

assert(
  telemetryEvents.map((event) => event.eventId).join("|") === "event-1|event-2|event-3",
  "telemetry subscribers did not receive assigned envelopes",
);
assert(agentEvents.length === 3, `unexpected AgentEvent count: ${JSON.stringify(agentEvents)}`);
assert(agentEvents[0].kind === "user" && agentEvents[0].text === "hello", "prompt should project to the existing user event");
assert(agentEvents[1].kind === "delta" && agentEvents[1].text === "world", "assistant delta should project to the existing delta event");
assert(
  agentEvents[2].kind === "files-changed" && agentEvents[2].files[0].adds === 2 && agentEvents[2].files[0].dels === 0,
  "files.changed should project to the existing files-changed event",
);

console.log("execution telemetry fanout assertions passed");
