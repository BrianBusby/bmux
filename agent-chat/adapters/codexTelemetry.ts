import type { SessionCtx } from "../types";
import type { TelemetryEventEnvelope, TelemetryProviderTurnId, TelemetryTokenUsage } from "../executionTelemetryTypes";
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
