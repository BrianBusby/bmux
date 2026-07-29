import type { SessionCtx } from "../types";
import type {
  TelemetryEventEnvelope,
  TelemetryMessageStream,
  TelemetryProviderTurnId,
  TelemetryToolKind,
  TelemetryToolStatus,
  TelemetryTokenUsage,
} from "../executionTelemetryTypes";
import { truncate } from "./lines";

export function emitCodexPromptSubmitted(sess: SessionCtx, text: string): TelemetryEventEnvelope | undefined {
  return sess.emitTelemetry?.({
    source: "sidecar",
    event: {
      type: "prompt.submitted",
      text,
    },
  }) ?? (sess.emit({ kind: "user", text }), undefined);
}

export function emitCodexProviderSessionLinked(
  sess: SessionCtx,
  providerSessionId: string,
  method: "thread/start" | "thread/fork",
): TelemetryEventEnvelope | undefined {
  return sess.emitTelemetry?.({
    source: "provider",
    providerSessionId,
    providerEvent: { method },
    event: {
      type: "session.provider-linked",
      providerSessionId,
    },
  }) ?? (sess.emit({ kind: "meta", providerSessionId }), undefined);
}

export function emitCodexTurnStarted(
  sess: SessionCtx,
  params: {
    providerSessionId?: string;
    turnId?: TelemetryProviderTurnId;
    model?: string;
    effort?: string;
  },
): TelemetryEventEnvelope | undefined {
  return sess.emitTelemetry?.({
    source: "provider",
    providerSessionId: params.providerSessionId,
    providerTurnId: params.turnId,
    providerEvent: {
      method: "turn/started",
      turnId: params.turnId,
    },
    event: {
      type: "turn.started",
      turnId: params.turnId,
      model: params.model || undefined,
      effort: params.effort || undefined,
    },
  });
}

export function emitCodexTurnCompleted(
  sess: SessionCtx,
  params: {
    providerSessionId?: string;
    turnId?: TelemetryProviderTurnId;
    durationMs?: number;
    usage?: unknown;
    generation?: number;
  },
): TelemetryEventEnvelope | undefined {
  const usage = codexTokenUsage(params.usage);
  const durationMs = finiteNumber(params.durationMs);
  return sess.emitTelemetry?.({
    source: "provider",
    providerSessionId: params.providerSessionId,
    providerTurnId: params.turnId,
    providerEvent: {
      method: "turn/completed",
      turnId: params.turnId,
    },
    event: {
      type: "turn.completed",
      turnId: params.turnId,
      durationMs,
      usage,
    },
  }, { doneGeneration: params.generation }) ?? (
    sess.emit({ kind: "done", stats: formatCodexDoneStats(usage, durationMs), generation: params.generation } as any),
    undefined
  );
}

export function emitCodexTurnFailed(
  sess: SessionCtx,
  params: {
    providerSessionId?: string;
    turnId?: TelemetryProviderTurnId;
    durationMs?: number;
    message?: string;
    code?: string;
    generation?: number;
  },
): TelemetryEventEnvelope | undefined {
  const message = truncate(params.message ?? "turn failed", 400);
  return sess.emitTelemetry?.({
    source: "provider",
    providerSessionId: params.providerSessionId,
    providerTurnId: params.turnId,
    providerEvent: {
      method: "turn/failed",
      turnId: params.turnId,
    },
    event: {
      type: "turn.failed",
      turnId: params.turnId,
      durationMs: finiteNumber(params.durationMs),
      error: {
        message,
        code: params.code,
      },
    },
  }, { doneGeneration: params.generation }) ?? (
    sess.emit({ kind: "error", message }),
    sess.emit({ kind: "done", generation: params.generation } as any),
    undefined
  );
}

export function emitCodexMessageDelta(
  sess: SessionCtx,
  params: {
    providerSessionId?: string;
    turnId?: TelemetryProviderTurnId;
    itemId?: string;
    method: string;
    stream: TelemetryMessageStream;
    text: string;
  },
): TelemetryEventEnvelope | undefined {
  return sess.emitTelemetry?.({
    source: "provider",
    providerSessionId: params.providerSessionId,
    providerTurnId: params.turnId,
    providerEvent: {
      method: params.method,
      itemId: params.itemId,
      turnId: params.turnId,
    },
    event: {
      type: "message.delta",
      stream: params.stream,
      itemId: params.itemId,
      text: params.text,
    },
  }) ?? (
    sess.emit({ kind: params.stream === "reasoning" ? "thinking" : "delta", text: params.text }),
    undefined
  );
}

export function emitCodexMessageCompleted(
  sess: SessionCtx,
  params: {
    providerSessionId?: string;
    turnId?: TelemetryProviderTurnId;
    itemId?: string;
    stream: TelemetryMessageStream;
    text?: string;
  },
): TelemetryEventEnvelope | undefined {
  return sess.emitTelemetry?.({
    source: "provider",
    providerSessionId: params.providerSessionId,
    providerTurnId: params.turnId,
    providerEvent: {
      method: "item/completed",
      itemId: params.itemId,
      turnId: params.turnId,
    },
    event: {
      type: "message.completed",
      stream: params.stream,
      itemId: params.itemId,
      text: params.text,
    },
  }) ?? (
    params.text ? sess.emit({ kind: params.stream === "reasoning" ? "thinking" : "assistant", text: params.text }) : undefined,
    undefined
  );
}

export function emitCodexToolStarted(
  sess: SessionCtx,
  params: {
    providerSessionId?: string;
    turnId?: TelemetryProviderTurnId;
    operationId: string;
    toolKind: TelemetryToolKind;
    name: string;
    inputSummary?: string;
    providerItemType?: string;
  },
): TelemetryEventEnvelope | undefined {
  return sess.emitTelemetry?.({
    source: "provider",
    providerSessionId: params.providerSessionId,
    providerTurnId: params.turnId,
    providerEvent: {
      method: "item/started",
      itemId: params.operationId,
      turnId: params.turnId,
    },
    metadata: params.providerItemType ? { providerItemType: params.providerItemType } : undefined,
    event: {
      type: "tool.started",
      operationId: params.operationId,
      toolKind: params.toolKind,
      name: params.name,
      inputSummary: params.inputSummary,
    },
  }) ?? (
    sess.emit({ kind: "tool-start", toolId: params.operationId, name: params.name, detail: params.inputSummary }),
    undefined
  );
}

export function emitCodexToolCompleted(
  sess: SessionCtx,
  params: {
    providerSessionId?: string;
    turnId?: TelemetryProviderTurnId;
    operationId: string;
    toolKind?: TelemetryToolKind;
    name?: string;
    status: TelemetryToolStatus;
    outputSummary?: string;
    exitCode?: number;
    durationMs?: number;
    providerItemType?: string;
    providerStatus?: string;
  },
): TelemetryEventEnvelope | undefined {
  return sess.emitTelemetry?.({
    source: "provider",
    providerSessionId: params.providerSessionId,
    providerTurnId: params.turnId,
    providerEvent: {
      method: "item/completed",
      itemId: params.operationId,
      turnId: params.turnId,
    },
    metadata: boundedMetadata({
      providerItemType: params.providerItemType,
      providerStatus: params.providerStatus,
    }),
    event: {
      type: "tool.completed",
      operationId: params.operationId,
      toolKind: params.toolKind,
      name: params.name,
      status: params.status,
      outputSummary: params.outputSummary,
      exitCode: finiteNumber(params.exitCode),
      durationMs: finiteNumber(params.durationMs),
    },
  }) ?? (
    sess.emit({
      kind: "tool-end",
      toolId: params.operationId,
      name: params.name,
      ok: params.status === "succeeded",
      detail: params.outputSummary,
    }),
    undefined
  );
}

export function codexTokenUsage(value: unknown): TelemetryTokenUsage | undefined {
  if (!value || typeof value !== "object") return undefined;
  const raw = value as Record<string, unknown>;
  const usage: TelemetryTokenUsage = {
    inputTokens: finiteNumber(raw.inputTokens),
    cachedInputTokens: finiteNumber(raw.cachedInputTokens),
    outputTokens: finiteNumber(raw.outputTokens),
    reasoningOutputTokens: finiteNumber(raw.reasoningOutputTokens),
    totalTokens: finiteNumber(raw.totalTokens),
    contextWindowTokens: finiteNumber(raw.contextWindowTokens ?? raw.modelContextWindow),
    model: typeof raw.model === "string" ? raw.model : undefined,
  };
  return Object.values(usage).some((entry) => entry !== undefined) ? usage : undefined;
}

function formatCodexDoneStats(usage: TelemetryTokenUsage | undefined, durationMs: number | undefined): string {
  const stats = [
    usage ? `${usage.inputTokens ?? 0} in · ${usage.outputTokens ?? 0} out` : null,
    durationMs !== undefined ? `${(durationMs / 1000).toFixed(1)}s` : null,
  ].filter(Boolean).join(" · ");
  return stats;
}

function finiteNumber(value: unknown): number | undefined {
  return typeof value === "number" && Number.isFinite(value) ? value : undefined;
}

function boundedMetadata(values: Record<string, string | undefined>): Record<string, string> | undefined {
  const entries = Object.entries(values).filter((entry): entry is [string, string] => typeof entry[1] === "string");
  return entries.length ? Object.fromEntries(entries) : undefined;
}
