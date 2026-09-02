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
    smartSessionCurrentTurn: "Current turn",
    smartSessionCurrentActivity: "Current activity",
    smartSessionPhase: "Phase",
    smartSessionPrompt: "Prompt",
    smartSessionPlan: "Plan",
    smartSessionEvidence: "Evidence",
    smartSessionCommands: "Commands",
    smartSessionFiles: "Files",
    smartSessionReasoning: "Reasoning",
    smartSessionFinalOutput: "Final output",
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
      schemaVersion: 1,
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
