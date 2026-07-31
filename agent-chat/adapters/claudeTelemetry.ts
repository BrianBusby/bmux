import type { SessionCtx } from "../types";
import type { TelemetryEventEnvelope } from "../executionTelemetryTypes";
import { truncate } from "./lines";

export function emitClaudePromptSubmitted(sess: SessionCtx, text: string): TelemetryEventEnvelope | undefined {
  return sess.emitTelemetry?.({
    source: "sidecar",
    event: {
      type: "prompt.submitted",
      text,
    },
  }) ?? (sess.emit({ kind: "user", text }), undefined);
}

export function emitClaudeProviderSessionLinked(
  sess: SessionCtx,
  params: {
    providerSessionId: string;
    model?: string;
  },
): TelemetryEventEnvelope | undefined {
  return sess.emitTelemetry?.({
    source: "provider",
    providerSessionId: params.providerSessionId,
    providerEvent: { method: "system/init" },
    event: {
      type: "session.provider-linked",
      providerSessionId: params.providerSessionId,
    },
  }, { providerLinkedModel: params.model }) ?? (
    sess.emit({ kind: "meta", model: params.model, providerSessionId: params.providerSessionId }),
    undefined
  );
}

export function emitClaudeTurnCompleted(
  sess: SessionCtx,
  params: {
    providerSessionId?: string;
    durationMs?: number;
    stats?: string;
    generation?: number;
  },
): TelemetryEventEnvelope | undefined {
  return sess.emitTelemetry?.({
    source: "provider",
    providerSessionId: params.providerSessionId,
    providerEvent: { method: "result" },
    event: {
      type: "turn.completed",
      durationMs: params.durationMs,
    },
  }, { doneGeneration: params.generation, doneStats: params.stats }) ?? (
    sess.emit({ kind: "done", stats: params.stats, generation: params.generation } as any),
    undefined
  );
}

export function emitClaudeTurnFailed(
  sess: SessionCtx,
  params: {
    providerSessionId?: string;
    message: string;
    code?: string;
    durationMs?: number;
    stats?: string;
    generation?: number;
    source?: "provider" | "sidecar";
    method?: string;
  },
): TelemetryEventEnvelope | undefined {
  const message = truncate(params.message, 400);
  return sess.emitTelemetry?.({
    source: params.source ?? "provider",
    providerSessionId: params.providerSessionId,
    providerEvent: params.method ? { method: params.method } : undefined,
    event: {
      type: "turn.failed",
      durationMs: params.durationMs,
      error: {
        message,
        code: params.code,
      },
    },
  }, { doneGeneration: params.generation, doneStats: params.stats }) ?? (
    sess.emit({ kind: "error", message }),
    sess.emit({ kind: "done", stats: params.stats, generation: params.generation } as any),
    undefined
  );
}
