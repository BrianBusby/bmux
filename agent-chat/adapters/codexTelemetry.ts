import type { SessionCtx } from "../types";
import type { TelemetryEventEnvelope } from "../executionTelemetryTypes";

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
