import type { Adapter, CommandEntry, OptionChoice, OptionValue, SessionCtx, SessionOption } from "../types";
import { readLines, tryParse, truncate } from "./lines";
import { prettifyModelLabel } from "./model-label";
import {
  emitCodexApprovalRequested,
  emitCodexApprovalResolved,
  emitCodexMessageCompleted,
  emitCodexMessageDelta,
  emitCodexProviderSessionLinked,
  emitCodexToolCompleted,
  emitCodexToolStarted,
  emitCodexTurnCompleted,
  emitCodexTurnFailed,
  emitCodexTurnStarted,
} from "./codexTelemetry";
import type { TelemetryApprovalDecision, TelemetryApprovalKind, TelemetryToolKind, TelemetryToolStatus } from "../executionTelemetryTypes";

// Codex: one shared `codex app-server` process (JSON-RPC over NDJSON stdio,
// the same interface the codex IDE extension uses) hosts a thread per chat
// session. Options are thread settings and turn overrides; mid-turn sends use
// turn/steer with the active turn id.

interface AppServer {
  proc: Bun.Subprocess<"pipe", "pipe", "pipe">;
  request(method: string, params?: unknown): Promise<any>;
  write(msg: unknown): void;
  sessionsByThread: Map<string, SessionCtx>;
}

interface ModelInfo {
  value: string;
  label: string;
  description?: string;
  efforts: OptionChoice[];
  defaultEffort: string;
  serviceTiers: { id: string; name: string; description?: string }[];
  defaultServiceTier: string | null;
  isDefault?: boolean;
}

interface CodexState {
  models: ModelInfo[];
  modes: OptionChoice[];
  model: string;
  effort: string;
  approvals: string;
  sandbox: string;
  fastMode: boolean;
  mode: string;
  currentTurnId?: string;
  turnActive: boolean;
  activeGeneration?: number;
  usageByTurnId: Map<string, unknown>;
  turnWaiters: ((id: string | null) => void)[];
  commands: CommandEntry[];
}

let shared: AppServer | null = null;
let sharedStarting: Promise<AppServer> | null = null;

const FALLBACK_EFFORTS: OptionChoice[] = ["low", "medium", "high", "xhigh"].map((value) => ({ value, label: value }));
const APPROVAL_CHOICES: OptionChoice[] = [
  { value: "untrusted", label: "Untrusted" },
  { value: "on-request", label: "On request" },
  { value: "on-failure", label: "On failure" },
  { value: "never", label: "Never" },
];
const SANDBOX_CHOICES: OptionChoice[] = [
  { value: "read-only", label: "Read only" },
  { value: "workspace-write", label: "Workspace write" },
  { value: "danger-full-access", label: "Danger full access" },
];

export const codexAdapter: Adapter = {
  capabilities: {
    triggers: ["$"],
    options: [
      { id: "model", label: "Model", kind: "select", value: "", disabled: true, description: "Loads at start" },
      { id: "effort", label: "Effort", kind: "select", value: "medium", role: "effort", choices: FALLBACK_EFFORTS },
      { id: "approvals", label: "Approvals", kind: "select", value: "never", choices: APPROVAL_CHOICES },
      { id: "sandbox", label: "Sandbox", kind: "select", value: "workspace-write", choices: SANDBOX_CHOICES },
      { id: "mode", label: "Mode", kind: "select", value: "default", choices: [{ value: "default", label: "Default" }, { value: "plan", label: "Plan" }] },
    ],
  },
  async send(sess, prompt, generation?: number) {
    try {
      const srv = await ensureServer();
      const st = await ensureCodexState(sess);
      let threadId = sess.internal.threadId as string | undefined;
      if (!threadId) {
        // Single-flight: concurrent first sends must share one thread/start or
        // each spawns its own thread and the UI tracks only one of them.
        let starting = sess.internal.threadStarting as Promise<string> | undefined;
        if (!starting) {
          starting = (async () => {
            const res = await srv.request("thread/start", { cwd: sess.cwd });
            const id: string | undefined = res.thread?.id;
            if (!id) throw new Error("codex thread/start returned no thread id");
            sess.internal.threadId = id;
            srv.sessionsByThread.set(id, sess);
            emitCodexProviderSessionLinked(sess, id, "thread/start");
            emitOptions(sess);
            await refreshCommands(sess);
            return id;
          })();
          sess.internal.threadStarting = starting;
          starting.catch(() => {}).finally(() => {
            if (sess.internal.threadStarting === starting) sess.internal.threadStarting = undefined;
          });
        }
        threadId = await starting;
      }
      if (codexSendRoute(st) === "steer") {
        const turnId = st.currentTurnId ?? await waitForTurnId(st);
        if (!turnId) throw new Error("codex turn is still starting");
        await srv.request("turn/steer", {
          threadId,
          expectedTurnId: turnId,
          input: [{ type: "text", text: prompt }],
        });
        return;
      }
      sess.setStatus("running");
      st.turnActive = true;
      st.activeGeneration = generation;
      await srv.request("turn/start", {
        threadId,
        input: [{ type: "text", text: prompt }],
        model: st.model || null,
        effort: st.effort || null,
        serviceTier: st.fastMode ? fastTier(st)?.id ?? null : null,
        approvalPolicy: st.approvals,
        sandboxPolicy: sandboxPolicy(st.sandbox, sess.cwd),
        collaborationMode: collaborationMode(st),
      });
      // Completion arrives via the turn/completed notification.
    } catch (err) {
      const st = sess.internal.codex as CodexState | undefined;
      const generation = st?.activeGeneration;
      if (st) {
        st.turnActive = false;
        st.currentTurnId = undefined;
        st.activeGeneration = undefined;
        resolveTurnWaiters(st, null);
      }
      sess.emit({ kind: "error", message: truncate(String(err), 400) });
      sess.emit({ kind: "done", generation } as any);
      sess.setStatus("idle");
    }
  },
  stop(sess) {
    const threadId = sess.internal.threadId as string | undefined;
    if (threadId && shared) shared.request("turn/interrupt", { threadId }).catch(() => {});
  },
  dispose(sess) {
    const threadId = sess.internal.threadId as string | undefined;
    if (threadId && shared) shared.sessionsByThread.delete(threadId);
  },
  async setOption(sess, id, value) {
    await setCodexOption(sess, id, value);
  },
  async refreshOptions(sess) {
    await ensureCodexState(sess, true);
    emitOptions(sess);
    await refreshCommands(sess);
  },
  async listOptions() {
    const models = await listModels();
    const modes = await listModes();
    const st = defaultState(true);
    st.models = models;
    st.modes = modes;
    st.model = initialModel(models, "");
    st.effort = effortForModel(st).value;
    return buildOptions(st);
  },
  async listCommands(cwd) {
    return [{ trigger: "$", commands: await listSkills(cwd) }];
  },
  async forkSession(source, target) {
    const threadId = source.internal.threadId as string | undefined;
    if (!threadId) throw new Error("codex thread id is not available yet");
    const srv = await ensureServer();
    const res = await srv.request("thread/fork", { threadId });
    const forkThreadId = res.thread?.id ?? res.threadId;
    if (!forkThreadId) throw new Error("codex thread/fork returned no thread id");
    target.internal.threadId = forkThreadId;
    srv.sessionsByThread.set(forkThreadId, target);
    const sourceState = codexState(source);
    target.internal.codex = forkedCodexState(sourceState);
    target.internal.deltaItems = new Set<string>();
    emitCodexProviderSessionLinked(target, forkThreadId, "thread/fork");
    emitOptions(target);
  },
};

function forkedCodexState(sourceState: CodexState): CodexState {
  return {
    ...sourceState,
    turnWaiters: [],
    currentTurnId: undefined,
    turnActive: false,
    activeGeneration: undefined,
    usageByTurnId: new Map(),
    commands: sourceState.commands.slice(),
  };
}

async function ensureServer(): Promise<AppServer> {
  if (shared && shared.proc.exitCode === null && !shared.proc.killed) return shared;
  if (sharedStarting) return sharedStarting;
  sharedStarting = startServer().finally(() => {
    sharedStarting = null;
  });
  return sharedStarting;
}

async function startServer(): Promise<AppServer> {
  const proc = Bun.spawn(["codex", "app-server"], {
    stdin: "pipe",
    stdout: "pipe",
    stderr: "pipe",
    env: { ...process.env },
  });
  let nextId = 1;
  const pending = new Map<number, { resolve: (v: any) => void; reject: (e: Error) => void }>();
  const write = (msg: unknown) => {
    proc.stdin.write(JSON.stringify(msg) + "\n");
    proc.stdin.flush();
  };
  // No codex RPC is long-lived (turn completion arrives as a notification),
  // so a dropped response must not leave callers awaiting forever; claude and
  // pi requests are bounded the same way.
  const REQUEST_TIMEOUT_MS = 30_000;
  const request = (method: string, params?: unknown) =>
    new Promise<any>((resolve, reject) => {
      const id = nextId++;
      const timer = setTimeout(() => {
        pending.delete(id);
        reject(new Error(`codex ${method} timed out`));
      }, REQUEST_TIMEOUT_MS);
      pending.set(id, {
        resolve: (v) => {
          clearTimeout(timer);
          resolve(v);
        },
        reject: (e) => {
          clearTimeout(timer);
          reject(e);
        },
      });
      write({ jsonrpc: "2.0", id, method, params: params ?? {} });
    });
  const srv: AppServer = { proc, request, write, sessionsByThread: new Map() };

  readLines(proc.stdout, (line) => {
    const msg = tryParse(line);
    if (!msg) return;
    if (msg.jsonrpc !== undefined && msg.jsonrpc !== "2.0") return;
    if (msg.id != null && (msg.result !== undefined || msg.error !== undefined)) {
      const p = pending.get(msg.id);
      if (p) {
        pending.delete(msg.id);
        msg.error ? p.reject(new Error(msg.error.message ?? "codex error")) : p.resolve(msg.result);
      }
      return;
    }
    handleServerMessage(srv, msg);
  }, () => {
    for (const p of pending.values()) p.reject(new Error("codex app-server exited"));
    pending.clear();
    for (const sess of srv.sessionsByThread.values()) {
      const st = codexState(sess);
      if (st.turnActive) {
        const generation = st.activeGeneration;
        st.turnActive = false;
        st.currentTurnId = undefined;
        st.activeGeneration = undefined;
        resolveTurnWaiters(st, null);
        sess.emit({ kind: "error", message: "codex app-server exited mid-turn" });
        sess.emit({ kind: "done", generation } as any);
        sess.setStatus("idle");
      }
      sess.internal.threadId = undefined;
    }
    if (shared === srv) shared = null;
  });
  readLines(proc.stderr, () => {});

  // A hung initialize would otherwise block every codex session forever;
  // killing the process closes stdout, which rejects all pending requests.
  let initTimedOut = false;
  const initTimer = setTimeout(() => {
    initTimedOut = true;
    proc.kill();
  }, 30_000);
  try {
    await request("initialize", {
      clientInfo: { name: "bmux", title: "bmux", version: "0.1" },
      capabilities: { experimentalApi: true, requestAttestation: false },
    });
  } catch (err) {
    throw initTimedOut ? new Error("codex app-server did not initialize within 30s") : err;
  } finally {
    clearTimeout(initTimer);
  }
  shared = srv;
  return srv;
}

// The app server speaks two protocol generations: v1 approvals
// (execCommandApproval/applyPatchApproval, keyed by conversationId, answered
// with ReviewDecision "approved"/"denied") and v2 item approvals
// (item/*/requestApproval, keyed by threadId, answered with
// "accept"/"decline"). Shapes verified against
// `codex app-server generate-json-schema`. Anything else (permission
// profiles, tool user input) is declined with a JSON-RPC error so the server
// falls back instead of hanging on a malformed result.
function approvalResponse(method: string, approve: boolean): { result: unknown } | { error: unknown } {
  switch (method) {
    case "execCommandApproval":
    case "applyPatchApproval":
      return { result: { decision: approve ? "approved" : "denied" } };
    case "item/commandExecution/requestApproval":
    case "item/fileChange/requestApproval":
      return { result: { decision: approve ? "accept" : "decline" } };
    default:
      return { error: { code: -32601, message: `${method} is not supported by bmux-agent-ui` } };
  }
}

function handleServerMessage(srv: AppServer, msg: any) {
  const p = msg.params ?? {};
  const threadKey = p.threadId ?? p.conversationId;
  const sess = threadKey ? srv.sessionsByThread.get(threadKey) : undefined;

  // Server -> client request (approvals such as command execution / patches).
  if (msg.id != null && msg.method) {
    const approve = sess ? codexState(sess).approvals === "never" : false;
    const response = approvalResponse(msg.method, approve);
    if (sess) emitCodexApprovalLifecycle(sess, msg, p, response, approve);
    srv.write({ jsonrpc: "2.0", id: msg.id, ...response });
    if (sess && "result" in response && !approve) {
      sess.emit({ kind: "status", text: `denied: ${truncate(String(p.command ?? msg.method), 120)} (auto-approve is off)` });
    } else if (sess && "error" in response) {
      sess.emit({ kind: "status", text: `declined unsupported request: ${truncate(String(msg.method), 120)}` });
    }
    return;
  }
  if (!sess) return;
  const st = codexState(sess);

  switch (msg.method) {
    case "turn/started":
      st.turnActive = true;
      st.currentTurnId = p.turn?.id;
      st.usageByTurnId.clear();
      resolveTurnWaiters(st, st.currentTurnId ?? null);
      emitCodexTurnStarted(sess, {
        providerSessionId: sess.internal.threadId as string | undefined,
        turnId: st.currentTurnId,
        model: st.model,
        effort: st.effort,
      });
      break;
    case "thread/settings/updated":
      applyThreadSettings(sess, p.settings);
      break;
    case "skills/changed":
      refreshCommands(sess).catch(() => {});
      break;
    case "item/agentMessage/delta":
      if (p.delta) {
        ((sess.internal.deltaItems ??= new Set<string>()) as Set<string>).add(p.itemId);
        emitCodexMessageDelta(sess, {
          providerSessionId: sess.internal.threadId as string | undefined,
          turnId: st.currentTurnId,
          itemId: typeof p.itemId === "string" ? p.itemId : undefined,
          method: "item/agentMessage/delta",
          stream: "assistant",
          text: String(p.delta),
        });
      }
      break;
    case "item/reasoning/delta":
    case "item/reasoningSummary/delta":
    case "item/reasoning/textDelta":
    case "item/reasoning/summaryTextDelta":
      if (p.delta) {
        emitCodexMessageDelta(sess, {
          providerSessionId: sess.internal.threadId as string | undefined,
          turnId: st.currentTurnId,
          itemId: typeof p.itemId === "string" ? p.itemId : undefined,
          method: msg.method,
          stream: "reasoning",
          text: String(p.delta),
        });
      }
      break;
    case "item/started":
      itemStarted(sess, p.item);
      break;
    case "item/completed":
      itemCompleted(sess, p.item);
      break;
    case "thread/tokenUsage/updated":
      recordCodexTokenUsage(st, p.turnId, p.tokenUsage);
      break;
    case "turn/completed": {
      st.turnActive = false;
      const turnId = p.turn?.id ?? st.currentTurnId;
      st.currentTurnId = undefined;
      const generation = st.activeGeneration;
      st.activeGeneration = undefined;
      const usage = takeCodexTokenUsage(st, turnId);
      resolveTurnWaiters(st, null);
      emitCodexTurnCompleted(sess, {
        providerSessionId: sess.internal.threadId as string | undefined,
        turnId,
        durationMs: p.turn?.durationMs,
        usage,
        generation,
      });
      sess.setStatus("idle");
      break;
    }
    case "turn/failed": {
      st.turnActive = false;
      const turnId = p.turn?.id ?? st.currentTurnId;
      st.currentTurnId = undefined;
      const generation = st.activeGeneration;
      st.activeGeneration = undefined;
      st.usageByTurnId.clear();
      resolveTurnWaiters(st, null);
      emitCodexTurnFailed(sess, {
        providerSessionId: sess.internal.threadId as string | undefined,
        turnId,
        durationMs: p.turn?.durationMs,
        message: p.error?.message ?? p.turn?.error?.message,
        code: p.error?.code ?? p.turn?.error?.code,
        generation,
      });
      sess.setStatus("idle");
      break;
    }
  }
}

function emitCodexApprovalLifecycle(
  sess: SessionCtx,
  msg: { id: string | number; method: string },
  params: Record<string, unknown>,
  response: { result: unknown } | { error: unknown },
  approve: boolean,
) {
  const st = codexState(sess);
  const requestId = msg.id;
  const approvalId = `codex-approval-${requestId}`;
  const providerSessionId = typeof params.threadId === "string"
    ? params.threadId
    : (typeof params.conversationId === "string" ? params.conversationId : sess.internal.threadId as string | undefined);
  emitCodexApprovalRequested(sess, {
    providerSessionId,
    turnId: st.currentTurnId,
    requestId,
    approvalId,
    approvalKind: codexApprovalKind(msg.method),
    method: msg.method,
    operationId: codexApprovalOperationId(params),
    summary: codexApprovalSummary(msg.method, params),
  });
  emitCodexApprovalResolved(sess, {
    providerSessionId,
    turnId: st.currentTurnId,
    requestId,
    approvalId,
    method: msg.method,
    decision: codexApprovalDecision(response, approve),
    reason: codexApprovalReason(response, approve),
  });
}

function codexApprovalKind(method: string): TelemetryApprovalKind {
  switch (method) {
    case "execCommandApproval":
    case "item/commandExecution/requestApproval":
      return "command";
    case "applyPatchApproval":
    case "item/fileChange/requestApproval":
      return "file-change";
    default:
      return "other";
  }
}

function codexApprovalOperationId(params: Record<string, unknown>): string | undefined {
  if (typeof params.itemId === "string") return params.itemId;
  if (typeof params.callId === "string") return params.callId;
  if (params.item && typeof params.item === "object" && typeof (params.item as Record<string, unknown>).id === "string") {
    return (params.item as Record<string, unknown>).id as string;
  }
  return undefined;
}

function codexApprovalSummary(method: string, params: Record<string, unknown>): string {
  const commandSummary = approvalCommandSummary(params);
  if (commandSummary) return truncate(commandSummary, 400);
  const fileSummary = approvalFileSummary(params);
  if (fileSummary) return truncate(fileSummary, 400);
  if (typeof params.reason === "string" && params.reason) return truncate(params.reason, 400);
  return truncate(method, 400);
}

function approvalCommandSummary(params: Record<string, unknown>): string | undefined {
  if (typeof params.command === "string" && params.command) return params.command;
  if (Array.isArray(params.command) && params.command.length) {
    const parts = params.command.filter((part): part is string => typeof part === "string");
    if (parts.length) return parts.join(" ");
  }
  if (params.item && typeof params.item === "object") {
    const command = (params.item as Record<string, unknown>).command;
    if (typeof command === "string" && command) return command;
  }
  return undefined;
}

function approvalFileSummary(params: Record<string, unknown>): string | undefined {
  if (params.item && typeof params.item === "object") return summarizeChanges(params.item);
  const changes = params.changes;
  if (Array.isArray(changes) && changes.length) return summarizeChanges(params);
  const fileChanges = params.fileChanges;
  if (fileChanges && typeof fileChanges === "object" && !Array.isArray(fileChanges)) {
    const entries = Object.entries(fileChanges as Record<string, unknown>);
    if (entries.length) {
      return entries.map(([path, change]) => `${fileChangeApprovalType(change)} ${path}`).join(", ");
    }
  }
  if (typeof params.grantRoot === "string" && params.grantRoot) return `grant write access ${params.grantRoot}`;
  return undefined;
}

function fileChangeApprovalType(change: unknown): string {
  if (change && typeof change === "object" && typeof (change as Record<string, unknown>).type === "string") {
    return (change as Record<string, unknown>).type as string;
  }
  return "change";
}

function codexApprovalDecision(
  response: { result: unknown } | { error: unknown },
  approve: boolean,
): TelemetryApprovalDecision {
  if ("error" in response) return "unsupported";
  return approve ? "approved" : "denied";
}

function codexApprovalReason(
  response: { result: unknown } | { error: unknown },
  approve: boolean,
): string | undefined {
  if ("error" in response) return "unsupported request";
  return approve ? undefined : "auto-approve is off";
}

function itemStarted(sess: SessionCtx, item: any) {
  if (!item) return;
  const st = codexState(sess);
  const common = {
    providerSessionId: sess.internal.threadId as string | undefined,
    turnId: st.currentTurnId,
    operationId: toolOperationId(item),
    providerItemType: typeof item.type === "string" ? item.type : undefined,
  };
  switch (item.type) {
    case "commandExecution":
      emitCodexToolStarted(sess, {
        ...common,
        toolKind: "command",
        name: "shell",
        inputSummary: truncate(item.command ?? ""),
      });
      break;
    case "fileChange":
    case "patchApply":
      emitCodexToolStarted(sess, {
        ...common,
        toolKind: "file-change",
        name: "edit",
        inputSummary: truncate(summarizeChanges(item)),
      });
      break;
    case "webSearch":
      emitCodexToolStarted(sess, {
        ...common,
        toolKind: "web-search",
        name: "web_search",
        inputSummary: truncate(item.query ?? ""),
      });
      break;
    case "mcpToolCall":
      emitCodexToolStarted(sess, {
        ...common,
        toolKind: "mcp",
        name: item.tool ?? "mcp",
        inputSummary: truncate(JSON.stringify(item.arguments ?? {})),
      });
      break;
  }
}

function itemCompleted(sess: SessionCtx, item: any) {
  if (!item) return;
  const st = codexState(sess);
  const common = {
    providerSessionId: sess.internal.threadId as string | undefined,
    turnId: st.currentTurnId,
    operationId: toolOperationId(item),
    providerItemType: typeof item.type === "string" ? item.type : undefined,
    providerStatus: typeof item.status === "string" ? item.status : undefined,
  };
  switch (item.type) {
    case "agentMessage": {
      const seen = (sess.internal.deltaItems ??= new Set<string>()) as Set<string>;
      if (item.text && !seen.has(item.id)) {
        const st = codexState(sess);
        emitCodexMessageCompleted(sess, {
          providerSessionId: sess.internal.threadId as string | undefined,
          turnId: st.currentTurnId,
          itemId: typeof item.id === "string" ? item.id : undefined,
          stream: "assistant",
          text: String(item.text),
        });
      }
      seen.delete(item.id);
      break;
    }
    case "commandExecution":
      emitCodexToolCompleted(sess, {
        ...common,
        toolKind: "command",
        name: "shell",
        status: codexCommandToolStatus(item),
        outputSummary: truncate(item.aggregatedOutput ?? "", 400),
        exitCode: item.exitCode,
        durationMs: item.durationMs,
      });
      break;
    case "fileChange":
    case "patchApply":
      emitCodexToolCompleted(sess, {
        ...common,
        toolKind: "file-change",
        name: "edit",
        status: codexLegacyOkStatus(item.status !== "failed"),
        outputSummary: truncate(summarizeChanges(item)),
        durationMs: item.durationMs,
      });
      break;
    case "webSearch":
    case "mcpToolCall":
      emitCodexToolCompleted(sess, {
        ...common,
        toolKind: toolKindForItemType(item.type),
        status: codexLegacyOkStatus(item.status !== "failed"),
        durationMs: item.durationMs,
      });
      break;
  }
}

function toolOperationId(item: any): string {
  return typeof item.id === "string" ? item.id : String(item.id ?? "");
}

function toolKindForItemType(type: string): TelemetryToolKind {
  switch (type) {
    case "commandExecution":
      return "command";
    case "fileChange":
    case "patchApply":
      return "file-change";
    case "webSearch":
      return "web-search";
    case "mcpToolCall":
      return "mcp";
    default:
      return "other";
  }
}

function codexCommandToolStatus(item: any): TelemetryToolStatus {
  return codexLegacyOkStatus(item.status !== "failed" && (item.exitCode == null || item.exitCode === 0));
}

function codexLegacyOkStatus(ok: boolean): TelemetryToolStatus {
  return ok ? "succeeded" : "failed";
}

function summarizeChanges(item: any): string {
  const changes = item.changes ?? [];
  if (Array.isArray(changes) && changes.length) {
    return changes.map((c: any) => `${c.kind ?? "edit"} ${c.path ?? ""}`).join(", ");
  }
  return item.status ?? "file change";
}

function defaultState(autoApprove: boolean): CodexState {
  return {
    models: [],
    modes: [{ value: "default", label: "Default" }, { value: "plan", label: "Plan" }],
    model: "",
    effort: "medium",
    approvals: autoApprove ? "never" : "on-request",
    sandbox: autoApprove ? "workspace-write" : "read-only",
    fastMode: false,
    mode: "default",
    turnActive: false,
    activeGeneration: undefined,
    usageByTurnId: new Map(),
    turnWaiters: [],
    commands: [],
  };
}

function recordCodexTokenUsage(st: CodexState, turnId: unknown, tokenUsage: unknown) {
  if (typeof turnId !== "string") return;
  if (!tokenUsage || typeof tokenUsage !== "object") return;
  const raw = tokenUsage as Record<string, unknown>;
  const total = raw.total;
  if (!total || typeof total !== "object") return;
  st.usageByTurnId.set(turnId, {
    ...(total as Record<string, unknown>),
    modelContextWindow: raw.modelContextWindow,
  });
}

function takeCodexTokenUsage(st: CodexState, turnId: unknown): unknown {
  if (typeof turnId !== "string") {
    st.usageByTurnId.clear();
    return undefined;
  }
  const usage = st.usageByTurnId.get(turnId);
  st.usageByTurnId.clear();
  return usage;
}

export function codexForkStateForTest(sourceState: Partial<CodexState>): { turnActive: boolean; currentTurnId?: string; activeGeneration?: number } {
  const forked = forkedCodexState({
    ...defaultState(true),
    ...sourceState,
    commands: sourceState.commands ?? [],
  });
  return {
    turnActive: forked.turnActive,
    currentTurnId: forked.currentTurnId,
    activeGeneration: forked.activeGeneration,
  };
}

export function codexSendRouteForTest(st: { turnActive?: boolean; currentTurnId?: string }, _sessStatus?: string): "start" | "steer" {
  return st.turnActive ? "steer" : "start";
}

(codexAdapter as any).attributionMode = (sess: SessionCtx) => {
  const st = sess.internal.codex as { turnActive?: boolean; currentTurnId?: string } | undefined;
  return st && codexSendRouteForTest(st) === "steer" ? "current-turn" : "new-turn";
};

function codexSendRoute(st: Pick<CodexState, "turnActive" | "currentTurnId">): "start" | "steer" {
  return codexSendRouteForTest(st);
}

function waitForTurnId(st: CodexState): Promise<string | null> {
  if (st.currentTurnId) return Promise.resolve(st.currentTurnId);
  return new Promise((resolve) => {
    const timer = setTimeout(() => {
      st.turnWaiters = st.turnWaiters.filter((r) => r !== done);
      resolve(null);
    }, 5_000);
    const done = (id: string | null) => {
      clearTimeout(timer);
      resolve(id);
    };
    st.turnWaiters.push(done);
  });
}

function resolveTurnWaiters(st: CodexState, id: string | null) {
  const waiters = st.turnWaiters.splice(0);
  for (const resolve of waiters) resolve(id);
}

function codexState(sess: SessionCtx): CodexState {
  let st = sess.internal.codex as CodexState | undefined;
  if (!st) {
    st = defaultState(sess.autoApprove);
    if (typeof sess.startOptions.model === "string") st.model = sess.startOptions.model;
    if (typeof sess.startOptions.effort === "string") st.effort = sess.startOptions.effort;
    if (typeof sess.startOptions.approvals === "string") st.approvals = sess.startOptions.approvals;
    if (typeof sess.startOptions.sandbox === "string") st.sandbox = sess.startOptions.sandbox;
    if (typeof sess.startOptions.fastMode === "boolean") st.fastMode = sess.startOptions.fastMode;
    if (typeof sess.startOptions.mode === "string") st.mode = sess.startOptions.mode;
    sess.internal.codex = st;
  }
  return st;
}

async function ensureCodexState(sess: SessionCtx, force = false): Promise<CodexState> {
  const st = codexState(sess);
  if (force || !st.models.length) st.models = await listModels();
  if (force || !st.modes.length) st.modes = await listModes();
  if (!st.model) st.model = initialModel(st.models, st.model);
  const effort = effortForModel(st);
  if (!effort.choices.some((c) => c.value === st.effort)) st.effort = effort.value;
  sess.internal.deltaItems ??= new Set<string>();
  return st;
}

async function setCodexOption(sess: SessionCtx, id: string, value: OptionValue) {
  const st = await ensureCodexState(sess);
  switch (id) {
    case "model":
      if (typeof value !== "string") throw new Error("model must be a string");
      st.model = value;
      if (!effortForModel(st).choices.some((c) => c.value === st.effort)) st.effort = effortForModel(st).value;
      break;
    case "effort":
      if (typeof value !== "string") throw new Error("effort must be a string");
      st.effort = value;
      break;
    case "fastMode":
      if (typeof value !== "boolean") throw new Error("fastMode must be boolean");
      st.fastMode = value;
      break;
    case "approvals":
      if (typeof value !== "string") throw new Error("approvals must be a string");
      st.approvals = value;
      break;
    case "sandbox":
      if (typeof value !== "string") throw new Error("sandbox must be a string");
      st.sandbox = value;
      break;
    case "mode":
      if (typeof value !== "string") throw new Error("mode must be a string");
      st.mode = value;
      break;
    default:
      throw new Error(`unsupported codex option: ${id}`);
  }
  const threadId = sess.internal.threadId as string | undefined;
  if (threadId) {
    const srv = await ensureServer();
    await srv.request("thread/settings/update", {
      threadId,
      model: st.model || null,
      effort: st.effort || null,
      serviceTier: st.fastMode ? fastTier(st)?.id ?? null : null,
      approvalPolicy: st.approvals,
      sandboxPolicy: sandboxPolicy(st.sandbox, sess.cwd),
      collaborationMode: collaborationMode(st),
    });
  }
  emitOptions(sess);
}

function emitOptions(sess: SessionCtx) {
  sess.emit({ kind: "options", options: buildOptions(codexState(sess)), actions: { fork: true } });
}

function buildOptions(st: CodexState): SessionOption[] {
  const effort = effortForModel(st);
  const opts: SessionOption[] = [
    {
      id: "model",
      label: "Model",
      kind: "select",
      value: st.model,
      choices: st.models.map((m) => ({ value: m.value, label: m.label, description: m.description })),
      disabled: !st.models.length,
    },
    { id: "effort", label: "Effort", kind: "select", value: st.effort, role: "effort", choices: effort.choices },
  ];
  if (fastTier(st)) opts.push({ id: "fastMode", label: "Fast", kind: "toggle", value: st.fastMode });
  opts.push(
    { id: "approvals", label: "Approvals", kind: "select", value: st.approvals, choices: APPROVAL_CHOICES },
    { id: "sandbox", label: "Sandbox", kind: "select", value: st.sandbox, choices: SANDBOX_CHOICES },
    { id: "mode", label: "Mode", kind: "select", value: st.mode, choices: st.modes },
  );
  return opts;
}

async function listModels(): Promise<ModelInfo[]> {
  const srv = await ensureServer();
  const out: ModelInfo[] = [];
  let cursor: string | null = null;
  do {
    const res = await srv.request("model/list", { includeHidden: false, cursor });
    for (const m of res.data ?? []) out.push(normalizeModel(m));
    cursor = res.nextCursor ?? null;
  } while (cursor);
  return out;
}

function normalizeModel(m: any): ModelInfo {
  const efforts = Array.isArray(m.supportedReasoningEfforts) && m.supportedReasoningEfforts.length
    ? m.supportedReasoningEfforts.map((e: any) => ({
      value: String(e.reasoningEffort ?? e),
      label: String(e.reasoningEffort ?? e),
      description: e.description ? String(e.description) : undefined,
    })).filter((e: OptionChoice) => !isOffLike(e.value))
    : FALLBACK_EFFORTS;
  return {
    value: String(m.model ?? m.id),
    label: prettifyModelLabel(String(m.displayName ?? m.model ?? m.id)),
    description: m.description ? String(m.description) : undefined,
    efforts,
    defaultEffort: String(m.defaultReasoningEffort ?? efforts[0]?.value ?? "medium"),
    serviceTiers: (m.serviceTiers ?? []).map((t: any) => ({
      id: String(t.id),
      name: String(t.name ?? t.id),
      description: t.description ? String(t.description) : undefined,
    })),
    defaultServiceTier: m.defaultServiceTier ?? null,
    isDefault: Boolean(m.isDefault),
  };
}

async function listModes(): Promise<OptionChoice[]> {
  try {
    const srv = await ensureServer();
    const res = await srv.request("collaborationMode/list", {});
    const choices = (res.data ?? [])
      .map((m: any) => ({
        value: String(m.mode ?? m.name),
        label: String(m.name ?? m.mode ?? "mode"),
        description: m.reasoning_effort ? `effort: ${m.reasoning_effort}` : undefined,
      }))
      .filter((c: OptionChoice) => c.value === "default" || c.value === "plan");
    if (choices.length) return uniqueChoices(choices);
  } catch {
    // Older app-server builds or missing experimental capability fall back here.
  }
  return [{ value: "default", label: "Default" }, { value: "plan", label: "Plan" }];
}

function uniqueChoices(choices: OptionChoice[]): OptionChoice[] {
  const seen = new Set<string>();
  return choices.filter((c) => {
    if (seen.has(c.value)) return false;
    seen.add(c.value);
    return true;
  });
}

function isOffLike(value: string): boolean {
  return /^(none|off|no[-_ ]?reasoning)$/i.test(value);
}

function initialModel(models: ModelInfo[], requested: string): string {
  if (requested && models.some((m) => m.value === requested)) return requested;
  return models.find((m) => m.isDefault)?.value ?? models[0]?.value ?? requested;
}

function selectedModel(st: CodexState): ModelInfo | undefined {
  return st.models.find((m) => m.value === st.model) ?? st.models[0];
}

function effortForModel(st: CodexState): { value: string; choices: OptionChoice[] } {
  const m = selectedModel(st);
  const choices = m?.efforts.length ? m.efforts : FALLBACK_EFFORTS;
  const value = choices.some((c) => c.value === st.effort)
    ? st.effort
    : (m?.defaultEffort && choices.some((c) => c.value === m.defaultEffort) ? m.defaultEffort : choices[0]?.value ?? "medium");
  return { value, choices };
}

function fastTier(st: CodexState): { id: string; name: string; description?: string } | undefined {
  return selectedModel(st)?.serviceTiers.find((t) => /fast|priority/i.test(`${t.id} ${t.name} ${t.description ?? ""}`));
}

function sandboxPolicy(value: string, cwd: string): any {
  switch (value) {
    case "danger-full-access":
      return { type: "dangerFullAccess" };
    case "workspace-write":
      return { type: "workspaceWrite", writableRoots: [cwd], networkAccess: true, excludeTmpdirEnvVar: false, excludeSlashTmp: false };
    case "read-only":
    default:
      return { type: "readOnly", networkAccess: true };
  }
}

function collaborationMode(st: CodexState): any {
  const mode = st.mode === "plan" ? "plan" : "default";
  return {
    mode,
    settings: {
      model: st.model,
      reasoning_effort: st.effort || null,
      developer_instructions: null,
    },
  };
}

function applyThreadSettings(sess: SessionCtx, settings: any) {
  if (!settings) return;
  const st = codexState(sess);
  if (settings.model) st.model = String(settings.model);
  if (settings.effort) st.effort = String(settings.effort);
  if (settings.serviceTier !== undefined) st.fastMode = Boolean(settings.serviceTier && settings.serviceTier === fastTier(st)?.id);
  if (settings.approvalPolicy && typeof settings.approvalPolicy === "string") st.approvals = settings.approvalPolicy;
  if (settings.sandboxPolicy?.type) st.sandbox = sandboxValue(settings.sandboxPolicy.type);
  if (settings.collaborationMode?.mode) st.mode = String(settings.collaborationMode.mode);
  emitOptions(sess);
}

export function codexHandleServerMessageForTest(sess: SessionCtx, msg: any) {
  const p = msg.params ?? {};
  const threadKey = p.threadId ?? p.conversationId ?? sess.internal.threadId ?? "codex-test-thread";
  sess.internal.threadId ??= threadKey;
  handleServerMessage({
    proc: undefined as unknown as Bun.Subprocess<"pipe", "pipe", "pipe">,
    request: async () => {
      throw new Error("unexpected Codex request in server-message test");
    },
    write: () => {},
    sessionsByThread: new Map([[threadKey, sess]]),
  }, msg);
}

function sandboxValue(type: string): string {
  if (type === "dangerFullAccess") return "danger-full-access";
  if (type === "workspaceWrite") return "workspace-write";
  return "read-only";
}

async function refreshCommands(sess: SessionCtx) {
  const commands = await listSkills(sess.cwd);
  codexState(sess).commands = commands;
  sess.emit({ kind: "commands", trigger: "$", commands });
}

async function listSkills(cwd: string): Promise<CommandEntry[]> {
  const srv = await ensureServer();
  const res = await srv.request("skills/list", { cwds: [cwd], forceReload: false });
  return (res.data ?? []).flatMap((entry: any) =>
    (entry.skills ?? []).filter((s: any) => s.enabled !== false).map((s: any) => ({
      name: String(s.name ?? ""),
      description: String(s.shortDescription ?? s.description ?? ""),
      source: s.scope ? String(s.scope) : "skill",
    })),
  ).filter((s: CommandEntry) => s.name);
}
