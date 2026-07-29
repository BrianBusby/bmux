import { ExecutionTelemetryFanout } from "../executionTelemetryFanout";
import { codexHandleSendFailureForTest, codexHandleServerMessageForTest } from "../adapters/codex";
import {
  emitCodexApprovalRequested,
  emitCodexApprovalResolved,
  emitCodexDiagnostic,
  emitCodexMessageCompleted,
  emitCodexMessageDelta,
  emitCodexPromptSubmitted,
  emitCodexProviderSessionLinked,
  emitCodexToolCompleted,
  emitCodexToolStarted,
  emitCodexTurnCompleted,
  emitCodexTurnFailed,
  emitCodexTurnStarted,
  emitCodexUsageUpdated,
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

  const usageUpdates = telemetryEvents.filter((event) => event.event.type === "usage.updated");
  assert(usageUpdates.length === 2, `expected two standalone usage telemetry events: ${JSON.stringify(telemetryEvents)}`);
  assert(usageUpdates[0].event.type === "usage.updated", "first usage update should publish usage.updated telemetry");
  assert(usageUpdates[0].providerSessionId === "thread-usage", "usage update provider session id changed");
  assert(usageUpdates[0].providerTurnId === "other-turn", "usage update provider turn id changed");
  assert(usageUpdates[0].providerEvent?.method === "thread/tokenUsage/updated", "usage update provider method changed");
  assert(usageUpdates[0].event.turnId === "other-turn", "usage update turn id changed");
  assert(usageUpdates[0].event.usage.inputTokens === 50, "standalone usage input tokens changed");
  assert(usageUpdates[0].event.usage.outputTokens === 60, "standalone usage output tokens changed");
  assert(usageUpdates[0].event.usage.totalTokens === 110, "standalone usage total tokens changed");
  assert(usageUpdates[0].event.usage.contextWindowTokens === 128_000, "standalone usage context window changed");
  assert(usageUpdates[1].event.type === "usage.updated", "second usage update should publish usage.updated telemetry");
  assert(usageUpdates[1].providerTurnId === "turn-with-usage", "matching usage update provider turn id changed");
  assert(usageUpdates[1].event.usage.inputTokens === 7, "matching standalone usage input tokens changed");
  assert(!("tokenUsage" in usageUpdates[1]), "usage telemetry must not store raw provider tokenUsage");

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
  const { sess, agentEvents, telemetryEvents } = makeCodexSession();
  sess.internal.threadId = "thread-tools";

  codexHandleServerMessageForTest(sess, {
    method: "turn/started",
    params: { threadId: "thread-tools", turn: { id: "turn-tools" } },
  });
  codexHandleServerMessageForTest(sess, {
    method: "item/started",
    params: { threadId: "thread-tools", item: { id: "cmd-1", type: "commandExecution", command: "echo hello" } },
  });
  codexHandleServerMessageForTest(sess, {
    method: "item/completed",
    params: { threadId: "thread-tools", item: { id: "cmd-1", type: "commandExecution", status: "completed", exitCode: 0, aggregatedOutput: "hello\n" } },
  });
  codexHandleServerMessageForTest(sess, {
    method: "item/started",
    params: { threadId: "thread-tools", item: { id: "file-1", type: "patchApply", changes: [{ kind: "modify", path: "src/a.ts" }] } },
  });
  codexHandleServerMessageForTest(sess, {
    method: "item/completed",
    params: { threadId: "thread-tools", item: { id: "file-1", type: "patchApply", status: "failed", changes: [{ kind: "modify", path: "src/a.ts" }] } },
  });
  codexHandleServerMessageForTest(sess, {
    method: "item/started",
    params: { threadId: "thread-tools", item: { id: "web-1", type: "webSearch", query: "bmux telemetry" } },
  });
  codexHandleServerMessageForTest(sess, {
    method: "item/completed",
    params: { threadId: "thread-tools", item: { id: "web-1", type: "webSearch", status: "completed" } },
  });
  codexHandleServerMessageForTest(sess, {
    method: "item/started",
    params: { threadId: "thread-tools", item: { id: "mcp-1", type: "mcpToolCall", tool: "linear.search", arguments: { query: "abc" } } },
  });
  codexHandleServerMessageForTest(sess, {
    method: "item/completed",
    params: { threadId: "thread-tools", item: { id: "mcp-1", type: "mcpToolCall", status: "completed" } },
  });

  assert(agentEvents.length === 8, `tool lifecycle AgentEvent projection changed: ${JSON.stringify(agentEvents)}`);
  assert(agentEvents[0].kind === "tool-start" && agentEvents[0].toolId === "cmd-1" && agentEvents[0].name === "shell" && agentEvents[0].detail === "echo hello", "command start projection changed");
  assert(agentEvents[1].kind === "tool-end" && agentEvents[1].toolId === "cmd-1" && agentEvents[1].name === "shell" && agentEvents[1].ok === true && agentEvents[1].detail === "hello", "command completion projection changed");
  assert(agentEvents[2].kind === "tool-start" && agentEvents[2].name === "edit" && agentEvents[2].detail === "modify src/a.ts", "file-change start projection changed");
  assert(agentEvents[3].kind === "tool-end" && agentEvents[3].name === "edit" && agentEvents[3].ok === false && agentEvents[3].detail === "modify src/a.ts", "file-change completion projection changed");
  assert(agentEvents[4].kind === "tool-start" && agentEvents[4].name === "web_search" && agentEvents[4].detail === "bmux telemetry", "web search start projection changed");
  assert(agentEvents[5].kind === "tool-end" && agentEvents[5].toolId === "web-1" && agentEvents[5].ok === true && agentEvents[5].name === undefined && agentEvents[5].detail === undefined, "web search completion projection changed");
  assert(agentEvents[6].kind === "tool-start" && agentEvents[6].name === "linear.search" && agentEvents[6].detail === "{\"query\":\"abc\"}", "mcp start projection changed");
  assert(agentEvents[7].kind === "tool-end" && agentEvents[7].toolId === "mcp-1" && agentEvents[7].ok === true && agentEvents[7].name === undefined && agentEvents[7].detail === undefined, "mcp completion projection changed");

  const toolEvents = telemetryEvents.filter((event) => event.event.type === "tool.started" || event.event.type === "tool.completed");
  assert(toolEvents.length === 8, `expected eight tool telemetry envelopes: ${JSON.stringify(telemetryEvents)}`);

  assert(toolEvents[0].event.type === "tool.started", "command start should publish tool.started telemetry");
  assert(toolEvents[0].providerSessionId === "thread-tools", "command start provider session id was not preserved");
  assert(toolEvents[0].providerTurnId === "turn-tools", "command start provider turn id was not preserved");
  assert(toolEvents[0].providerEvent?.method === "item/started", "command start provider method changed");
  assert(toolEvents[0].providerEvent?.itemId === "cmd-1", "command start provider item id changed");
  assert(toolEvents[0].event.toolKind === "command" && toolEvents[0].event.name === "shell", "command start telemetry changed");
  assert(toolEvents[0].event.inputSummary === "echo hello", "command start input summary changed");

  assert(toolEvents[1].event.type === "tool.completed", "command completion should publish tool.completed telemetry");
  assert(toolEvents[1].providerEvent?.method === "item/completed", "command completion provider method changed");
  assert(toolEvents[1].event.status === "succeeded", "command completion status changed");
  assert(toolEvents[1].event.exitCode === 0, "command completion exit code changed");
  assert(toolEvents[1].event.outputSummary === "hello", "command output summary changed");
  assert(toolEvents[1].metadata?.providerStatus === "completed", "command provider status should stay bounded metadata");

  assert(toolEvents[3].event.type === "tool.completed", "file completion should publish tool.completed telemetry");
  assert(toolEvents[3].event.toolKind === "file-change", "file completion tool kind changed");
  assert(toolEvents[3].event.status === "failed", "file completion status changed");
  assert(toolEvents[3].metadata?.providerItemType === "patchApply", "file provider item type should stay bounded metadata");

  assert(toolEvents[4].event.type === "tool.started" && toolEvents[4].event.toolKind === "web-search", "web search start telemetry changed");
  assert(toolEvents[6].event.type === "tool.started" && toolEvents[6].event.toolKind === "mcp" && toolEvents[6].event.name === "linear.search", "mcp start telemetry changed");
  assert(!("item" in toolEvents[6]), "tool telemetry must not store raw provider items");
}

{
  const { sess, agentEvents, telemetryEvents } = makeCodexSession();
  sess.internal.threadId = "thread-approval";

  codexHandleServerMessageForTest(sess, {
    id: 101,
    method: "execCommandApproval",
    params: {
      conversationId: "thread-approval",
      callId: "cmd-call-1",
      command: ["echo", "approved"],
    },
  });

  assert(agentEvents.length === 0, `approved approval request should not project React events: ${JSON.stringify(agentEvents)}`);
  const approvalEvents = telemetryEvents.filter((event) => event.event.type === "approval.requested" || event.event.type === "approval.resolved");
  assert(approvalEvents.length === 2, `expected approved approval telemetry pair: ${JSON.stringify(telemetryEvents)}`);
  assert(approvalEvents[0].event.type === "approval.requested", "approved request should publish approval.requested telemetry");
  assert(approvalEvents[0].providerSessionId === "thread-approval", "approval request provider session id changed");
  assert(approvalEvents[0].providerEvent?.method === "execCommandApproval", "approval request provider method changed");
  assert(approvalEvents[0].providerEvent?.requestId === 101, "approval request provider request id changed");
  assert(approvalEvents[0].event.approvalId === "codex-approval-101", "approval id changed");
  assert(approvalEvents[0].event.approvalKind === "command", "approval kind changed");
  assert(approvalEvents[0].event.operationId === "cmd-call-1", "legacy command approval operation id changed");
  assert(approvalEvents[0].event.summary === "echo approved", "approval summary changed");
  assert(approvalEvents[1].event.type === "approval.resolved", "approved request should publish approval.resolved telemetry");
  assert(approvalEvents[1].event.approvalId === "codex-approval-101", "resolved approval id changed");
  assert(approvalEvents[1].event.decision === "approved", "approved decision changed");
  assert(!("params" in approvalEvents[0]), "approval telemetry must not store raw provider request params");
}

{
  const { sess, agentEvents, telemetryEvents } = makeCodexSession();
  sess.internal.threadId = "thread-patch-approval";

  codexHandleServerMessageForTest(sess, {
    id: 102,
    method: "applyPatchApproval",
    params: {
      conversationId: "thread-patch-approval",
      callId: "patch-call-1",
      fileChanges: {
        "src/secret.ts": { type: "update", unified_diff: "SECRET_DIFF" },
      },
    },
  });

  assert(agentEvents.length === 0, `approved patch approval should not project React events: ${JSON.stringify(agentEvents)}`);
  const approvalEvents = telemetryEvents.filter((event) => event.event.type === "approval.requested" || event.event.type === "approval.resolved");
  assert(approvalEvents.length === 2, `expected patch approval telemetry pair: ${JSON.stringify(telemetryEvents)}`);
  assert(approvalEvents[0].event.type === "approval.requested", "patch request should publish approval.requested telemetry");
  assert(approvalEvents[0].event.approvalKind === "file-change", "patch approval kind changed");
  assert(approvalEvents[0].event.operationId === "patch-call-1", "patch approval operation id changed");
  assert(approvalEvents[0].event.summary === "update src/secret.ts", "patch approval summary changed");
  assert(!JSON.stringify(approvalEvents).includes("SECRET_DIFF"), "patch approval telemetry must not store raw diffs");
  assert(approvalEvents[1].event.type === "approval.resolved", "patch approval should publish approval.resolved telemetry");
  assert(approvalEvents[1].event.decision === "approved", "patch approval decision changed");
}

{
  const { sess, agentEvents, telemetryEvents } = makeCodexSession();
  sess.autoApprove = false;
  sess.startOptions.approvals = "on-request";
  sess.internal.threadId = "thread-denied-approval";

  codexHandleServerMessageForTest(sess, {
    id: "deny-1",
    method: "item/fileChange/requestApproval",
    params: {
      threadId: "thread-denied-approval",
      itemId: "file-approval-1",
      grantRoot: "/tmp/project",
    },
  });

  assert(agentEvents.length === 1, `denied approval status projection changed: ${JSON.stringify(agentEvents)}`);
  assert(
    agentEvents[0].kind === "status"
      && agentEvents[0].text === "denied: item/fileChange/requestApproval (auto-approve is off)",
    "denied approval status text changed",
  );
  const approvalEvents = telemetryEvents.filter((event) => event.event.type === "approval.requested" || event.event.type === "approval.resolved");
  assert(approvalEvents.length === 2, `expected denied approval telemetry pair: ${JSON.stringify(telemetryEvents)}`);
  assert(approvalEvents[0].event.type === "approval.requested", "denied request should publish approval.requested telemetry");
  assert(approvalEvents[0].event.approvalKind === "file-change", "file approval kind changed");
  assert(approvalEvents[0].event.operationId === "file-approval-1", "file approval operation id changed");
  assert(approvalEvents[0].event.summary === "grant write access /tmp/project", "file approval summary changed");
  assert(approvalEvents[1].event.type === "approval.resolved", "denied request should publish approval.resolved telemetry");
  assert(approvalEvents[1].event.decision === "denied", "denied decision changed");
  assert(approvalEvents[1].event.reason === "auto-approve is off", "denied reason changed");

  const diagnosticEvents = telemetryEvents.filter((event) => event.event.type === "diagnostic");
  assert(diagnosticEvents.length === 1, `expected denied status diagnostic telemetry: ${JSON.stringify(telemetryEvents)}`);
  assert(diagnosticEvents[0].event.type === "diagnostic", "denied status should publish diagnostic telemetry");
  assert(diagnosticEvents[0].providerSessionId === "thread-denied-approval", "denied diagnostic provider session id changed");
  assert(diagnosticEvents[0].providerEvent?.method === "item/fileChange/requestApproval", "denied diagnostic provider method changed");
  assert(diagnosticEvents[0].providerEvent?.requestId === "deny-1", "denied diagnostic request id changed");
  assert(diagnosticEvents[0].event.level === "info", "denied diagnostic level changed");
  assert(diagnosticEvents[0].event.code === "approval.denied", "denied diagnostic code changed");
  assert(
    diagnosticEvents[0].event.message === "denied: item/fileChange/requestApproval (auto-approve is off)",
    "denied diagnostic message changed",
  );
}

{
  const { sess, agentEvents, telemetryEvents } = makeCodexSession();
  sess.internal.threadId = "thread-unsupported-approval";

  codexHandleServerMessageForTest(sess, {
    id: 202,
    method: "toolUserInput/request",
    params: { threadId: "thread-unsupported-approval" },
  });

  assert(agentEvents.length === 1, `unsupported approval status projection changed: ${JSON.stringify(agentEvents)}`);
  assert(
    agentEvents[0].kind === "status"
      && agentEvents[0].text === "declined unsupported request: toolUserInput/request",
    "unsupported approval status text changed",
  );
  const approvalEvents = telemetryEvents.filter((event) => event.event.type === "approval.requested" || event.event.type === "approval.resolved");
  assert(approvalEvents.length === 2, `expected unsupported approval telemetry pair: ${JSON.stringify(telemetryEvents)}`);
  assert(approvalEvents[0].event.type === "approval.requested", "unsupported request should publish approval.requested telemetry");
  assert(approvalEvents[0].event.approvalKind === "other", "unsupported approval kind changed");
  assert(approvalEvents[0].event.summary === "toolUserInput/request", "unsupported approval summary changed");
  assert(approvalEvents[1].event.type === "approval.resolved", "unsupported request should publish approval.resolved telemetry");
  assert(approvalEvents[1].event.decision === "unsupported", "unsupported decision changed");
  assert(approvalEvents[1].event.reason === "unsupported request", "unsupported reason changed");

  const diagnosticEvents = telemetryEvents.filter((event) => event.event.type === "diagnostic");
  assert(diagnosticEvents.length === 1, `expected unsupported status diagnostic telemetry: ${JSON.stringify(telemetryEvents)}`);
  assert(diagnosticEvents[0].event.type === "diagnostic", "unsupported status should publish diagnostic telemetry");
  assert(diagnosticEvents[0].providerSessionId === "thread-unsupported-approval", "unsupported diagnostic provider session id changed");
  assert(diagnosticEvents[0].providerEvent?.method === "toolUserInput/request", "unsupported diagnostic provider method changed");
  assert(diagnosticEvents[0].providerEvent?.requestId === 202, "unsupported diagnostic request id changed");
  assert(diagnosticEvents[0].event.level === "warning", "unsupported diagnostic level changed");
  assert(diagnosticEvents[0].event.code === "request.unsupported", "unsupported diagnostic code changed");
  assert(
    diagnosticEvents[0].event.message === "declined unsupported request: toolUserInput/request",
    "unsupported diagnostic message changed",
  );
}

{
  const { sess, agentEvents, telemetryEvents } = makeCodexSession();
  sess.internal.threadId = "thread-send-failure";

  codexHandleServerMessageForTest(sess, {
    method: "turn/started",
    params: { threadId: "thread-send-failure", turn: { id: "turn-send-failure" } },
  });
  const st = sess.internal.codex as { activeGeneration?: number; turnActive?: boolean };
  st.activeGeneration = 55;
  st.turnActive = true;

  codexHandleSendFailureForTest(sess, new Error("turn/start broke"), "turn/start");
  const failedSt = sess.internal.codex as { activeGeneration?: number; turnActive?: boolean };

  assert(agentEvents.length === 2, `send failure projection changed: ${JSON.stringify(agentEvents)}`);
  assert(
    agentEvents[0].kind === "error" && agentEvents[0].message === "Error: turn/start broke",
    "send failure error projection changed",
  );
  assert(agentEvents[1].kind === "done", "send failure should still close the UI turn");
  assert((agentEvents[1] as any).generation === 55, "send failure done generation changed");
  assert(sess.status === "idle", `send failure should return session to idle: ${sess.status}`);
  assert(failedSt.activeGeneration === undefined, "send failure should clear active generation");
  assert(failedSt.turnActive === false, "send failure should clear active turn state");

  const diagnosticEvents = telemetryEvents.filter((event) => event.event.type === "diagnostic");
  assert(diagnosticEvents.length === 1, `expected send failure diagnostic telemetry: ${JSON.stringify(telemetryEvents)}`);
  assert(diagnosticEvents[0].event.type === "diagnostic", "send failure should publish diagnostic telemetry");
  assert(diagnosticEvents[0].providerSessionId === "thread-send-failure", "send failure provider session id changed");
  assert(diagnosticEvents[0].providerTurnId === "turn-send-failure", "send failure provider turn id changed");
  assert(diagnosticEvents[0].providerEvent?.method === "turn/start", "send failure provider method changed");
  assert(diagnosticEvents[0].providerEvent?.turnId === "turn-send-failure", "send failure provider turn ref changed");
  assert(diagnosticEvents[0].event.level === "error", "send failure diagnostic level changed");
  assert(diagnosticEvents[0].event.code === "send.failed", "send failure diagnostic code changed");
  assert(diagnosticEvents[0].event.message === "Error: turn/start broke", "send failure diagnostic message changed");
  assert(!("err" in diagnosticEvents[0]), "send failure telemetry must not store raw errors");
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
  emitCodexToolStarted(sess, {
    providerSessionId: "thread-fallback",
    turnId: "turn-fallback",
    operationId: "tool-fallback",
    toolKind: "command",
    name: "shell",
    inputSummary: "echo fallback",
  });
  emitCodexToolCompleted(sess, {
    providerSessionId: "thread-fallback",
    turnId: "turn-fallback",
    operationId: "tool-fallback",
    toolKind: "command",
    name: "shell",
    status: "succeeded",
    outputSummary: "fallback output",
  });
  emitCodexApprovalRequested(sess, {
    providerSessionId: "thread-fallback",
    turnId: "turn-fallback",
    requestId: "approval-fallback",
    approvalId: "approval-fallback",
    approvalKind: "command",
    method: "execCommandApproval",
    summary: "echo fallback",
  });
  emitCodexApprovalResolved(sess, {
    providerSessionId: "thread-fallback",
    turnId: "turn-fallback",
    requestId: "approval-fallback",
    approvalId: "approval-fallback",
    method: "execCommandApproval",
    decision: "approved",
  });
  emitCodexUsageUpdated(sess, {
    providerSessionId: "thread-fallback",
    turnId: "turn-fallback",
    usage: {
      inputTokens: 9,
      outputTokens: 10,
    },
  });
  emitCodexDiagnostic(sess, {
    providerSessionId: "thread-fallback",
    turnId: "turn-fallback",
    method: "diagnostic/fallback",
    requestId: "diagnostic-fallback",
    level: "warning",
    message: "fallback diagnostic",
    code: "diagnostic.fallback",
  });

  assert(agentEvents.length === 11, `legacy AgentEvent fallback changed: ${JSON.stringify(agentEvents)}`);
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
  assert(agentEvents[8].kind === "tool-start" && agentEvents[8].toolId === "tool-fallback" && agentEvents[8].detail === "echo fallback", "legacy tool start fallback changed");
  assert(agentEvents[9].kind === "tool-end" && agentEvents[9].toolId === "tool-fallback" && agentEvents[9].ok === true && agentEvents[9].detail === "fallback output", "legacy tool completion fallback changed");
  assert(agentEvents[10].kind === "status" && agentEvents[10].text === "fallback diagnostic", "legacy diagnostic fallback changed");
}

console.log("codex telemetry migration assertions passed");

export {};
