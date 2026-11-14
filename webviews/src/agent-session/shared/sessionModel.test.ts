import { act, createElement } from "react";
import { createRoot } from "react-dom/client";
import { JSDOM } from "jsdom";
import { renderToStaticMarkup } from "react-dom/server";
import { RelatedAwarenessNotice, SemanticReportsNotice, SmartSessionFreshnessBanner, SmartSessionSurface } from "../react/SmartSessionSurface";
import { expect, test } from "bun:test";
import { makeClientId } from "./ids";
import {
  autoStartProvider,
  canSelectProvider,
  canStopProvider,
  formatTemplate,
  initialState,
  messageForError,
  reduceSession,
  sendInput,
  shouldAutoStartProvider,
  statusLabel,
  type Action,
} from "./sessionModel";
import {
  initialSmartSessionState,
  reduceSmartSession,
  semanticFieldForKind,
  semanticMessageForKind,
  shouldRefreshSmartSession,
  SMART_SESSION_SEMANTIC_KINDS,
} from "./smartSessionModel";
import type { AppContext, ProviderInfo, SmartSessionSnapshot } from "./types";

const theme = {
  isDark: true,
  pageBackground: "transparent",
  surfaceBackground: "rgba(0, 0, 0, 0.3)",
  surfaceElevatedBackground: "rgba(0, 0, 0, 0.4)",
  inputBackground: "rgba(0, 0, 0, 0.2)",
  border: "rgba(255, 255, 255, 0.1)",
  borderStrong: "rgba(255, 255, 255, 0.2)",
  text: "rgba(255, 255, 255, 1)",
  mutedText: "rgba(255, 255, 255, 0.6)",
  softText: "rgba(255, 255, 255, 0.8)",
  accent: "rgba(138, 180, 248, 1)",
  accentSoft: "rgba(138, 180, 248, 0.2)",
  danger: "rgba(255, 141, 126, 1)",
  shadow: "rgba(0, 0, 0, 0.2)",
};

const context: AppContext = {
  panelId: "panel-1",
  workspaceId: "workspace-1",
  renderer: "react",
  initialProviderId: "codex",
  copy: {
    start: "Start",
    stop: "Stop",
    send: "Send",
    provider: "Provider",
    rateLimits: "Rate limits",
    rateLimitUsageRemaining: "Usage remaining",
    rateLimitPrimary: "Primary",
    rateLimitSecondary: "Secondary",
    rateLimitWeekly: "Weekly",
    rateLimitMonthly: "Monthly",
    rateLimitDaysFormat: "%@d",
    rateLimitHoursFormat: "%@h",
    rateLimitMinutesFormat: "%@m",
    rateLimitResets: "resets",
    voiceInput: "Voice input",
    promptPlaceholder: "Ask anything",
    attachFile: "Attach file",
    addFilesAndMore: "Add files and more",
    addPhotosAndFiles: "Add photos & files",
    removeAttachment: "Remove attachment",
    copyOutput: "Copy output",
    copyAssistantMessage: "Copy",
    copiedAssistantMessage: "Copied",
    copyUserMessage: "Copy message",
    copiedUserMessage: "Copied",
    shellLabel: "Shell",
    copyShellContents: "Copy shell contents",
    copiedShellContents: "Copied shell contents",
    collapseShell: "Collapse shell",
    showRawOutput: "Show raw output",
    showOptimizedOutput: "Show optimized output",
    rawOutputUnavailable: "Raw output unavailable",
    shellSuccess: "Success",
    showMore: "Show more",
    showLess: "Show less",
    browseWeb: "Browse web",
    autoContext: "Context",
    includeIdeContext: "Include IDE context",
    ideContext: "IDE context",
    tools: "Tools",
    changePermissions: "Change permissions",
    permissionsDefault: "Default permissions",
    permissionsFullAccess: "Full access",
    permissionsAutoReview: "Auto-review",
    permissionsCustom: "Custom (config.toml)",
    reasoningEffortHigh: "High",
    mentionMenuTitle: "Mention",
    mentionCurrentWorkspace: "Current workspace",
    skillMenuTitle: "Skills",
    composerNoResults: "No results",
    planMode: "Plan mode",
    planSuggestionAction: "Use plan mode",
    planSuggestionDismiss: "Dismiss suggestion",
    planSuggestionShortcut: "Shift + Tab",
    planSuggestionTitle: "Create a plan",
    skillPlan: "Plan",
    skillCodeReview: "Code review",
    skillResearch: "Research",
    loadingStatus: "Loading",
    idleStatus: "Idle",
    startingStatus: "Starting",
    runningStatus: "Running",
    stoppingStatus: "Stopping",
    failedStatus: "Failed",
    rendererReadyFormat: "%@ ready",
    stopped: "Stopped",
    sentCharsFormat: "Sent %d chars",
    providerStarted: "Provider started",
    providerExitedFormat: "Provider exited %d",
    requestFailed: "Native bridge request failed.",
    terminalView: "Terminal",
    sessionView: "Session",
    smartSessionRefresh: "Refresh",
    smartSessionLoading: "Loading session",
    smartSessionNoSession: "No linked session",
    smartSessionUnavailable: "Session data unavailable",
    smartSessionNoSupportedAgent: "No supported coding agent detected",
    smartSessionAwaitingFirstPrompt: "Coding agent detected. Waiting for a prompt.",
    smartSessionAssociationPending: "Prompt observed. Linking session.",
    smartSessionProjectionPending: "Session linked. Building facts.",
    smartSessionIngestionFailed: "Session evidence ingestion failed",
    smartSessionIdentityReconciliationFailed: "Could not reconcile session identity",
    smartSessionProjectionFailed: "Could not read session facts",
    smartSessionUnsupportedOrUnassociated: "No associated supported session",
    smartSessionNotFound: "Session not found",
    smartSessionFailed: "Session refresh failed",
    smartSessionUnknown: "Unknown",
    smartSessionIdentity: "Identity",
    smartSessionPurpose: "Purpose",
    smartSessionCurrentTurn: "Latest turn",
    smartSessionCurrentActivity: "Current activity",
    smartSessionPhase: "Phase",
    smartSessionPrompt: "Prompt",
    smartSessionPlan: "Plan",
    smartSessionEvidence: "Evidence",
    smartSessionCommands: "Commands",
    smartSessionFiles: "Files",
    smartSessionReasoning: "Reasoning",
    smartSessionFinalOutput: "Evidence",
    smartSessionPriorTurns: "Prior turns",
    smartSessionNoPlan: "No plan evidence",
    smartSessionNoEvidence: "No evidence yet",
    smartSessionSessionID: "Session ID",
    smartSessionRevision: "Revision",
    smartSessionThread: "Thread",
    smartSessionTurn: "Turn",
  },
  theme,
};

const providers: ProviderInfo[] = [
  {
    id: "codex",
    displayName: "Codex",
    executableName: "codex",
    transportKind: "stdio-jsonrpc",
    arguments: ["app-server", "--listen", "stdio://"],
    autoStart: true,
  },
  {
    id: "claude",
    displayName: "Claude Code",
    executableName: "claude",
    transportKind: "stdio-jsonl",
    arguments: ["-p"],
    autoStart: false,
  },
];

test("provider started event records running session", () => {
  const starting = reduceSession(
    reduceSession(initialState("react"), { type: "context", context }),
    { type: "starting" },
  );
  const state = reduceSession(starting, {
    type: "event",
    event: {
      type: "provider.started",
      providerId: "codex",
      sessionId: "session-1",
      executablePath: "/usr/local/bin/codex",
      arguments: ["app-server", "--listen", "stdio://"],
    },
  });

  expect(state.status).toBe("running");
  expect(state.runningSessionId).toBe("session-1");
  expect(state.log.at(-1)?.text).toBe("Provider started");
});


test("rate limit row event updates context", () => {
  const initial = reduceSession(initialState("react"), { type: "context", context });
  const state = reduceSession(initial, {
    type: "event",
    event: {
      type: "app.rateLimitRows",
      rateLimitRows: [
        {
          role: "primary",
          remainingPercent: 42,
          resetsAt: 1_850_000_000,
        },
      ],
    },
  });

  expect(state.context?.rateLimitRows).toEqual([
    {
      role: "primary",
      remainingPercent: 42,
      resetsAt: 1_850_000_000,
    },
  ]);
});

test("provider output is appended without changing running session", () => {
  const running = {
    ...initialState("solid"),
    status: "running" as const,
    runningSessionId: "session-1",
  };
  const state = reduceSession(running, {
    type: "event",
    event: {
      type: "provider.output",
      providerId: "claude",
      sessionId: "session-1",
      stream: "stdout",
      text: "{\"type\":\"assistant\"}",
    },
  });

  expect(state.status).toBe("running");
  expect(state.runningSessionId).toBe("session-1");
  expect(state.log.at(-1)?.level).toBe("stdout");
  expect(state.transcript.at(-1)).toMatchObject({
    isComplete: false,
    role: "assistant",
    sessionId: "session-1",
    sentAtMs: expect.any(Number),
    text: "{\"type\":\"assistant\"}",
  });
});

test("provider output log entries are byte bounded", () => {
  const running = {
    ...initialState("solid"),
    status: "running" as const,
    runningSessionId: "session-1",
  };
  const state = reduceSession(running, {
    type: "event",
    event: {
      type: "provider.output",
      providerId: "codex",
      sessionId: "session-1",
      stream: "stdout",
      text: "a".repeat(1024 * 1024),
    },
  });

  const logText = state.log.at(-1)?.text ?? "";
  expect(logText.length).toBeLessThanOrEqual(8 * 1024);
  expect(logText.startsWith("[earlier log output truncated]\n")).toBe(true);
});

test("provider stdout deltas append to the current assistant transcript turn", () => {
  const running = {
    ...initialState("solid"),
    status: "running" as const,
    runningSessionId: "session-1",
  };
  const first = reduceSession(running, {
    type: "event",
    event: {
      type: "provider.output",
      providerId: "codex",
      sessionId: "session-1",
      stream: "stdout",
      text: "hello",
    },
  });
  const second = reduceSession(first, {
    type: "event",
    event: {
      type: "provider.output",
      providerId: "codex",
      sessionId: "session-1",
      stream: "stdout",
      text: " world",
    },
  });

  expect(second.transcript).toHaveLength(1);
  expect(second.transcript[0]).toMatchObject({
    isComplete: false,
    role: "assistant",
    sentAtMs: first.transcript[0]?.sentAtMs,
    text: "hello world",
  });
});

test("provider turn completion marks the active assistant transcript complete", () => {
  const running = {
    ...initialState("solid"),
    status: "running" as const,
    runningSessionId: "session-1",
  };
  const withOutput = reduceSession(running, {
    type: "event",
    event: {
      type: "provider.output",
      providerId: "codex",
      sessionId: "session-1",
      stream: "stdout",
      text: "done",
    },
  });
  const completed = reduceSession(withOutput, {
    type: "event",
    event: {
      type: "provider.turnComplete",
      providerId: "codex",
      sessionId: "session-1",
    },
  });

  expect(completed.status).toBe("running");
  expect(completed.runningSessionId).toBe("session-1");
  expect(completed.transcript[0]).toMatchObject({
    isComplete: true,
    role: "assistant",
    text: "done",
  });
});

test("provider exit marks assistant transcript complete", () => {
  const running = {
    ...initialState("solid"),
    status: "running" as const,
    runningSessionId: "session-1",
  };
  const withOutput = reduceSession(running, {
    type: "event",
    event: {
      type: "provider.output",
      providerId: "codex",
      sessionId: "session-1",
      stream: "stdout",
      text: "done",
    },
  });
  const exited = reduceSession(withOutput, {
    type: "event",
    event: {
      type: "provider.exit",
      providerId: "codex",
      sessionId: "session-1",
      status: 0,
    },
  });

  expect(exited.transcript[0]).toMatchObject({
    isComplete: true,
    role: "assistant",
    text: "done",
  });
});

test("provider activity updates a single transcript turn by activity id", () => {
  const running = {
    ...initialState("solid"),
    status: "running" as const,
    runningSessionId: "session-1",
  };
  const started = reduceSession(running, {
    type: "event",
    event: {
      type: "provider.activity",
      providerId: "codex",
      sessionId: "session-1",
      activityId: "item-1",
      kind: "command",
      status: "inProgress",
      action: "Running",
      detail: "bun test",
    },
  });
  const withOutput = reduceSession(started, {
    type: "event",
    event: {
      type: "provider.activity",
      providerId: "codex",
      sessionId: "session-1",
      activityId: "item-1",
      kind: "command",
      status: "inProgress",
      action: "Running",
      outputDelta: "ok\\n",
    },
  });
  const completed = reduceSession(withOutput, {
    type: "event",
    event: {
      type: "provider.activity",
      providerId: "codex",
      sessionId: "session-1",
      activityId: "item-1",
      kind: "command",
      status: "completed",
      action: "Ran",
      detail: "bun test",
    },
  });

  expect(completed.transcript).toHaveLength(1);
  expect(completed.transcript[0]).toMatchObject({
    role: "activity",
    text: "Ran",
    detail: "bun test",
    output: "ok\\n",
    activityKind: "command",
    activityStatus: "completed",
  });
});

test("provider activity retains raw output metadata across status updates", () => {
  const running = {
    ...initialState("solid"),
    status: "running" as const,
    runningSessionId: "session-1",
  };
  const withOutput = reduceSession(running, {
    type: "event",
    event: {
      type: "provider.activity",
      providerId: "codex",
      sessionId: "session-1",
      activityId: "item-1",
      kind: "command",
      status: "inProgress",
      action: "Running",
      outputDelta: "ok\\n",
      outputMetadata: {
        rawOutputRef: "terminal-output:session-1:item-1",
        rawByteCount: 3,
        rawLineCount: 2,
        wasOptimized: false,
      },
    },
  });
  const completed = reduceSession(withOutput, {
    type: "event",
    event: {
      type: "provider.activity",
      providerId: "codex",
      sessionId: "session-1",
      activityId: "item-1",
      kind: "command",
      status: "completed",
      action: "Ran",
      detail: "echo ok",
    },
  });

  expect(completed.transcript[0]?.outputMetadata).toEqual({
    rawOutputRef: "terminal-output:session-1:item-1",
    rawByteCount: 3,
    rawLineCount: 2,
    wasOptimized: false,
  });
});

test("provider activity output is retained with a bounded tail", () => {
  const running = {
    ...initialState("solid"),
    status: "running" as const,
    runningSessionId: "session-1",
  };
  const started = reduceSession(running, {
    type: "event",
    event: {
      type: "provider.activity",
      providerId: "codex",
      sessionId: "session-1",
      activityId: "item-1",
      kind: "command",
      status: "inProgress",
      action: "Running",
    },
  });
  const first = reduceSession(started, {
    type: "event",
    event: {
      type: "provider.activity",
      providerId: "codex",
      sessionId: "session-1",
      activityId: "item-1",
      kind: "command",
      status: "inProgress",
      action: "Running",
      outputDelta: "a".repeat(70_000),
    },
  });
  const second = reduceSession(first, {
    type: "event",
    event: {
      type: "provider.activity",
      providerId: "codex",
      sessionId: "session-1",
      activityId: "item-1",
      kind: "command",
      status: "completed",
      action: "Ran",
      outputDelta: "tail",
    },
  });

  const output = second.transcript[0]?.output ?? "";
  expect(output.length).toBeLessThanOrEqual(64 * 1024);
  expect(output.startsWith("[earlier command output truncated]\n")).toBe(true);
  expect(output.endsWith("tail")).toBe(true);
});

test("sent action appends a user transcript turn", () => {
  const running = {
    ...reduceSession(initialState("react"), { type: "context", context }),
    status: "running" as const,
    runningSessionId: "session-1",
    input: "hello codex",
  };
  const state = reduceSession(running, {
    type: "sent",
    sessionId: "session-1",
    sentAtMs: 1_850_000_000_000,
    text: "hello codex",
    submittedInput: "hello codex",
  });

  expect(state.input).toBe("");
  expect(state.transcript.at(-1)).toMatchObject({
    role: "user",
    sentAtMs: 1_850_000_000_000,
    text: "hello codex",
  });
});

test("sent action keeps displayed attachments separate from provider prompt text", () => {
  const running = {
    ...reduceSession(initialState("react"), { type: "context", context }),
    status: "running" as const,
    runningSessionId: "session-1",
    input: "describe this",
  };
  const attachment = {
    id: "attachment-1",
    kind: "image" as const,
    label: "moon.jpeg",
    path: "/tmp/moon.jpeg",
    dataUrl: "data:image/jpeg;base64,abc",
  };
  const state = reduceSession(running, {
    type: "sent",
    attachments: [attachment],
    displayText: "describe this",
    sessionId: "session-1",
    text: "[moon.jpeg](/tmp/moon.jpeg)\n\ndescribe this",
    submittedInput: "describe this",
  });

  expect(state.input).toBe("");
  expect(state.log.at(-1)?.text).toBe("Sent 42 chars");
  expect(state.transcript.at(-1)).toMatchObject({
    role: "user",
    text: "describe this",
    attachments: [attachment],
  });
});

test("stderr output appends a warning notice transcript turn", () => {
  const running = {
    ...initialState("solid"),
    status: "running" as const,
    runningSessionId: "session-1",
  };
  const state = reduceSession(running, {
    type: "event",
    event: {
      type: "provider.output",
      providerId: "codex",
      sessionId: "session-1",
      stream: "stderr",
      text: "warning text",
    },
  });

  expect(state.transcript.at(-1)).toMatchObject({
    role: "notice",
    tone: "warning",
    text: "warning text",
  });
});

test("provider output for a different session is ignored", () => {
  const running = {
    ...initialState("solid"),
    status: "running" as const,
    runningSessionId: "session-1",
  };
  const state = reduceSession(running, {
    type: "event",
    event: {
      type: "provider.output",
      providerId: "claude",
      sessionId: "session-x",
      stream: "stdout",
      text: "{\"type\":\"assistant\"}",
    },
  });

  expect(state).toBe(running);
});

test("unknown provider events are ignored", () => {
  const running = {
    ...initialState("solid"),
    status: "running" as const,
    runningSessionId: "session-1",
  };
  const state = reduceSession(running, {
    type: "event",
    event: { type: "provider.unknown", sessionId: "session-1" } as never,
  });

  expect(state).toBe(running);
});

test("accepted start reply tracks session before provider started event", () => {
  const starting = reduceSession(
    reduceSession(initialState("react"), { type: "context", context }),
    { type: "starting" },
  );
  const accepted = reduceSession(starting, { type: "startAccepted", sessionId: "session-1" });

  expect(accepted.status).toBe("starting");
  expect(accepted.runningSessionId).toBe("session-1");
  expect(canStopProvider(accepted)).toBe(true);

  const failed = reduceSession(accepted, {
    type: "event",
    event: {
      type: "provider.exit",
      providerId: "opencode",
      sessionId: "session-1",
      status: 1,
    },
  });

  expect(failed.status).toBe("failed");
  expect(failed.runningSessionId).toBeUndefined();
});

test("provider exit during pending start is applied before start reply", () => {
  const starting = reduceSession(
    reduceSession(initialState("react"), { type: "context", context }),
    { type: "starting" },
  );
  const failed = reduceSession(starting, {
    type: "event",
    event: {
      type: "provider.exit",
      providerId: "codex",
      sessionId: "session-early-exit",
      status: 1,
    },
  });

  expect(failed.status).toBe("failed");
  expect(failed.runningSessionId).toBeUndefined();
  expect(failed.log.at(-1)?.text).toBe("Provider exited 1");

  const staleAccepted = reduceSession(failed, { type: "startAccepted", sessionId: "session-early-exit" });
  expect(staleAccepted.status).toBe("failed");
  expect(staleAccepted.runningSessionId).toBeUndefined();
});

test("stale exit from a previous seen session is ignored during pending start", () => {
  const loaded = reduceSession(initialState("react"), { type: "context", context });
  const firstStart = reduceSession(loaded, { type: "starting" });
  const accepted = reduceSession(firstStart, { type: "startAccepted", sessionId: "session-1" });
  const exited = reduceSession(accepted, {
    type: "event",
    event: {
      type: "provider.exit",
      providerId: "codex",
      sessionId: "session-1",
      status: 0,
    },
  });
  const restarting = reduceSession(exited, { type: "starting" });
  const state = reduceSession(restarting, {
    type: "event",
    event: {
      type: "provider.exit",
      providerId: "codex",
      sessionId: "session-1",
      status: 1,
    },
  });

  expect(state).toBe(restarting);
  expect(state.status).toBe("starting");
});

test("provider exit for a different session is ignored", () => {
  const running = {
    ...initialState("solid"),
    status: "running" as const,
    runningSessionId: "session-1",
  };
  const state = reduceSession(running, {
    type: "event",
    event: {
      type: "provider.exit",
      providerId: "claude",
      sessionId: "session-x",
      status: 143,
    },
  });

  expect(state).toBe(running);
});

test("auto start is enabled for idle auto-start providers after context and providers load", () => {
  const stateWithContext = reduceSession(initialState("react"), { type: "context", context });
  const state = reduceSession(stateWithContext, { type: "providers", providers });

  expect(shouldAutoStartProvider(state)).toBe(true);
});

test("auto start is disabled after a provider has already been attempted", () => {
  const state = reduceSession(
    reduceSession(reduceSession(initialState("react"), { type: "context", context }), {
      type: "providers",
      providers,
    }),
    { type: "autoStartAttempted", providerId: "codex" },
  );

  expect(shouldAutoStartProvider(state)).toBe(false);
});

test("auto start attempts are remembered per provider switch", () => {
  const loaded = reduceSession(
    reduceSession(initialState("react"), { type: "context", context }),
    { type: "providers", providers },
  );
  const attemptedCodex = reduceSession(loaded, { type: "autoStartAttempted", providerId: "codex" });
  const selectedClaude = reduceSession(attemptedCodex, { type: "selectProvider", providerId: "claude" });
  const selectedCodexAgain = reduceSession(selectedClaude, { type: "selectProvider", providerId: "codex" });

  expect(shouldAutoStartProvider(selectedCodexAgain)).toBe(false);
});

test("auto start sends provider start from an explicit snapshot", async () => {
  const loaded = reduceSession(
    reduceSession(initialState("react"), { type: "context", context }),
    { type: "providers", providers },
  );
  const actions: Action[] = [];
  const messages: Array<{ method: string; params: Record<string, unknown> }> = [];
  const globalWithWindow = globalThis as unknown as { window?: unknown };
  const originalWindow = globalWithWindow.window;
  globalWithWindow.window = {
    webkit: {
      messageHandlers: {
        agentSession: {
          async postMessage(message: unknown) {
            messages.push(message as { method: string; params: Record<string, unknown> });
            return { ok: true, value: { sessionId: "session-auto" } };
          },
        },
      },
    },
  };

  try {
    await autoStartProvider(loaded, (action) => actions.push(action));
  } finally {
    if (originalWindow === undefined) {
      delete globalWithWindow.window;
    } else {
      globalWithWindow.window = originalWindow;
    }
  }

  expect(actions.map((action) => action.type)).toEqual(["autoStartAttempted", "starting", "startAccepted"]);
  expect(actions[0]).toEqual({ type: "autoStartAttempted", providerId: "codex" });
  expect(messages[0]?.method).toBe("provider.start");
  expect(messages[0]?.params.providerId).toBe("codex");
});

test("sent input only clears the submitted value", () => {
  const loaded = {
    ...reduceSession(initialState("react"), { type: "context", context }),
    status: "running" as const,
    runningSessionId: "session-1",
  };
  const typed = reduceSession(loaded, { type: "setInput", input: "new draft" });
  const state = reduceSession(typed, {
    type: "sent",
    sessionId: "session-1",
    text: "old draft",
    submittedInput: "old draft",
  });

  expect(state.input).toBe("new draft");
  expect(state.log.at(-1)?.text).toBe("Sent 9 chars");
});

test("late sent replies do not overwrite a requested stop", () => {
  const stopping = {
    ...reduceSession(initialState("react"), { type: "context", context }),
    status: "stopping" as const,
    runningSessionId: "session-1",
    requestedStopSessionId: "session-1",
    input: "draft",
  };
  const state = reduceSession(stopping, {
    type: "sent",
    sessionId: "session-1",
    text: "draft",
    submittedInput: "draft",
  });

  expect(state).toBe(stopping);
});

test("send waits until provider is running after start is accepted", async () => {
  const loaded = reduceSession(initialState("react"), { type: "context", context });
  const starting = {
    ...reduceSession(loaded, { type: "setInput", input: "hello" }),
    status: "starting" as const,
    runningSessionId: "session-1",
  };
  const actions: Action[] = [];
  const messages: unknown[] = [];
  const globalWithWindow = globalThis as unknown as { window?: unknown };
  const originalWindow = globalWithWindow.window;
  globalWithWindow.window = {
    webkit: {
      messageHandlers: {
        agentSession: {
          async postMessage(message: unknown) {
            messages.push(message);
            return { ok: false, error: { userMessage: "Provider not ready" } };
          },
        },
      },
    },
  };

  try {
    await sendInput(starting, (action) => actions.push(action));
  } finally {
    if (originalWindow === undefined) {
      delete globalWithWindow.window;
    } else {
      globalWithWindow.window = originalWindow;
    }
  }

  expect(messages).toHaveLength(0);
  expect(actions).toHaveLength(0);
});

test("send includes selected permission mode", async () => {
  const running = {
    ...reduceSession(initialState("react"), { type: "context", context }),
    input: "needs access",
    status: "running" as const,
    runningSessionId: "session-1",
  };
  const messages: Array<{ method: string; params: Record<string, unknown> }> = [];
  const globalWithWindow = globalThis as unknown as { window?: unknown };
  const originalWindow = globalWithWindow.window;
  globalWithWindow.window = {
    webkit: {
      messageHandlers: {
        agentSession: {
          async postMessage(message: unknown) {
            messages.push(message as { method: string; params: Record<string, unknown> });
            return { ok: true, value: { sent: true } };
          },
        },
      },
    },
  };

  try {
    await sendInput(running, () => {}, { permissionMode: "full-access" });
  } finally {
    if (originalWindow === undefined) {
      delete globalWithWindow.window;
    } else {
      globalWithWindow.window = originalWindow;
    }
  }

  expect(messages[0]?.method).toBe("provider.writeLine");
  expect(messages[0]?.params.permissionMode).toBe("full-access");
});

test("stop preserves running session until provider exit arrives", () => {
  const running = {
    ...reduceSession(initialState("react"), { type: "context", context }),
    status: "running" as const,
    runningSessionId: "session-1",
  };
  const stopping = reduceSession(running, { type: "stopping", sessionId: "session-1" });

  expect(stopping.status).toBe("stopping");
  expect(stopping.runningSessionId).toBe("session-1");
  expect(stopping.requestedStopSessionId).toBe("session-1");
  expect(statusLabel(stopping)).toBe("Stopping");
});

test("requested stop exits return to idle even with signal status", () => {
  const stopping = {
    ...reduceSession(initialState("react"), { type: "context", context }),
    status: "stopping" as const,
    runningSessionId: "session-1",
    requestedStopSessionId: "session-1",
  };
  const state = reduceSession(stopping, {
    type: "event",
    event: {
      type: "provider.exit",
      providerId: "codex",
      sessionId: "session-1",
      status: 15,
    },
  });

  expect(state.status).toBe("idle");
  expect(state.runningSessionId).toBeUndefined();
  expect(state.requestedStopSessionId).toBeUndefined();
  expect(state.log.at(-1)?.text).toBe("Stopped");
});

test("late stop failures do not overwrite a clean stop exit", () => {
  const stopping = {
    ...reduceSession(initialState("react"), { type: "context", context }),
    status: "stopping" as const,
    runningSessionId: "session-1",
    requestedStopSessionId: "session-1",
  };
  const stopped = reduceSession(stopping, {
    type: "event",
    event: {
      type: "provider.exit",
      providerId: "codex",
      sessionId: "session-1",
      status: 15,
    },
  });
  const state = reduceSession(stopped, {
    type: "stopFailed",
    sessionId: "session-1",
    message: "The agent session is no longer available.",
  });

  expect(state.status).toBe("idle");
  expect(state.runningSessionId).toBeUndefined();
  expect(state.log.at(-1)?.text).toBe("Stopped");
});

test("late send failures do not overwrite a requested stop", () => {
  const stopping = {
    ...reduceSession(initialState("react"), { type: "context", context }),
    status: "stopping" as const,
    runningSessionId: "session-1",
    requestedStopSessionId: "session-1",
  };
  const state = reduceSession(stopping, {
    type: "sendFailed",
    sessionId: "session-1",
    message: "Native bridge request failed.",
  });

  expect(state).toBe(stopping);
});

test("session-scoped failures do not overwrite a requested stop", () => {
  const stopping = {
    ...reduceSession(initialState("react"), { type: "context", context }),
    status: "stopping" as const,
    runningSessionId: "session-1",
    requestedStopSessionId: "session-1",
  };
  const state = reduceSession(stopping, {
    type: "failedForSession",
    sessionId: "session-1",
    message: "Native bridge request failed.",
  });

  expect(state).toBe(stopping);
});

test("bridge request errors use copy from session state", () => {
  const state = reduceSession(initialState("react"), {
    type: "context",
    context: {
      ...context,
      copy: { ...context.copy, requestFailed: "Localized bridge failure." },
    },
  });

  expect(messageForError(new Error("Native bridge request failed."), state)).toBe("Localized bridge failure.");
});

test("smart session refresh waits until the Session surface is active", () => {
  expect(shouldRefreshSmartSession(false, false)).toBe(false);
  expect(shouldRefreshSmartSession(false, true)).toBe(false);
  expect(shouldRefreshSmartSession(true, false)).toBe(false);
  expect(shouldRefreshSmartSession(true, true)).toBe(true);
});

test("send failures for the active running session keep stop available", () => {
  const running = {
    ...reduceSession(initialState("react"), { type: "context", context }),
    status: "running" as const,
    runningSessionId: "session-1",
  };
  const state = reduceSession(running, {
    type: "sendFailed",
    sessionId: "session-1",
    message: "Native bridge request failed.",
  });

  expect(state.status).toBe("failed");
  expect(state.runningSessionId).toBe("session-1");
  expect(canStopProvider(state)).toBe(true);
});

test("transient provider busy send failures keep the session running", async () => {
  const running = {
    ...reduceSession(initialState("react"), { type: "context", context }),
    input: "second turn",
    status: "running" as const,
    runningSessionId: "session-1",
  };
  const actions: Action[] = [];
  const messages: unknown[] = [];
  const globalWithWindow = globalThis as unknown as { window?: unknown };
  const originalWindow = globalWithWindow.window;
  globalWithWindow.window = {
    webkit: {
      messageHandlers: {
        agentSession: {
          async postMessage(message: unknown) {
            messages.push(message);
            return {
              ok: false,
              error: {
                code: "providerNotReady",
                userMessage: "The provider is not ready yet.",
              },
            };
          },
        },
      },
    },
  };

  try {
    const sent = await sendInput(running, (action) => actions.push(action));
    expect(sent).toBe(false);
  } finally {
    if (originalWindow === undefined) {
      delete globalWithWindow.window;
    } else {
      globalWithWindow.window = originalWindow;
    }
  }

  expect(messages).toHaveLength(1);
  expect(actions).toHaveLength(0);
});

test("stop failures for an active session keep stop available", () => {
  const stopping = {
    ...reduceSession(initialState("react"), { type: "context", context }),
    status: "stopping" as const,
    runningSessionId: "session-1",
    requestedStopSessionId: "session-1",
  };
  const state = reduceSession(stopping, {
    type: "stopFailed",
    sessionId: "session-1",
    message: "Native bridge request failed.",
  });

  expect(state.status).toBe("failed");
  expect(state.runningSessionId).toBe("session-1");
  expect(state.requestedStopSessionId).toBeUndefined();
  expect(canStopProvider(state)).toBe(true);
});

test("provider started during a requested stop is ignored", () => {
  const stopping = {
    ...reduceSession(initialState("react"), { type: "context", context }),
    status: "stopping" as const,
    runningSessionId: "session-1",
    requestedStopSessionId: "session-1",
  };
  const state = reduceSession(stopping, {
    type: "event",
    event: {
      type: "provider.started",
      providerId: "codex",
      sessionId: "session-1",
      executablePath: "/usr/local/bin/codex",
      arguments: ["app-server", "--listen", "stdio://"],
    },
  });

  expect(state).toBe(stopping);
});

test("format templates honor positional specifiers", () => {
  expect(formatTemplate("%2$@ %1$d", [7, "files"])).toBe("files 7");
});

test("failed calls with an active session keep stop available", () => {
  const running = {
    ...reduceSession(initialState("react"), { type: "context", context }),
    status: "running" as const,
    runningSessionId: "session-1",
  };
  const failed = reduceSession(running, { type: "failed", message: "Native bridge request failed." });

  expect(failed.status).toBe("failed");
  expect(failed.runningSessionId).toBe("session-1");
  expect(canStopProvider(failed)).toBe(true);
});

test("claude does not auto start", () => {
  const claudeContext = { ...context, initialProviderId: "claude" as const };
  const state = reduceSession(
    reduceSession(initialState("react"), { type: "context", context: claudeContext }),
    { type: "providers", providers },
  );

  expect(shouldAutoStartProvider(state)).toBe(false);
});

test("provider selection is blocked while a failed session is still active", () => {
  const failedWithActiveSession = {
    ...reduceSession(initialState("react"), { type: "context", context }),
    status: "failed" as const,
    runningSessionId: "session-1",
  };
  const state = reduceSession(failedWithActiveSession, { type: "selectProvider", providerId: "claude" });

  expect(canSelectProvider(failedWithActiveSession)).toBe(false);
  expect(state.selectedProviderId).toBe("codex");
});

test("provider selection is allowed after a failed start without an active session", () => {
  const failedWithoutSession = {
    ...reduceSession(initialState("react"), { type: "context", context }),
    status: "failed" as const,
  };
  const state = reduceSession(failedWithoutSession, { type: "selectProvider", providerId: "claude" });

  expect(canSelectProvider(failedWithoutSession)).toBe(true);
  expect(state.selectedProviderId).toBe("claude");
});

test("client ids do not require crypto.randomUUID", () => {
  const descriptor = Object.getOwnPropertyDescriptor(globalThis, "crypto");
  Object.defineProperty(globalThis, "crypto", {
    configurable: true,
    value: {
      getRandomValues(bytes: Uint8Array) {
        bytes.fill(7);
        return bytes;
      },
    },
  });

  try {
    expect(makeClientId()).toMatch(/^[0-9a-f-]{36}$/);
    const loaded = reduceSession(initialState("react"), { type: "context", context });
    expect(loaded.log[0]?.id).toMatch(/^[0-9a-f-]{36}$/);
  } finally {
    if (descriptor) {
      Object.defineProperty(globalThis, "crypto", descriptor);
    } else {
      delete (globalThis as { crypto?: unknown }).crypto;
    }
  }
});

test("smart session reducer ignores an older refresh response", () => {
  const loading = reduceSmartSession(initialSmartSessionState(), { type: "refreshStarted", requestId: 2 });
  const state = reduceSmartSession(loading, {
    type: "refreshSucceeded",
    requestId: 1,
    result: {
      schemaVersion: 1,
      status: "available",
      snapshot: smartSessionSnapshot({ factualRevision: 1 }),
    },
  });

  expect(state.status).toBe("loading");
  expect(state.snapshot).toBeUndefined();
});

test("smart session reducer keeps newer factual revisions", () => {
  const current = reduceSmartSession(initialSmartSessionState(), {
    type: "refreshSucceeded",
    requestId: 1,
    result: {
      schemaVersion: 1,
      status: "available",
      snapshot: smartSessionSnapshot({ factualRevision: 4 }),
    },
  });
  const state = reduceSmartSession(current, {
    type: "refreshSucceeded",
    requestId: 2,
    result: {
      schemaVersion: 1,
      status: "available",
      snapshot: smartSessionSnapshot({ factualRevision: 3 }),
    },
  });

  expect(state.snapshot?.revision.factualRevision).toBe(4);
});

test("smart session reducer keeps newer SessionWorkModel semantic revisions", () => {
  const current = reduceSmartSession(initialSmartSessionState(), {
    type: "refreshSucceeded",
    requestId: 1,
    result: {
      schemaVersion: 1,
      status: "available",
      snapshot: smartSessionSnapshot({
        factualRevision: 4,
        latestSemanticInferenceCreatedAt: "2026-08-17T07:05:00.000Z",
      }),
    },
  });
  const state = reduceSmartSession(current, {
    type: "refreshSucceeded",
    requestId: 2,
    result: {
      schemaVersion: 1,
      status: "available",
      snapshot: smartSessionSnapshot({
        factualRevision: 4,
        latestSemanticInferenceCreatedAt: "2026-08-17T07:03:00.000Z",
      }),
    },
  });
  expect(state.snapshot?.revision.latestSemanticInferenceCreatedAt).toBe("2026-08-17T07:05:00.000Z");
});

test("smart session reads supported meaning from SessionWorkModel fields", () => {
  const model = smartSessionSnapshot({ factualRevision: 2, threadIntent: "Build Smart Session bridge" });
  expect(model.workModel?.thread?.intent.kind).toBe(SMART_SESSION_SEMANTIC_KINDS.threadIntent);
  expect(model.workModel?.thread?.intent.summary).toBe("Build Smart Session bridge");
});

test("smart session transfers semantic messages by exact PE kind and scope", () => {
  const model = smartSessionSnapshot({
    factualRevision: 2,
    semanticMessages: [
      semanticMessage({
        kind: SMART_SESSION_SEMANTIC_KINDS.threadIntent,
        scope: "thread",
        scopeId: "thread-1",
        concisePhrase: "Build Smart Session bridge",
      }),
      semanticMessage({
        kind: SMART_SESSION_SEMANTIC_KINDS.sessionPhase,
        scope: "session",
        scopeId: "session-1",
        concisePhrase: "implementation",
      }),
    ],
  });

  expect(
    semanticMessageForKind(model, {
      kind: SMART_SESSION_SEMANTIC_KINDS.threadIntent,
      scope: "thread",
      scopeId: "thread-1",
    })?.concisePhrase,
  ).toBe("Build Smart Session bridge");
  expect(
    semanticMessageForKind(model, {
      kind: SMART_SESSION_SEMANTIC_KINDS.threadIntent,
      scope: "session",
      scopeId: "session-1",
    }),
  ).toBeUndefined();
});

test("smart session leaves unknown semantics absent instead of inferring from prompt text", () => {
  const model = smartSessionSnapshot({
    factualRevision: 1,
    prompt: "Blocked on milestone 2 and 75% complete",
    semanticMessages: [],
    knownSemantics: false,
  });

  expect(
    semanticFieldForKind(model, {
      kind: SMART_SESSION_SEMANTIC_KINDS.currentActivity,
      scope: "turn",
      scopeId: "turn-1",
    })?.state,
  ).toBe("unknown");
  expect(model.semanticMessages.map((message) => message.concisePhrase).join(" ")).not.toContain("Blocked");
  expect(model.semanticMessages.map((message) => message.concisePhrase).join(" ")).not.toContain("75%");
});

function smartSessionSnapshot({
  factualRevision,
  prompt = "Add a Smart Session surface",
  semanticMessages = [],
  latestSemanticInferenceCreatedAt = "2026-08-17T07:02:00.000Z",
  knownSemantics = true,
  threadIntent = "Add a Smart Session surface",
  turnIntent = "Add a Smart Session surface",
  currentActivity = "Rendering supported session meaning",
  sessionPhase = "implementation",
}: {
  factualRevision: number;
  prompt?: string;
  semanticMessages?: SmartSessionSnapshot["semanticMessages"];
  latestSemanticInferenceCreatedAt?: string;
  knownSemantics?: boolean;
  threadIntent?: string;
  turnIntent?: string;
  currentActivity?: string;
  sessionPhase?: string;
}): SmartSessionSnapshot {
  const semanticInferenceIds = knownSemantics
    ? [
        `inference-${SMART_SESSION_SEMANTIC_KINDS.sessionPhase}`,
        `inference-${SMART_SESSION_SEMANTIC_KINDS.threadIntent}`,
        `inference-${SMART_SESSION_SEMANTIC_KINDS.turnIntent}`,
        `inference-${SMART_SESSION_SEMANTIC_KINDS.currentActivity}`,
      ]
    : [];
  const modelRevisionKey = `schema:1|factual:${factualRevision}|semantic:${semanticInferenceIds.join(",")}`;
  const providerThread = {
    confidence: "high",
    firstObservedAt: "2026-08-17T07:00:00.000Z",
    provider: "codex",
    providerThreadId: "provider-thread-1",
    source: "observed",
    threadId: "thread-1",
    updatedAt: "2026-08-17T07:01:00.000Z",
  };
  return {
    schemaVersion: 1,
    revision: {
      schemaVersion: 3,
      factualRevision,
      key: modelRevisionKey,
      latestSemanticInferenceCreatedAt: knownSemantics ? latestSemanticInferenceCreatedAt : undefined,
      latestSemanticMessageCreatedAt: semanticMessages[0]?.createdAt,
      modelRevisionKey,
      semanticInferenceIds,
      semanticMessageCount: semanticMessages.length,
    },
    identity: {
      agentKind: "codex",
      cwd: "/repo",
      providerThreads: [providerThread],
      sessionId: "session-1",
      startedAt: "2026-08-17T07:00:00.000Z",
      status: "active",
      updatedAt: "2026-08-17T07:01:00.000Z",
      workspaceId: "workspace-1",
    },
    workModel: {
      schemaVersion: 1,
      revision: {
        factualRevision,
        latestSemanticInferenceCreatedAt: knownSemantics ? latestSemanticInferenceCreatedAt : undefined,
        modelRevisionKey,
        schemaVersion: 1,
        semanticInferenceIds,
      },
      thread: {
        identity: providerThread,
        intent: semanticField({
          kind: SMART_SESSION_SEMANTIC_KINDS.threadIntent,
          known: knownSemantics,
          scope: "thread",
          scopeId: "thread-1",
          summary: threadIntent,
        }),
      },
      currentTurn: {
        currentActivity: semanticField({
          kind: SMART_SESSION_SEMANTIC_KINDS.currentActivity,
          known: knownSemantics,
          scope: "turn",
          scopeId: "turn-1",
          summary: currentActivity,
        }),
        intent: semanticField({
          kind: SMART_SESSION_SEMANTIC_KINDS.turnIntent,
          known: knownSemantics,
          scope: "turn",
          scopeId: "turn-1",
          summary: turnIntent,
        }),
        threadId: "thread-1",
        turnId: "turn-1",
      },
      sessionPhase: semanticField({
        kind: SMART_SESSION_SEMANTIC_KINDS.sessionPhase,
        known: knownSemantics,
        scope: "session",
        scopeId: "session-1",
        summary: sessionPhase,
      }),
    },
    factual: {
      latestTurn: {
        assistantMessages: [],
        completedCommands: [],
        fileChangeAttributions: [],
        provider: "codex",
        providerTurnId: "provider-turn-1",
        prompt: {
          confidence: "high",
          promptId: "prompt-1",
          source: "observed",
          submittedAt: "2026-08-17T07:00:00.000Z",
          text: prompt,
        },
        status: "completed",
        threadId: "thread-1",
        turnId: "turn-1",
        updatedAt: "2026-08-17T07:01:00.000Z",
        visibleReasoningSummaries: [],
      },
      priorTurns: [],
      turnCount: 1,
    },
    semanticMessages,
    semanticMessagesReadStatus: "unavailable",
    crossSessionAwareness: {
      status: "available",
      relatedSessions: [],
      collisions: [],
      relatedOmittedCount: 0,
      collisionOmittedCount: 0,
    },
  };
}

function semanticField({
  kind,
  scope,
  scopeId,
  summary,
  known = true,
}: {
  kind: string;
  scope: "session" | "thread" | "turn";
  scopeId: string;
  summary: string;
  known?: boolean;
}): NonNullable<SmartSessionSnapshot["workModel"]>["sessionPhase"] {
  if (!known) {
    return {
      kind,
      reason: "no_active_semantic_inference",
      scope,
      scopeId,
      state: "unknown",
    };
  }
  return {
    detail: summary,
    kind,
    record: {
      confidence: "high",
      createdAt: "2026-08-17T07:02:00.000Z",
      inferenceId: `inference-${kind}`,
      payload: { summary },
      producerId: "producer",
      producerType: "rule",
      producerVersion: "v1",
      schemaVersion: 1,
      specificity: "scoped",
      status: "active",
      supersedes: [],
      supportingEvidenceRefs: [{ factualRevision: 1, id: "turn-1", kind: "coding_agent_turn" }],
      supportingFactualRevision: 1,
    },
    scope,
    scopeId,
    state: "known",
    summary,
  };
}

function semanticMessage({
  kind,
  scope,
  scopeId,
  concisePhrase,
}: {
  kind: string;
  scope: "session" | "thread" | "turn";
  scopeId: string;
  concisePhrase: string;
}): SmartSessionSnapshot["semanticMessages"][number] {
  return {
    concisePhrase,
    confidence: "high",
    createdAt: "2026-08-17T07:02:00.000Z",
    expandedMeaning: concisePhrase,
    messageId: `message-${kind}`,
    presentationPolicyId: "policy",
    presentationPolicyVersion: "v1",
    presentationProducerId: "producer",
    presentationProducerVersion: "v1",
    scope,
    scopeId,
    semanticInferenceId: `inference-${kind}`,
    semanticInferenceKind: kind,
    specificity: "scoped",
    status: "active",
    supportingFactualRevision: 1,
  };
}


test("smart session labels tool-only and assistant evidence without claiming a final output", async () => {
  const catalog: unknown = await Bun.file("Resources/Localizable.xcstrings").json();
  function field(value: unknown, key: string): unknown {
    if (typeof value !== "object" || value === null || !(key in value)) throw new Error(`Missing catalog field ${key}`);
    return Reflect.get(value, key);
  }
  const strings = field(catalog, "strings");
  const localizations = field(field(strings, "agentSession.web.smartSession.finalOutput"), "localizations");
  const englishCopy = field(field(field(localizations, "en"), "stringUnit"), "value");
  if (typeof englishCopy !== "string") throw new Error("Missing localized Smart Session label");
  const localizedContext: AppContext = { ...context, copy: { ...context.copy, smartSessionFinalOutput: englishCopy } };
  for (const kind of ["tool", "assistant"]) {
    const dom = new JSDOM("<!doctype html><div id='root'></div>", { url: "https://example.test" });
    const previousWindow = globalThis.window;
    const previousDocument = globalThis.document;
    Object.assign(globalThis, { window: dom.window, document: dom.window.document, IS_REACT_ACT_ENVIRONMENT: true });
    const original = smartSessionSnapshot({ factualRevision: 1 });
    const turn = original.factual.latestTurn;
    if (!turn) throw new Error("Expected current turn in fixture");
    const snapshot: SmartSessionSnapshot = { ...original, factual: { ...original.factual, latestTurn: {
      ...turn,
      completedCommands: kind === "tool" ? [{ commandId: "cmd", command: "swift test", status: "failed", completedAt: "2026-08-17T07:01:00Z", source: "observed", confidence: "high" }] : [],
      assistantMessages: kind === "assistant" ? [{ messageId: "message", text: "Still investigating", completedAt: "2026-08-17T07:01:00Z", source: "observed", confidence: "high" }] : [],
    } } };
    Object.assign(dom.window, { webkit: { messageHandlers: { agentSession: {
      postMessage: async () => ({ ok: true, value: { schemaVersion: 1, status: "available", snapshot } }),
    } } } });
    const container = dom.window.document.getElementById("root");
    if (!container) throw new Error("Missing root");
    const root = createRoot(container);
    try {
      await act(async () => { root.render(createElement(SmartSessionSurface, { context: localizedContext })); });
      const section = dom.window.document.querySelector(".focus-results");
      expect(section?.querySelector("h3")?.textContent).toBe("Evidence");
      expect(section?.textContent).toContain(kind === "tool" ? "swift test" : "Still investigating");
      expect(section?.textContent).not.toContain("Final output");
    } finally {
      await act(async () => root.unmount());
      dom.window.close();
      Object.assign(globalThis, { window: previousWindow, document: previousDocument, IS_REACT_ACT_ENVIRONMENT: false });
    }
  }
});

test("smart session does not label a cached snapshot available after bridge failure", () => {
  const current = reduceSmartSession(initialSmartSessionState(), {
    type: "refreshSucceeded", requestId: 1,
    result: { schemaVersion: 1, status: "available", snapshot: smartSessionSnapshot({ factualRevision: 4 }) },
  });
  const failed = reduceSmartSession(current, { type: "refreshFailed", requestId: 2 });
  expect(failed.status).toBe("failed");
  expect(failed.snapshot?.revision.factualRevision).toBe(4);
});


test("smart session keeps failed bridge snapshots marked stale and clears not-found", () => {
  const snapshot = smartSessionSnapshot({ factualRevision: 4 });
  const stale = reduceSmartSession(initialSmartSessionState(), {
    type: "refreshSucceeded", requestId: 1,
    result: { schemaVersion: 1, status: "failed", snapshot, lastSuccessfulReadAt: "2026-08-17T07:05:00Z" },
  });
  expect(stale.status).toBe("failed");
  expect(stale.snapshot).toEqual(snapshot);
  expect(stale.lastSuccessfulReadAt).toBe("2026-08-17T07:05:00Z");
  const missing = reduceSmartSession(stale, { type: "refreshSucceeded", requestId: 2,
    result: { schemaVersion: 1, status: "notFound" } });
  expect(missing.snapshot).toBeUndefined();
});

test("smart session never attaches failed response to a different session", () => {
  const current = reduceSmartSession(initialSmartSessionState(), {
    type: "refreshSucceeded", requestId: 1,
    result: { schemaVersion: 1, status: "available", snapshot: smartSessionSnapshot({ factualRevision: 4 }) },
  });
  const failed = reduceSmartSession(current, { type: "refreshSucceeded", requestId: 2,
    result: { schemaVersion: 1, status: "projectionFailed", sessionId: "different-session" } });
  expect(failed.snapshot).toBeUndefined();
});


test("smart session visibly labels retained facts after failure", () => {
  const state = reduceSmartSession(initialSmartSessionState(), { type: "refreshSucceeded", requestId: 1,
    result: { schemaVersion: 1, status: "failed", snapshot: smartSessionSnapshot({ factualRevision: 4 }), lastSuccessfulReadAt: "2026-08-17T07:05:00Z" } });
  const markup = renderToStaticMarkup(createElement(SmartSessionFreshnessBanner, { state, onRefresh: () => {} }));
  expect(markup).toContain('role="status"');
  expect(markup).toContain("Could not refresh. Showing last known session data.");
  expect(markup).toContain("Session data last read");
  expect(markup).toContain("Refresh");
});

test("smart session replaces an older revision from a different session", () => {
  const first = smartSessionSnapshot({ factualRevision: 10 });
  const second = smartSessionSnapshot({ factualRevision: 1 });
  const replacement = { ...second, identity: { ...second.identity, sessionId: "another-session" } };
  const current = reduceSmartSession(initialSmartSessionState(), { type: "refreshSucceeded", requestId: 1,
    result: { schemaVersion: 1, status: "available", snapshot: first } });
  const next = reduceSmartSession(current, { type: "refreshSucceeded", requestId: 2,
    result: { schemaVersion: 1, status: "available", snapshot: replacement } });
  expect(next.snapshot?.identity.sessionId).toBe("another-session");
  expect(next.snapshot?.revision.factualRevision).toBe(1);
});

test("a late failed refresh cannot replace a newer successful refresh", () => {
  const current = reduceSmartSession(initialSmartSessionState(), { type: "refreshSucceeded", requestId: 2,
    result: { schemaVersion: 1, status: "available", snapshot: smartSessionSnapshot({ factualRevision: 4 }) } });
  const late = reduceSmartSession(current, { type: "refreshFailed", requestId: 1 });
  expect(late).toEqual(current);
});

test("smart session retains the last read time when a later failure keeps the same snapshot", () => {
  const snapshot = smartSessionSnapshot({ factualRevision: 4 });
  const first = reduceSmartSession(initialSmartSessionState(), { type: "refreshSucceeded", requestId: 1,
    result: { schemaVersion: 1, status: "failed", snapshot, lastSuccessfulReadAt: "2026-08-17T07:05:00Z" } });
  const later = reduceSmartSession(first, { type: "refreshSucceeded", requestId: 2,
    result: { schemaVersion: 1, status: "projectionFailed", sessionId: snapshot.identity.sessionId } });
  expect(later.snapshot).toEqual(snapshot);
  expect(later.status).toBe("projectionFailed");
  expect(later.lastSuccessfulReadAt).toBe("2026-08-17T07:05:00Z");
});

test("smart session clears read time when a failure names a different session", () => {
  const first = reduceSmartSession(initialSmartSessionState(), { type: "refreshSucceeded", requestId: 1,
    result: { schemaVersion: 1, status: "failed", snapshot: smartSessionSnapshot({ factualRevision: 4 }), lastSuccessfulReadAt: "2026-08-17T07:05:00Z" } });
  const next = reduceSmartSession(first, { type: "refreshSucceeded", requestId: 2,
    result: { schemaVersion: 1, status: "projectionFailed", sessionId: "different-session" } });
  expect(next.snapshot).toBeUndefined();
  expect(next.lastSuccessfulReadAt).toBeUndefined();
});


test("smart session keeps ambiguous equal-ranked semantic revisions as stale", () => {
  const first = smartSessionSnapshot({ factualRevision: 4 });
  const second = { ...first, revision: { ...first.revision, semanticInferenceIds: first.revision.semanticInferenceIds?.map(id => `${id}-replacement`) } };
  const state = reduceSmartSession(initialSmartSessionState(), { type: "refreshSucceeded", requestId: 1,
    result: { schemaVersion: 1, status: "available", snapshot: first } });
  const result = reduceSmartSession(state, { type: "refreshSucceeded", requestId: 2,
    result: { schemaVersion: 1, status: "available", snapshot: second } });
  expect(result.status).toBe("failed");
  expect(result.snapshot).toEqual(first);
});


test("smart session accepts a truly identical equal-ranked snapshot", () => {
  const snapshot = smartSessionSnapshot({ factualRevision: 4 });
  const current = reduceSmartSession(initialSmartSessionState(), { type: "refreshSucceeded", requestId: 1,
    result: { schemaVersion: 1, status: "available", snapshot } });
  const next = reduceSmartSession(current, { type: "refreshSucceeded", requestId: 2,
    result: { schemaVersion: 1, status: "available", snapshot } });
  expect(next.status).toBe("available");
  expect(next.snapshot).toEqual(snapshot);
});


test("smart session treats differing semantic counts as unordered", () => {
  const first = smartSessionSnapshot({ factualRevision: 4 });
  const alternatives = [
    { ...first, revision: { ...first.revision, semanticInferenceIds: [...(first.revision.semanticInferenceIds ?? []), "new-id"] } },
    { ...first, revision: { ...first.revision, semanticMessageCount: first.revision.semanticMessageCount + 1 } },
  ];
  const initial = reduceSmartSession(initialSmartSessionState(), { type: "refreshSucceeded", requestId: 1,
    result: { schemaVersion: 1, status: "available", snapshot: first } });
  for (const candidate of alternatives) {
    const result = reduceSmartSession(initial, { type: "refreshSucceeded", requestId: 2,
      result: { schemaVersion: 1, status: "available", snapshot: candidate } });
    expect(result.status).toBe("failed");
    expect(result.snapshot).toEqual(first);
  }
});


test("independent awareness updates do not freeze an unchanged primary snapshot", () => {
  const sample = smartSessionSnapshot({ factualRevision: 4 });
  const first: SmartSessionSnapshot = { ...sample, crossSessionAwareness: { ...sample.crossSessionAwareness, status: "unavailable" } };
  const next: SmartSessionSnapshot = { ...first, crossSessionAwareness: { ...first.crossSessionAwareness, status: "available" } };
  const initial = reduceSmartSession(initialSmartSessionState(), { type: "refreshSucceeded", requestId: 1,
    result: { schemaVersion: 1, status: "available", snapshot: first } });
  const result = reduceSmartSession(initial, { type: "refreshSucceeded", requestId: 2,
    result: { schemaVersion: 1, status: "available", snapshot: next } });
  expect(result.status).toBe("available");
  expect(result.snapshot?.crossSessionAwareness.status).toBe("available");
});

test("semantic reports recover after an unavailable read without a factual revision change", () => {
  const first = smartSessionSnapshot({ factualRevision: 4 });
  const message = semanticMessage({ kind: "test", scope: "session", scopeId: "session-1", concisePhrase: "Observed" });
  const recovered: SmartSessionSnapshot = { ...first, semanticMessages: [message], semanticMessagesReadStatus: "available",
    revision: { ...first.revision, semanticMessageCount: 1, latestSemanticMessageCreatedAt: message.createdAt } };
  const initial = reduceSmartSession(initialSmartSessionState(), { type: "refreshSucceeded", requestId: 1,
    result: { schemaVersion: 1, status: "available", snapshot: first } });
  const result = reduceSmartSession(initial, { type: "refreshSucceeded", requestId: 2,
    result: { schemaVersion: 1, status: "available", snapshot: recovered } });
  expect(result.status).toBe("available");
  expect(result.snapshot?.semanticMessages).toEqual([message]);
});

test("semantic recovery does not bypass an ambiguous changed primary model", () => {
  const first = smartSessionSnapshot({ factualRevision: 4 });
  const message = semanticMessage({ kind: "test", scope: "session", scopeId: "session-1", concisePhrase: "Observed" });
  const candidate: SmartSessionSnapshot = { ...first, semanticMessages: [message], semanticMessagesReadStatus: "available",
    revision: { ...first.revision, semanticMessageCount: 1, latestSemanticMessageCreatedAt: message.createdAt },
    identity: { ...first.identity, status: "completed" } };
  const initial = reduceSmartSession(initialSmartSessionState(), { type: "refreshSucceeded", requestId: 1,
    result: { schemaVersion: 1, status: "available", snapshot: first } });
  const result = reduceSmartSession(initial, { type: "refreshSucceeded", requestId: 2,
    result: { schemaVersion: 1, status: "available", snapshot: candidate } });
  expect(result.status).toBe("failed");
  expect(result.snapshot?.identity.status).toBe(first.identity.status);
});

test("ambiguous primary facts retain separately observed awareness", () => {
  const first = smartSessionSnapshot({ factualRevision: 4 });
  const second: SmartSessionSnapshot = { ...first,
    revision: { ...first.revision, semanticInferenceIds: ["replacement"] },
    crossSessionAwareness: { ...first.crossSessionAwareness, status: "unavailable" },
  };
  const initial = reduceSmartSession(initialSmartSessionState(), { type: "refreshSucceeded", requestId: 1,
    result: { schemaVersion: 1, status: "available", snapshot: first } });
  const result = reduceSmartSession(initial, { type: "refreshSucceeded", requestId: 2,
    result: { schemaVersion: 1, status: "available", snapshot: second } });
  expect(result.status).toBe("failed");
  expect(result.snapshot?.revision).toEqual(first.revision);
  expect(result.snapshot?.crossSessionAwareness.status).toBe("unavailable");
});


test("related work reports each source's read availability", () => {
  const awareness = smartSessionSnapshot({ factualRevision: 4 }).crossSessionAwareness;
  const variants: Array<[SmartSessionSnapshot["crossSessionAwareness"], string]> = [
    [{ ...awareness, status: "unavailable", relatedReadStatus: "unavailable", collisionReadStatus: "unavailable" }, "Related work is unavailable."],
    [{ ...awareness, relatedReadStatus: "available", collisionReadStatus: "unavailable" }, "Some related-work information is incomplete or unavailable."],
    [{ ...awareness, relatedReadStatus: "partial", collisionReadStatus: "available" }, "Some related-work information is incomplete or unavailable."],
    [{ ...awareness, relatedReadStatus: "unavailable", collisionReadStatus: "available" }, "Some related-work information is incomplete or unavailable."],
    [{ ...awareness, relatedReadStatus: "available", collisionReadStatus: "available" }, "may be incomplete"],
    [awareness, "Some related-work information is incomplete or unavailable."],
  ];
  for (const [value, expected] of variants) {
    const markup = renderToStaticMarkup(createElement(RelatedAwarenessNotice, { awareness: value }));
    expect(markup).toContain(expected);
  }
});


test("smart session does not order absent factual revisions or timestamps", () => {
  const first = smartSessionSnapshot({ factualRevision: 4 });
  const candidates: SmartSessionSnapshot[] = [
    { ...first, revision: { ...first.revision, factualRevision: undefined } },
    { ...first, revision: { ...first.revision, latestSemanticInferenceCreatedAt: undefined } },
    { ...first, revision: { ...first.revision, schemaVersion: 2 } },
  ];
  const initial = reduceSmartSession(initialSmartSessionState(), { type: "refreshSucceeded", requestId: 1,
    result: { schemaVersion: 1, status: "available", snapshot: first } });
  for (const candidate of candidates) {
    const result = reduceSmartSession(initial, { type: "refreshSucceeded", requestId: 2,
      result: { schemaVersion: 1, status: "available", snapshot: candidate } });
    expect(result.status).toBe("failed");
    expect(result.snapshot).toEqual(first);
    const reverseInitial = reduceSmartSession(initialSmartSessionState(), { type: "refreshSucceeded", requestId: 1,
      result: { schemaVersion: 1, status: "available", snapshot: candidate } });
    const reverse = reduceSmartSession(reverseInitial, { type: "refreshSucceeded", requestId: 2,
      result: { schemaVersion: 1, status: "available", snapshot: first } });
    expect(reverse.status).toBe("failed");
    expect(reverse.snapshot).toEqual(candidate);
  }
});


test("semantic report availability is visible without hiding factual data", () => {
  expect(renderToStaticMarkup(createElement(SemanticReportsNotice, { status: "unavailable" }))).toContain("Additional session reports are unavailable or unknown.");
  expect(renderToStaticMarkup(createElement(SemanticReportsNotice, {}))).toContain("Additional session reports are unavailable or unknown.");
  expect(renderToStaticMarkup(createElement(SemanticReportsNotice, { status: "available" }))).toContain("Additional session reports may be incomplete.");
});


test("stale smart session offers an actionable refresh", async () => {
  const dom = new JSDOM("<!doctype html><html><body><div id='root'></div></body></html>");
  const previousWindow = Object.getOwnPropertyDescriptor(globalThis, "window");
  const previousDocument = Object.getOwnPropertyDescriptor(globalThis, "document");
  const previousAct = Object.getOwnPropertyDescriptor(globalThis, "IS_REACT_ACT_ENVIRONMENT");
  Object.defineProperty(globalThis, "window", { configurable: true, value: dom.window });
  Object.defineProperty(globalThis, "document", { configurable: true, value: dom.window.document });
  Object.defineProperty(globalThis, "IS_REACT_ACT_ENVIRONMENT", { configurable: true, value: true });
  const element = dom.window.document.getElementById("root");
  if (!element) throw new Error("Missing test root");
  const root = createRoot(element);
  const state = reduceSmartSession(initialSmartSessionState(), { type: "refreshSucceeded", requestId: 1,
    result: { schemaVersion: 1, status: "failed", snapshot: smartSessionSnapshot({ factualRevision: 4 }) } });
  const calls: string[] = [];
  try {
    await act(async () => root.render(createElement(SmartSessionFreshnessBanner, { state, onRefresh: () => calls.push("refresh") })));
    expect(element.textContent).toContain("Could not refresh. Showing last known session data.");
    const button = element.querySelector("button");
    expect(button?.textContent).toBe("Refresh");
    await act(async () => button?.click());
    expect(calls).toEqual(["refresh"]);
  } finally {
    await act(async () => root.unmount());
    if (previousWindow) Object.defineProperty(globalThis, "window", previousWindow); else Reflect.deleteProperty(globalThis, "window");
    if (previousDocument) Object.defineProperty(globalThis, "document", previousDocument); else Reflect.deleteProperty(globalThis, "document");
    if (previousAct) Object.defineProperty(globalThis, "IS_REACT_ACT_ENVIRONMENT", previousAct); else Reflect.deleteProperty(globalThis, "IS_REACT_ACT_ENVIRONMENT");
    dom.window.close();
  }
});

test.each(["in_progress", "completed", "missing"])("smart session describes latest turn: %s", async (status) => {
  const catalog: unknown = await Bun.file("Resources/Localizable.xcstrings").json();
  function field(value: unknown, key: string): unknown {
    if (typeof value !== "object" || value === null || !(key in value)) throw new Error(`Missing catalog field ${key}`);
    return Reflect.get(value, key);
  }
  function english(key: string): string {
    const strings = field(catalog, "strings");
    const localizations = field(field(strings, key), "localizations");
    const value = field(field(field(localizations, "en"), "stringUnit"), "value");
    if (typeof value !== "string") throw new Error(`Missing English copy for ${key}`);
    return value;
  }
  const localizedContext: AppContext = { ...context, copy: { ...context.copy,
    smartSessionCurrentTurn: english("agentSession.web.smartSession.currentTurn"),
    smartSessionNoCurrentTurn: english("agentSession.web.smartSession.noCurrentTurn"),
  } };
    const dom = new JSDOM("<!doctype html><div id='root'></div>", { url: "https://example.test" });
    const previousWindow = Object.getOwnPropertyDescriptor(globalThis, "window");
    const previousDocument = Object.getOwnPropertyDescriptor(globalThis, "document");
    const previousAct = Object.getOwnPropertyDescriptor(globalThis, "IS_REACT_ACT_ENVIRONMENT");
    Object.defineProperty(globalThis, "window", { configurable: true, value: dom.window });
    Object.defineProperty(globalThis, "document", { configurable: true, value: dom.window.document });
    Object.defineProperty(globalThis, "IS_REACT_ACT_ENVIRONMENT", { configurable: true, value: true });
    const original = smartSessionSnapshot({ factualRevision: 1 });
    const turn = original.factual.latestTurn;
    if (!turn) throw new Error("Expected current turn in fixture");
    const snapshot: SmartSessionSnapshot = { ...original, factual: { ...original.factual,
      latestTurn: status === "missing" ? undefined : { ...turn, status },
    } };
    Object.assign(dom.window, { webkit: { messageHandlers: { agentSession: {
      postMessage: async () => ({ ok: true, value: { schemaVersion: 1, status: "available", snapshot } }),
    } } } });
    const container = dom.window.document.getElementById("root");
    if (!container) throw new Error("Missing root");
    const root = createRoot(container);
    try {
      await act(async () => { root.render(createElement(SmartSessionSurface, { context: localizedContext })); });
      if (status === "missing") {
        expect(container.textContent).toContain("Latest turn unavailable.");
        expect(container.textContent).not.toContain("latest supported outcome appears below");
      } else {
        expect(dom.window.document.querySelector(".focus-current-card .focus-card-kicker")?.textContent).toContain("Latest turn");
        expect(dom.window.document.querySelector(".focus-turn-status")?.textContent).toBe(status);
      }
    } finally {
      await act(async () => root.unmount());
      if (previousWindow) Object.defineProperty(globalThis, "window", previousWindow); else Reflect.deleteProperty(globalThis, "window");
      if (previousDocument) Object.defineProperty(globalThis, "document", previousDocument); else Reflect.deleteProperty(globalThis, "document");
      if (previousAct) Object.defineProperty(globalThis, "IS_REACT_ACT_ENVIRONMENT", previousAct); else Reflect.deleteProperty(globalThis, "IS_REACT_ACT_ENVIRONMENT");
      dom.window.close();
    }
});

// The producer assertion in FirstSemanticSessionInferenceTests.swift:96 yields
// this synthetic text from a completed command. This is not producer execution.
test.each(["active", "completed", "missing", "file-only", "provider-description", "no-prompt"]) ("recorded evidence excludes inferred current activity for %s", async (scenario) => {
  const dom = new JSDOM("<!doctype html><div id='root'></div>", { url: "https://example.test" });
  const previousWindow = Object.getOwnPropertyDescriptor(globalThis, "window");
  const previousDocument = Object.getOwnPropertyDescriptor(globalThis, "document");
  const previousAct = Object.getOwnPropertyDescriptor(globalThis, "IS_REACT_ACT_ENVIRONMENT");
  Object.defineProperty(globalThis, "window", { configurable: true, value: dom.window });
  Object.defineProperty(globalThis, "document", { configurable: true, value: dom.window.document });
  Object.defineProperty(globalThis, "IS_REACT_ACT_ENVIRONMENT", { configurable: true, value: true });
  const original = smartSessionSnapshot({ factualRevision: 1, currentActivity: "Validating with swift test", threadIntent: "Original assignment", prompt: "Change direction to the follow-up", knownSemantics: !["file-only", "provider-description"].includes(scenario) });
  const turn = original.factual.latestTurn;
  if (!turn) throw new Error("Expected turn fixture");
  const snapshot: SmartSessionSnapshot = { ...original, factual: { ...original.factual, priorTurns: [{ turnId: "prior", provider: "codex", providerTurnId: "prior-turn", status: "completed", updatedAt: "2026-08-17T07:00:00Z" }], latestTurn: {
    ...turn, prompt: scenario === "no-prompt" ? undefined : turn.prompt, status: scenario === "active" ? "running" : "completed",
    completedCommands: ["active", "completed"].includes(scenario) ? [{ commandId: "cmd", command: "swift test", status: "completed", completedAt: "2026-08-17T07:01:00Z", source: "observed", confidence: "high" }] : [],
    fileChangeAttributions: ["file-only", "provider-description"].includes(scenario) ? [{ attributionId: "file", paths: ["Sources/main.swift"], summary: scenario === "file-only" ? "Applied patch" : "Requested changes to configuration", observedAt: "2026-08-17T07:02:00Z", source: "observed", confidence: "high" }] : [],
  } } };
  Object.assign(dom.window, { webkit: { messageHandlers: { agentSession: {
    postMessage: async () => ({ ok: true, value: { schemaVersion: 1, status: "available", snapshot } }),
  } } } });
  const container = dom.window.document.getElementById("root");
  if (!container) throw new Error("Missing root");
  const root = createRoot(container);
  try {
    await act(async () => { root.render(createElement(SmartSessionSurface, { context })); });
    const promptBlock = container.querySelectorAll(".focus-current-grid .focus-summary-block")[0];
    expect(promptBlock?.querySelector("h3")?.textContent).toBe("Latest turn prompt");
    expect(promptBlock?.querySelector("p")?.textContent).toBe(scenario === "no-prompt" ? "Unknown" : "Change direction to the follow-up");
    expect(container.textContent).not.toContain("Original assignment");
    const historyToggle = container.querySelector<HTMLButtonElement>(".focus-history-toggle");
    expect(historyToggle).not.toBeNull();
    await act(async () => historyToggle?.click());
    expect(historyToggle?.getAttribute("aria-expanded")).toBe("true");
    expect(container.querySelector(".focus-history-details button")).toBeNull();
    const block = container.querySelectorAll(".focus-current-grid .focus-summary-block")[1];
    expect(container.textContent).not.toContain("Validating with swift test");
    const description = scenario === "file-only" ? "Applied patch" : "Requested changes to configuration";
    if (["file-only", "provider-description"].includes(scenario)) {
      const items = [...container.querySelectorAll(".focus-results li")].map(item => item.textContent);
      expect(items).toContain("Sources/main.swift");
      expect(items).toContain(`Recorded description (unverified): ${description}`);
      expect(container.querySelector(".focus-current-actions button")).toBeNull();
    }
    expect(block?.querySelector("h3")?.textContent).toBe("Recorded evidence");
    expect(block?.querySelector("p")?.textContent).toBe(["file-only", "provider-description"].includes(scenario) ? "Sources/main.swift" : ["missing", "no-prompt"].includes(scenario) ? "Unknown" : "swift test · completed");
  } finally {
    await act(async () => root.unmount());
    if (previousWindow) Object.defineProperty(globalThis, "window", previousWindow); else Reflect.deleteProperty(globalThis, "window");
    if (previousDocument) Object.defineProperty(globalThis, "document", previousDocument); else Reflect.deleteProperty(globalThis, "document");
    if (previousAct) Object.defineProperty(globalThis, "IS_REACT_ACT_ENVIRONMENT", previousAct); else Reflect.deleteProperty(globalThis, "IS_REACT_ACT_ENVIRONMENT");
    dom.window.close();
  }
});

test("loaded evidence is selectable and available through a disclosure", async () => {
  const dom = new JSDOM("<!doctype html><div id='root'></div>", { url: "https://example.test" });
  const previousWindow = globalThis.window;
  const previousDocument = globalThis.document;
  Object.assign(globalThis, { window: dom.window, document: dom.window.document, IS_REACT_ACT_ENVIRONMENT: true });
  const original = smartSessionSnapshot({ factualRevision: 1 });
  const turn = original.factual.latestTurn;
  if (!turn) throw new Error("Expected turn");
  const commands = Array.from({ length: 100 }, (_, i) => ({ commandId: `cmd-${i}`, command: `command-${i}`, status: "completed", completedAt: "2026-08-17T07:01:00Z", source: "observed", confidence: "high" }));
  const files = Array.from({ length: 100 }, (_, i) => ({ attributionId: `file-${i}`, paths: [`file-${i}`], summary: `patch-${i}`, observedAt: "2026-08-17T07:02:00Z", source: "observed", confidence: "high" }));
  const messages = Array.from({ length: 12 }, (_, i) => ({ messageId: `message-${i}`, text: `message-${i}`, completedAt: "2026-08-17T07:03:00Z", source: "observed", confidence: "high" }));
  const snapshot: SmartSessionSnapshot = { ...original, factual: { ...original.factual, latestTurn: { ...turn, completedCommands: commands, fileChangeAttributions: files, assistantMessages: messages } }, crossSessionAwareness: { ...original.crossSessionAwareness, relatedSessions: [{ sessionId: "related", lifecycleState: "unknown", completionState: "unknown", freshnessState: "unknown", relationshipReasons: ["Shared file"] }] } };
  Object.assign(dom.window, { webkit: { messageHandlers: { agentSession: { postMessage: async () => ({ ok: true, value: { schemaVersion: 1, status: "available", snapshot } }) } } } });
  const container = dom.window.document.getElementById("root");
  if (!container) throw new Error("Missing root");
  const root = createRoot(container);
  try {
    await act(async () => root.render(createElement(SmartSessionSurface, { context })));
    const disclosure = container.querySelector<HTMLButtonElement>(".focus-evidence-disclosure");
    expect(disclosure?.textContent).toBe("Show more recorded evidence");
    expect(disclosure?.getAttribute("aria-expanded")).toBe("false");
    expect(Boolean(container.querySelector(".focus-connected-dot"))).toBe(false);
    expect(container.querySelector(".focus-header-status")?.textContent).toContain("Last reported status:");
    expect(container.querySelector(".focus-related-strip")?.tagName).not.toBe("BUTTON");
    expect(container.querySelectorAll(".focus-evidence-page li").length).toBe(0);
    await act(async () => disclosure?.click());
    expect(disclosure?.getAttribute("aria-expanded")).toBe("true");
    expect(container.querySelector(".focus-evidence-page [role=status]")?.textContent).toBe("Page 1 of 21");
    expect(container.querySelectorAll(".focus-evidence-page li").length).toBeLessThanOrEqual(20);
    expect(container.querySelector(".focus-evidence-page")?.textContent).toContain("command-3");
    const item = container.querySelector(".focus-evidence-page li");
    if (!item?.firstChild) throw new Error("Missing evidence text");
    const range = dom.window.document.createRange();
    range.selectNodeContents(item);
    const selection = dom.window.getSelection();
    selection?.removeAllRanges();
    selection?.addRange(range);
    expect(selection?.toString()).toBe(item.textContent);
    const visited: string[] = [];
    for (const _unused of Array.from({ length: 21 })) {
      expect(container.querySelectorAll(".focus-evidence-page li").length).toBeLessThanOrEqual(20);
      visited.push(container.querySelector(".focus-evidence-page")?.textContent ?? "");
      const next = container.querySelector<HTMLButtonElement>(".focus-evidence-next");
      if (!next || next.getAttribute("aria-disabled") === "true") break;
      await act(async () => next.click());
    }
    expect(visited.join(" ")).toContain("command-99");
    expect(visited.join(" ")).toContain("file-99");
    expect(visited.join(" ")).toContain("Recorded description (unverified): patch-99");
    expect(visited.join(" ")).toContain("message-10");
    const previous = container.querySelector<HTMLButtonElement>(".focus-evidence-previous");
    expect(previous?.getAttribute("aria-disabled")).toBe("false");
    const nextAtEnd = container.querySelector<HTMLButtonElement>(".focus-evidence-next");
    nextAtEnd?.focus();
    expect(nextAtEnd?.getAttribute("aria-disabled")).toBe("true");
    expect(dom.window.document.activeElement).toBe(nextAtEnd);
    await act(async () => previous?.click());
    expect(container.querySelector(".focus-evidence-page")?.textContent).not.toContain("message-10");
    await act(async () => disclosure?.click());
    expect(disclosure?.getAttribute("aria-expanded")).toBe("false");
    expect(container.querySelectorAll(".focus-evidence-page li").length).toBe(0);
    const learnings = [...container.querySelectorAll<HTMLButtonElement>("[role=tab]")].find(button => button.textContent === "Learnings");
    await act(async () => learnings?.click());
    expect(container.querySelector(".focus-learnings button")).toBeNull();
  } finally {
    await act(async () => root.unmount());
    dom.window.close();
    Object.assign(globalThis, { window: previousWindow, document: previousDocument, IS_REACT_ACT_ENVIRONMENT: false });
  }
});


test.each(["loading", "missingSession", "failed"])("unavailable read %s is not presented as reported session status", async (kind) => {
  const dom = new JSDOM("<!doctype html><div id='root'></div>", { url: "https://example.test" });
  const previousWindow = globalThis.window;
  const previousDocument = globalThis.document;
  Object.assign(globalThis, { window: dom.window, document: dom.window.document, IS_REACT_ACT_ENVIRONMENT: true });
  const response = kind === "loading" ? new Promise(() => {}) : Promise.resolve({ ok: true, value: { schemaVersion: 1, status: kind } });
  Object.assign(dom.window, { webkit: { messageHandlers: { agentSession: { postMessage: () => response } } } });
  const container = dom.window.document.getElementById("root");
  if (!container) throw new Error("Missing root");
  const root = createRoot(container);
  try {
    await act(async () => root.render(createElement(SmartSessionSurface, { context })));
    expect(container.querySelector(".focus-header-status")?.textContent).not.toContain("Last reported status");
    expect(container.querySelector(".focus-card-status")?.textContent).not.toContain("Last reported status");
    expect(container.textContent).not.toContain("Verified workspace identity");
    if (kind === "loading") expect(container.querySelector(".focus-empty-state")?.textContent).toContain("Loading");
  } finally {
    await act(async () => root.unmount());
    dom.window.close();
    Object.assign(globalThis, { window: previousWindow, document: previousDocument, IS_REACT_ACT_ENVIRONMENT: false });
  }
});
