export type TelemetrySchema = "bmux.execution-event.v1";

export type TelemetryJsonPrimitive = string | number | boolean | null;
export type TelemetryJsonValue =
  | TelemetryJsonPrimitive
  | TelemetryJsonValue[]
  | { [key: string]: TelemetryJsonValue };
export type TelemetryMetadataValue =
  | TelemetryJsonPrimitive
  | TelemetryJsonPrimitive[];

export type TelemetrySource =
  | "provider"
  | "sidecar"
  | "git-observer"
  | "native-hook";

export type TelemetryProviderId = string;
export type TelemetryProviderEventMethod = string;
export type TelemetryProviderItemId = string;
export type TelemetryProviderTurnId = string;
export type TelemetryProviderSessionId = string;
export type TelemetrySessionId = string;
export type TelemetryEventId = string;

export interface TelemetryProviderEventRef {
  method?: TelemetryProviderEventMethod;
  requestId?: string | number;
  itemId?: TelemetryProviderItemId;
  turnId?: TelemetryProviderTurnId;
  sequence?: string | number;
}

export interface TelemetryEventEnvelope {
  schema: TelemetrySchema;
  eventId: TelemetryEventId;
  sessionId: TelemetrySessionId;
  sequence: number;
  capturedAtMs: number;
  source: TelemetrySource;
  provider: TelemetryProviderId;
  providerSessionId?: TelemetryProviderSessionId;
  providerTurnId?: TelemetryProviderTurnId;
  providerEvent?: TelemetryProviderEventRef;
  event: TelemetryEvent;
  metadata?: Record<string, TelemetryMetadataValue>;
}

export type TelemetrySidecarAssignedEnvelopeField =
  | "schema"
  | "eventId"
  | "sessionId"
  | "sequence"
  | "capturedAtMs"
  | "provider";

export type TelemetryEventEnvelopeDraft =
  Omit<TelemetryEventEnvelope, TelemetrySidecarAssignedEnvelopeField>
  & Partial<Pick<TelemetryEventEnvelope, TelemetrySidecarAssignedEnvelopeField>>;

export type TelemetryEnvelopeSubscriber = (envelope: TelemetryEventEnvelope) => void;

export interface TelemetryPublishProjectionOptions {
  doneGeneration?: number;
  doneStats?: string;
  providerLinkedModel?: string;
  skipAgentEventProjection?: boolean;
}

export type TelemetryOptionValue = string | boolean;

export type TelemetryEvent =
  | TelemetrySessionStarted
  | TelemetryProviderSessionLinked
  | TelemetryPromptSubmitted
  | TelemetryTurnStarted
  | TelemetryTurnCompleted
  | TelemetryTurnFailed
  | TelemetryPlanUpdated
  | TelemetryMessageDelta
  | TelemetryMessageCompleted
  | TelemetryToolStarted
  | TelemetryToolCompleted
  | TelemetryApprovalRequested
  | TelemetryApprovalResolved
  | TelemetryUsageUpdated
  | TelemetryFilesChanged
  | TelemetryContextCompacted
  | TelemetryDiagnostic;

export interface TelemetrySessionStarted {
  type: "session.started";
  cwd: string;
  title?: string;
  startOptions?: Record<string, TelemetryOptionValue>;
}

export interface TelemetryProviderSessionLinked {
  type: "session.provider-linked";
  providerSessionId: TelemetryProviderSessionId;
}

export interface TelemetryPromptSubmitted {
  type: "prompt.submitted";
  text: string;
}

export interface TelemetryTurnStarted {
  type: "turn.started";
  turnId?: TelemetryProviderTurnId;
  model?: string;
  effort?: string;
}

export interface TelemetryTurnCompleted {
  type: "turn.completed";
  turnId?: TelemetryProviderTurnId;
  durationMs?: number;
  usage?: TelemetryTokenUsage;
}

export interface TelemetryTurnFailed {
  type: "turn.failed";
  turnId?: TelemetryProviderTurnId;
  durationMs?: number;
  error: TelemetryErrorInfo;
}

export interface TelemetryPlanStep {
  text: string;
  status: string;
}

export interface TelemetryPlanUpdated {
  type: "plan.updated";
  explanation?: string;
  steps: TelemetryPlanStep[];
}

export type TelemetryMessageStream = "assistant" | "reasoning";

export interface TelemetryMessageDelta {
  type: "message.delta";
  stream: TelemetryMessageStream;
  itemId?: TelemetryProviderItemId;
  text: string;
  index?: number;
}

export interface TelemetryMessageCompleted {
  type: "message.completed";
  stream: TelemetryMessageStream;
  itemId?: TelemetryProviderItemId;
  text?: string;
}

export type TelemetryToolKind =
  | "command"
  | "file-change"
  | "web-search"
  | "mcp"
  | "subagent"
  | "other";

export interface TelemetryToolStarted {
  type: "tool.started";
  operationId: string;
  toolKind: TelemetryToolKind;
  name: string;
  inputSummary?: string;
  cwd?: string;
  startedAtMs?: number;
}

export type TelemetryToolStatus =
  | "succeeded"
  | "failed"
  | "cancelled"
  | "denied"
  | "unknown";

export interface TelemetryToolCompleted {
  type: "tool.completed";
  operationId: string;
  toolKind?: TelemetryToolKind;
  name?: string;
  status: TelemetryToolStatus;
  outputSummary?: string;
  error?: TelemetryErrorInfo;
  exitCode?: number;
  durationMs?: number;
  completedAtMs?: number;
}

export type TelemetryApprovalKind =
  | "command"
  | "file-change"
  | "provider"
  | "other";

export interface TelemetryApprovalRequested {
  type: "approval.requested";
  approvalId: string;
  approvalKind: TelemetryApprovalKind;
  operationId?: string;
  summary?: string;
  requestedAtMs?: number;
}

export type TelemetryApprovalDecision =
  | "approved"
  | "denied"
  | "declined"
  | "unsupported"
  | "expired";

export interface TelemetryApprovalResolved {
  type: "approval.resolved";
  approvalId: string;
  decision: TelemetryApprovalDecision;
  reason?: string;
  respondedAtMs?: number;
}

export interface TelemetryUsageUpdated {
  type: "usage.updated";
  turnId?: TelemetryProviderTurnId;
  usage: TelemetryTokenUsage;
}

export interface TelemetryTokenUsage {
  inputTokens?: number;
  cachedInputTokens?: number;
  outputTokens?: number;
  reasoningOutputTokens?: number;
  totalTokens?: number;
  contextWindowTokens?: number;
  model?: string;
}

export type TelemetryFileChangeSource = "provider" | "git-observer";

export interface TelemetryFilesChanged {
  type: "files.changed";
  source: TelemetryFileChangeSource;
  files: TelemetryChangedFile[];
}

export interface TelemetryChangedFile {
  path: string;
  status: string;
  additions?: number;
  deletions?: number;
  summary?: string;
}

export interface TelemetryContextCompacted {
  type: "context.compacted";
  turnId?: TelemetryProviderTurnId;
  inputTokens?: number;
  outputTokens?: number;
}

export type TelemetryDiagnosticLevel = "info" | "warning" | "error";

export interface TelemetryDiagnostic {
  type: "diagnostic";
  level: TelemetryDiagnosticLevel;
  message: string;
  code?: string;
}

export interface TelemetryErrorInfo {
  message: string;
  code?: string;
  retryable?: boolean;
}
