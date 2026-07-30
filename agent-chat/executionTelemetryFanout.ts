import type { AgentEvent, ChangedFile } from "./types";
import type {
  TelemetryChangedFile,
  TelemetryEventEnvelope,
  TelemetryEventEnvelopeDraft,
  TelemetryEnvelopeSubscriber,
  TelemetryProviderId,
  TelemetryPublishProjectionOptions,
  TelemetrySessionId,
  TelemetryToolStatus,
  TelemetryTokenUsage,
} from "./executionTelemetryTypes";

export type AgentEventEmitter = (event: AgentEvent) => void;

export interface ExecutionTelemetryFanoutOptions {
  sessionId: TelemetrySessionId;
  provider: TelemetryProviderId;
  emitAgentEvent: AgentEventEmitter;
  nowMs?: () => number;
  idFactory?: (context: { sessionId: TelemetrySessionId; sequence: number }) => string;
}

export class ExecutionTelemetryFanout {
  private nextSequence = 1;
  private readonly subscribers = new Set<TelemetryEnvelopeSubscriber>();
  private readonly sessionId: TelemetrySessionId;
  private readonly provider: TelemetryProviderId;
  private readonly emitAgentEvent: AgentEventEmitter;
  private readonly nowMs: () => number;
  private readonly idFactory: (context: { sessionId: TelemetrySessionId; sequence: number }) => string;

  constructor(options: ExecutionTelemetryFanoutOptions) {
    this.sessionId = options.sessionId;
    this.provider = options.provider;
    this.emitAgentEvent = options.emitAgentEvent;
    this.nowMs = options.nowMs ?? (() => Date.now());
    this.idFactory = options.idFactory ?? (() => defaultEventId());
  }

  subscribe(subscriber: TelemetryEnvelopeSubscriber): () => void {
    this.subscribers.add(subscriber);
    return () => {
      this.subscribers.delete(subscriber);
    };
  }

  publish(draft: TelemetryEventEnvelopeDraft, projection?: TelemetryPublishProjectionOptions): TelemetryEventEnvelope {
    const envelope = this.assignEnvelope(draft);
    for (const subscriber of this.subscribers) subscriber(envelope);
    for (const event of projectTelemetryEnvelopeToAgentEvents(envelope, projection)) this.emitAgentEvent(event);
    return envelope;
  }

  private assignEnvelope(draft: TelemetryEventEnvelopeDraft): TelemetryEventEnvelope {
    const sequence = this.nextSequence++;
    const envelope: TelemetryEventEnvelope = {
      schema: "bmux.execution-event.v1",
      eventId: this.idFactory({ sessionId: this.sessionId, sequence }),
      sessionId: this.sessionId,
      sequence,
      capturedAtMs: this.nowMs(),
      source: draft.source,
      provider: this.provider,
      event: draft.event,
    };
    if (draft.providerSessionId !== undefined) envelope.providerSessionId = draft.providerSessionId;
    if (draft.providerTurnId !== undefined) envelope.providerTurnId = draft.providerTurnId;
    if (draft.providerEvent !== undefined) envelope.providerEvent = draft.providerEvent;
    if (draft.metadata !== undefined) envelope.metadata = draft.metadata;
    return envelope;
  }
}

export function projectTelemetryEnvelopeToAgentEvents(
  envelope: TelemetryEventEnvelope,
  projection?: TelemetryPublishProjectionOptions,
): AgentEvent[] {
  const event = envelope.event;
  switch (event.type) {
    case "session.started":
      return [];
    case "session.provider-linked":
      return [{ kind: "meta", model: projection?.providerLinkedModel, providerSessionId: event.providerSessionId }];
    case "prompt.submitted":
      return [{ kind: "user", text: event.text }];
    case "turn.started":
      return [];
    case "turn.completed":
      return [withDoneGeneration({ kind: "done", stats: projection?.doneStats ?? formatUsageStats(event.usage, event.durationMs) ?? "" }, projection)];
    case "turn.failed":
      return [
        { kind: "error", message: event.error.message },
        withDoneGeneration({ kind: "done", stats: projection?.doneStats }, projection),
      ];
    case "message.delta":
      return [{ kind: event.stream === "reasoning" ? "thinking" : "delta", text: event.text }];
    case "message.completed":
      if (!event.text) return [];
      return [{ kind: event.stream === "reasoning" ? "thinking" : "assistant", text: event.text }];
    case "tool.started":
      return [{ kind: "tool-start", toolId: event.operationId, name: event.name, detail: event.inputSummary }];
    case "tool.completed":
      return [{
        kind: "tool-end",
        toolId: event.operationId,
        name: event.name,
        ok: toolStatusOk(event.status),
        detail: event.outputSummary ?? event.error?.message,
      }];
    case "approval.requested":
    case "approval.resolved":
    case "usage.updated":
    case "context.compacted":
      return [];
    case "files.changed":
      return [{ kind: "files-changed", files: event.files.map(projectChangedFile) }];
    case "diagnostic":
      return event.level === "error"
        ? [{ kind: "error", message: event.message }]
        : [{ kind: "status", text: event.message }];
  }
}

function withDoneGeneration(
  event: Extract<AgentEvent, { kind: "done" }>,
  projection: TelemetryPublishProjectionOptions | undefined,
): Extract<AgentEvent, { kind: "done" }> {
  if (projection?.doneGeneration === undefined) return event;
  return { ...event, generation: projection.doneGeneration } as Extract<AgentEvent, { kind: "done" }>;
}

function defaultEventId(): string {
  return globalThis.crypto?.randomUUID?.() ?? `${Date.now()}-${Math.random().toString(36).slice(2)}`;
}

function projectChangedFile(file: TelemetryChangedFile): ChangedFile {
  return {
    path: file.path,
    status: file.status,
    adds: file.additions ?? 0,
    dels: file.deletions ?? 0,
  };
}

function toolStatusOk(status: TelemetryToolStatus): boolean {
  return status === "succeeded";
}

function formatUsageStats(usage: TelemetryTokenUsage | undefined, durationMs: number | undefined): string | undefined {
  const stats = [
    usage ? `${usage.inputTokens ?? 0} in · ${usage.outputTokens ?? 0} out` : null,
    formatDuration(durationMs),
  ].filter(Boolean).join(" · ");
  return stats || undefined;
}

function formatDuration(durationMs: number | undefined): string | undefined {
  return durationMs === undefined ? undefined : `${(durationMs / 1000).toFixed(1)}s`;
}
