import type { SessionCtx } from "../types";
import type { TelemetryEventEnvelope } from "../executionTelemetryTypes";
import { truncate } from "./lines";

export function claudeTurnID(generation: number | undefined): string | undefined {
  return generation === undefined ? undefined : `bmux-turn-${generation}`;
}

export function emitClaudePromptSubmitted(sess: SessionCtx, text: string, generation?: number): TelemetryEventEnvelope | undefined {
  const providerTurnId = claudeTurnID(generation);
  const prompt = sess.emitTelemetry?.({
    source: "sidecar",
    providerTurnId,
    event: {
      type: "prompt.submitted",
      text,
    },
  });
  if (!prompt) {
    sess.emit({ kind: "user", text });
    return undefined;
  }
  if (providerTurnId) sess.emitTelemetry?.({
    source: "sidecar",
    providerTurnId,
    event: { type: "turn.started", turnId: providerTurnId },
  });
  return prompt;
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
    generation?: number;
    durationMs?: number;
    stats?: string;
  },
): TelemetryEventEnvelope | undefined {
  return sess.emitTelemetry?.({
    source: "provider",
    providerSessionId: params.providerSessionId,
    providerTurnId: claudeTurnID(params.generation),
    providerEvent: { method: "result" },
    event: {
      type: "turn.completed",
      turnId: claudeTurnID(params.generation),
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
    generation?: number;
    message: string;
    code?: string;
    durationMs?: number;
    stats?: string;
    source?: "provider" | "sidecar";
    method?: string;
  },
): TelemetryEventEnvelope | undefined {
  const message = truncate(params.message, 400);
  return sess.emitTelemetry?.({
    source: params.source ?? "provider",
    providerSessionId: params.providerSessionId,
    providerTurnId: claudeTurnID(params.generation),
    providerEvent: params.method ? { method: params.method } : undefined,
    event: {
      type: "turn.failed",
      turnId: claudeTurnID(params.generation),
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
