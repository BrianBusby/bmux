export type ProviderId = "codex" | "claude" | "opencode";

export type RendererKind = "react" | "solid";

export type ComposerPermissionMode = "default" | "auto-review" | "full-access" | "custom";

export type ProviderInfo = {
  id: ProviderId;
  displayName: string;
  executableName: string;
  transportKind: "stdio-jsonrpc" | "stdio-jsonl" | "http-loopback";
  arguments: string[];
  autoStart: boolean;
};

export type AgentSessionTheme = {
  isDark: boolean;
  pageBackground: string;
  surfaceBackground: string;
  surfaceElevatedBackground: string;
  inputBackground: string;
  border: string;
  borderStrong: string;
  text: string;
  mutedText: string;
  softText: string;
  accent: string;
  accentSoft: string;
  danger: string;
  shadow: string;
};

export type AppContext = {
  panelId: string;
  workspaceId: string;
  stableWorkspaceId?: string;
  renderer: RendererKind;
  initialProviderId: ProviderId;
  workingDirectory?: string;
  rateLimitRows?: AgentSessionRateLimitRow[];
  copy: AgentSessionCopy;
  theme: AgentSessionTheme;
};

export type AgentSessionRateLimitRow = {
  role: "primary" | "secondary";
  remainingPercent: number;
  usedPercent?: number;
  windowDurationMins?: number;
  resetsAt?: number;
};

export type AgentSessionCopy = {
  start: string;
  stop: string;
  send: string;
  provider: string;
  rateLimits: string;
  rateLimitUsageRemaining: string;
  rateLimitPrimary: string;
  rateLimitSecondary: string;
  rateLimitWeekly: string;
  rateLimitMonthly: string;
  rateLimitDaysFormat: string;
  rateLimitHoursFormat: string;
  rateLimitMinutesFormat: string;
  rateLimitResets: string;
  voiceInput: string;
  promptPlaceholder: string;
  attachFile: string;
  addFilesAndMore: string;
  addPhotosAndFiles: string;
  removeAttachment: string;
  copyOutput: string;
  copyAssistantMessage: string;
  copiedAssistantMessage: string;
  copyUserMessage: string;
  copiedUserMessage: string;
  shellLabel: string;
  copyShellContents: string;
  copiedShellContents: string;
  collapseShell: string;
  showRawOutput: string;
  showOptimizedOutput: string;
  rawOutputUnavailable: string;
  shellSuccess: string;
  showMore: string;
  showLess: string;
  browseWeb: string;
  autoContext: string;
  includeIdeContext: string;
  ideContext: string;
  tools: string;
  changePermissions: string;
  permissionsDefault: string;
  permissionsFullAccess: string;
  permissionsAutoReview: string;
  permissionsCustom: string;
  reasoningEffortHigh: string;
  mentionMenuTitle: string;
  mentionCurrentWorkspace: string;
  skillMenuTitle: string;
  composerNoResults: string;
  planMode: string;
  planSuggestionAction: string;
  planSuggestionDismiss: string;
  planSuggestionShortcut: string;
  planSuggestionTitle: string;
  skillPlan: string;
  skillCodeReview: string;
  skillResearch: string;
  loadingStatus: string;
  idleStatus: string;
  startingStatus: string;
  runningStatus: string;
  stoppingStatus: string;
  failedStatus: string;
  rendererReadyFormat: string;
  stopped: string;
  sentCharsFormat: string;
  providerStarted: string;
  providerExitedFormat: string;
  requestFailed: string;
  terminalView: string;
  sessionView: string;
  smartSessionRefresh: string;
  smartSessionLoading: string;
  smartSessionNoSession: string;
  smartSessionUnavailable: string;
  smartSessionNotFound: string;
  smartSessionFailed: string;
  smartSessionUnknown: string;
  smartSessionIdentity: string;
  smartSessionPurpose: string;
  smartSessionCurrentTurn: string;
  smartSessionCurrentActivity: string;
  smartSessionPhase: string;
  smartSessionPrompt: string;
  smartSessionPlan: string;
  smartSessionEvidence: string;
  smartSessionCommands: string;
  smartSessionFiles: string;
  smartSessionReasoning: string;
  smartSessionFinalOutput: string;
  smartSessionPriorTurns: string;
  smartSessionNoPlan: string;
  smartSessionNoEvidence: string;
  smartSessionSessionID: string;
  smartSessionRevision: string;
  smartSessionThread: string;
  smartSessionTurn: string;
  smartSessionRelatedWork: string;
  smartSessionNoRelatedWork: string;
  smartSessionPossibleCollisions: string;
};

export type SmartSessionReadStatus =
  | "available"
  | "missingSession"
  | "unavailable"
  | "notFound"
  | "failed";

export type SmartSessionReadResult =
  | {
      schemaVersion: 1;
      status: "available";
      snapshot: SmartSessionSnapshot;
    }
  | {
      schemaVersion: 1;
      status: Exclude<SmartSessionReadStatus, "available">;
      sessionId?: string;
      reason?: string;
    };

export type SmartSessionSnapshot = {
  schemaVersion: 1;
  revision: SmartSessionRevision;
  identity: SmartSessionIdentity;
  workModel?: SmartSessionWorkModel;
  factual: SmartSessionFactual;
  semanticMessages: SmartSessionSemanticMessage[];
  crossSessionAwareness: {
    status: "available" | "unavailable";
    relatedSessions: Array<{
      sessionId: string;
      lifecycleState: string;
      completionState: string;
      relationshipReasons: string[];
      freshnessState: string;
    }>;
    collisions: Array<{
      id: string;
      path: string;
      state: string;
      participantSessionIds: string[];
    }>;
    relatedOmittedCount: number;
    collisionOmittedCount: number;
  };
};

export type SmartSessionRevision = {
  schemaVersion?: number;
  factualRevision?: number;
  semanticInferenceIds?: string[];
  latestSemanticInferenceCreatedAt?: string;
  modelRevisionKey?: string;
  semanticMessageCount: number;
  latestSemanticMessageCreatedAt?: string;
  key: string;
};

export type SmartSessionWorkModel = {
  schemaVersion: number;
  revision: SmartSessionWorkModelRevision;
  thread?: SmartSessionWorkModelThread;
  currentTurn?: SmartSessionWorkModelCurrentTurn;
  sessionPhase: SmartSessionSemanticField;
};

export type SmartSessionWorkModelRevision = {
  schemaVersion: number;
  factualRevision?: number;
  semanticInferenceIds: string[];
  latestSemanticInferenceCreatedAt?: string;
  modelRevisionKey: string;
};

export type SmartSessionWorkModelThread = {
  identity: SmartSessionProviderThread;
  intent: SmartSessionSemanticField;
};

export type SmartSessionWorkModelCurrentTurn = {
  turnId: string;
  threadId?: string;
  intent: SmartSessionSemanticField;
  currentActivity: SmartSessionSemanticField;
};

export type SmartSessionSemanticField = {
  kind: string;
  scope: "session" | "thread" | "turn";
  scopeId?: string;
  state: "known" | "unknown" | "unavailable";
  reason?: string;
  record?: SmartSessionSemanticRecord;
  summary?: string;
  detail?: string;
};

export type SmartSessionSemanticRecord = {
  inferenceId: string;
  schemaVersion: number;
  payload: unknown;
  supportingEvidenceRefs: SmartSessionSemanticEvidenceRef[];
  supportingFactualRevision?: number;
  confidence: string;
  specificity: string;
  producerType: string;
  producerId: string;
  producerVersion: string;
  createdAt: string;
  status: "active" | "superseded" | "invalidated";
  supersedes: string[];
  supersededBy?: string;
};

export type SmartSessionSemanticEvidenceRef = {
  kind: string;
  id: string;
  ledgerSequence?: number;
  factualRevision?: number;
};

export type SmartSessionIdentity = {
  sessionId: string;
  agentKind: string;
  workspaceId?: string;
  surfaceId?: string;
  worktreeId?: string;
  cwd?: string;
  status: string;
  startedAt?: string;
  updatedAt: string;
  providerThreads: SmartSessionProviderThread[];
};

export type SmartSessionProviderThread = {
  threadId: string;
  provider: string;
  providerThreadId: string;
  worktreeId?: string;
  source: string;
  confidence: string;
  firstObservedAt: string;
  updatedAt: string;
};

export type SmartSessionFactual = {
  latestTurn?: SmartSessionTurn;
  priorTurns: SmartSessionTurnReference[];
  turnCount: number;
};

export type SmartSessionTurn = {
  turnId: string;
  threadId?: string;
  provider: string;
  providerTurnId: string;
  status: string;
  model?: string;
  startedAt?: string;
  completedAt?: string;
  updatedAt: string;
  prompt?: SmartSessionPrompt;
  plan?: SmartSessionPlan;
  completedCommands: SmartSessionCommand[];
  visibleReasoningSummaries: SmartSessionReasoningSummary[];
  assistantMessages: SmartSessionAssistantMessage[];
  fileChangeAttributions: SmartSessionFileChangeAttribution[];
};

export type SmartSessionTurnReference = {
  turnId: string;
  threadId?: string;
  provider: string;
  providerTurnId: string;
  status: string;
  startedAt?: string;
  completedAt?: string;
  updatedAt: string;
};

export type SmartSessionPrompt = {
  promptId: string;
  text: string;
  submittedAt: string;
  source: string;
  confidence: string;
};

export type SmartSessionPlan = {
  planId: string;
  explanation?: string;
  observedAt: string;
  source: string;
  confidence: string;
  steps: SmartSessionPlanStep[];
};

export type SmartSessionPlanStep = {
  stepId: string;
  order: number;
  text: string;
  status: string;
};

export type SmartSessionCommand = {
  commandId: string;
  command: string;
  cwd?: string;
  status: string;
  exitCode?: number;
  outputSummary?: string;
  startedAt?: string;
  completedAt: string;
  source: string;
  confidence: string;
};

export type SmartSessionReasoningSummary = {
  summaryId: string;
  text: string;
  completedAt: string;
  source: string;
  confidence: string;
};

export type SmartSessionAssistantMessage = {
  messageId: string;
  text: string;
  completedAt: string;
  source: string;
  confidence: string;
};

export type SmartSessionFileChangeAttribution = {
  attributionId: string;
  paths: string[];
  summary?: string;
  observedAt: string;
  source: string;
  confidence: string;
};

export type SmartSessionSemanticMessage = {
  messageId: string;
  semanticInferenceId: string;
  semanticInferenceKind: string;
  scope: "session" | "thread" | "turn";
  scopeId: string;
  concisePhrase: string;
  expandedMeaning: string;
  supportingFactualRevision?: number;
  confidence: string;
  specificity: string;
  presentationProducerId: string;
  presentationProducerVersion: string;
  presentationPolicyId: string;
  presentationPolicyVersion: string;
  localeIdentifier?: string;
  createdAt: string;
  status: "active" | "superseded" | "invalidated";
};

export type TerminalOutputMetadata = {
  rawOutputRef?: string;
  rawByteCount: number;
  rawLineCount: number;
  wasOptimized: boolean;
};

export type AgentSessionAttachment = {
  dataUrl?: string;
  fsPath?: string;
  id: string;
  kind: "file" | "image";
  label: string;
  mimeType?: string;
  path: string;
};

export type AgentEvent =
  | {
      type: "app.theme";
      theme: AgentSessionTheme;
    }
  | {
      type: "app.rateLimitRows";
      rateLimitRows: AgentSessionRateLimitRow[];
    }
  | {
      type: "provider.started";
      sessionId: string;
      providerId: ProviderId;
      executablePath: string;
      arguments: string[];
    }
  | {
      type: "provider.output";
      sessionId: string;
      providerId: ProviderId;
      stream: "stdout" | "stderr";
      text: string;
    }
  | {
      type: "provider.activity";
      sessionId: string;
      providerId: ProviderId;
      activityId: string;
      kind: "command" | "fileChange" | "other";
      status: "inProgress" | "completed" | "failed" | "stopped";
      action: string;
      detail?: string;
      outputDelta?: string;
      outputMetadata?: TerminalOutputMetadata;
    }
  | {
      type: "provider.turnComplete";
      sessionId: string;
      providerId: ProviderId;
    }
  | {
      type: "provider.exit";
      sessionId: string;
      providerId: ProviderId;
      status: number;
    };
