import type {
  TelemetryApprovalKind,
  TelemetryDiagnosticLevel,
  TelemetryEventEnvelope,
  TelemetryProviderId,
  TelemetryProviderSessionId,
  TelemetryProviderTurnId,
  TelemetrySessionId,
  TelemetryTokenUsage,
} from "./executionTelemetryTypes";

export type LiveSessionLifecycleState = "unknown" | "idle" | "running" | "failed";

export interface LiveSessionUsageSummary extends TelemetryTokenUsage {
  turnId?: TelemetryProviderTurnId;
  observedAtMs: number;
}

export interface LiveSessionDiagnosticSummary {
  level: TelemetryDiagnosticLevel;
  message: string;
  code?: string;
  observedAtMs: number;
}

export interface LiveSessionApprovalBlockedState {
  blocked: boolean;
  pendingCount: number;
  approvalId?: string;
  approvalKind?: TelemetryApprovalKind;
  operationId?: string;
  summary?: string;
  requestedAtMs?: number;
}

export interface LiveSessionFilesChangedSummary {
  hasChanges: boolean;
  count: number;
}

export interface LiveSessionProjectionSnapshot {
  sessionId: TelemetrySessionId;
  provider: TelemetryProviderId;
  providerSessionId?: TelemetryProviderSessionId;
  currentProviderTurnId?: TelemetryProviderTurnId;
  lifecycleState: LiveSessionLifecycleState;
  activeOperationCount: number;
  latestActivityAtMs: number;
  latestUsageSummary?: LiveSessionUsageSummary;
  latestDiagnostic?: LiveSessionDiagnosticSummary;
  approvalBlocked: LiveSessionApprovalBlockedState;
  filesChanged?: LiveSessionFilesChangedSummary;
}

interface PendingApproval {
  approvalId: string;
  approvalKind: TelemetryApprovalKind;
  operationId?: string;
  summary?: string;
  requestedAtMs?: number;
}

interface ProjectionState {
  sessionId?: TelemetrySessionId;
  provider?: TelemetryProviderId;
  providerSessionId?: TelemetryProviderSessionId;
  currentProviderTurnId?: TelemetryProviderTurnId;
  lifecycleState: LiveSessionLifecycleState;
  latestActivityAtMs?: number;
  latestUsageSummary?: LiveSessionUsageSummary;
  latestDiagnostic?: LiveSessionDiagnosticSummary;
}

export class LiveSessionProjection {
  private readonly state: ProjectionState = {
    lifecycleState: "unknown",
  };
  private readonly activeOperationIds = new Set<string>();
  private readonly pendingApprovals = new Map<string, PendingApproval>();
  private readonly changedFilePaths = new Set<string>();

  apply(envelope: TelemetryEventEnvelope): LiveSessionProjectionSnapshot {
    this.assertStreamIdentity(envelope);
    this.state.latestActivityAtMs = envelope.capturedAtMs;
    if (envelope.providerSessionId !== undefined) this.state.providerSessionId = envelope.providerSessionId;
    if (envelope.providerTurnId !== undefined && this.state.lifecycleState === "running") {
      this.state.currentProviderTurnId = envelope.providerTurnId;
    }

    const event = envelope.event;
    switch (event.type) {
      case "session.started":
        if (this.state.lifecycleState === "unknown") this.state.lifecycleState = "idle";
        break;
      case "session.provider-linked":
        this.state.providerSessionId = event.providerSessionId;
        break;
      case "prompt.submitted":
        this.state.lifecycleState = "running";
        break;
      case "turn.started":
        this.state.lifecycleState = "running";
        this.state.currentProviderTurnId = event.turnId ?? envelope.providerTurnId;
        break;
      case "turn.completed":
        this.finishTurn(event.turnId ?? envelope.providerTurnId, "idle");
        if (event.usage) this.state.latestUsageSummary = usageSummary(event.usage, event.turnId ?? envelope.providerTurnId, envelope.capturedAtMs);
        break;
      case "turn.failed":
        this.finishTurn(event.turnId ?? envelope.providerTurnId, "failed");
        break;
      case "tool.started":
        this.activeOperationIds.add(event.operationId);
        break;
      case "tool.completed":
        this.activeOperationIds.delete(event.operationId);
        break;
      case "approval.requested":
        this.pendingApprovals.set(event.approvalId, {
          approvalId: event.approvalId,
          approvalKind: event.approvalKind,
          operationId: event.operationId,
          summary: event.summary,
          requestedAtMs: event.requestedAtMs ?? envelope.capturedAtMs,
        });
        break;
      case "approval.resolved":
        this.pendingApprovals.delete(event.approvalId);
        break;
      case "usage.updated":
        this.state.latestUsageSummary = usageSummary(event.usage, event.turnId ?? envelope.providerTurnId, envelope.capturedAtMs);
        break;
      case "files.changed":
        for (const file of event.files) this.changedFilePaths.add(file.path);
        break;
      case "diagnostic":
        this.state.latestDiagnostic = {
          level: event.level,
          message: event.message,
          code: event.code,
          observedAtMs: envelope.capturedAtMs,
        };
        break;
      case "message.delta":
      case "message.completed":
      case "context.compacted":
        break;
    }

    return this.snapshot();
  }

  snapshot(): LiveSessionProjectionSnapshot {
    if (!this.state.sessionId || !this.state.provider || this.state.latestActivityAtMs === undefined) {
      throw new Error("live session projection has no telemetry events");
    }
    const snapshot: LiveSessionProjectionSnapshot = {
      sessionId: this.state.sessionId,
      provider: this.state.provider,
      providerSessionId: this.state.providerSessionId,
      currentProviderTurnId: this.state.currentProviderTurnId,
      lifecycleState: this.state.lifecycleState,
      activeOperationCount: this.activeOperationIds.size,
      latestActivityAtMs: this.state.latestActivityAtMs,
      latestUsageSummary: this.state.latestUsageSummary,
      latestDiagnostic: this.state.latestDiagnostic,
      approvalBlocked: this.approvalBlockedState(),
    };
    if (this.changedFilePaths.size > 0) {
      snapshot.filesChanged = {
        hasChanges: true,
        count: this.changedFilePaths.size,
      };
    }
    return snapshot;
  }

  private assertStreamIdentity(envelope: TelemetryEventEnvelope) {
    if (this.state.sessionId === undefined) {
      this.state.sessionId = envelope.sessionId;
      this.state.provider = envelope.provider;
      return;
    }
    if (this.state.sessionId !== envelope.sessionId) {
      throw new Error(`mixed telemetry sessions: expected ${this.state.sessionId}, got ${envelope.sessionId}`);
    }
    if (this.state.provider !== envelope.provider) {
      throw new Error(`mixed telemetry providers: expected ${this.state.provider}, got ${envelope.provider}`);
    }
  }

  private finishTurn(turnId: TelemetryProviderTurnId | undefined, nextState: LiveSessionLifecycleState) {
    if (turnId === undefined || this.state.currentProviderTurnId === undefined || this.state.currentProviderTurnId === turnId) {
      delete this.state.currentProviderTurnId;
    }
    this.activeOperationIds.clear();
    this.state.lifecycleState = nextState;
  }

  private approvalBlockedState(): LiveSessionApprovalBlockedState {
    const firstPending = this.pendingApprovals.values().next().value as PendingApproval | undefined;
    if (!firstPending) return { blocked: false, pendingCount: 0 };
    return {
      blocked: true,
      pendingCount: this.pendingApprovals.size,
      approvalId: firstPending.approvalId,
      approvalKind: firstPending.approvalKind,
      operationId: firstPending.operationId,
      summary: firstPending.summary,
      requestedAtMs: firstPending.requestedAtMs,
    };
  }
}

export function replayLiveSessionProjection(envelopes: Iterable<TelemetryEventEnvelope>): LiveSessionProjectionSnapshot {
  const projection = new LiveSessionProjection();
  let snapshot: LiveSessionProjectionSnapshot | undefined;
  for (const envelope of envelopes) snapshot = projection.apply(envelope);
  if (!snapshot) throw new Error("live session projection replay requires at least one telemetry event");
  return snapshot;
}

function usageSummary(
  usage: TelemetryTokenUsage,
  turnId: TelemetryProviderTurnId | undefined,
  observedAtMs: number,
): LiveSessionUsageSummary {
  return {
    turnId,
    inputTokens: usage.inputTokens,
    cachedInputTokens: usage.cachedInputTokens,
    outputTokens: usage.outputTokens,
    reasoningOutputTokens: usage.reasoningOutputTokens,
    totalTokens: usage.totalTokens,
    contextWindowTokens: usage.contextWindowTokens,
    model: usage.model,
    observedAtMs,
  };
}
