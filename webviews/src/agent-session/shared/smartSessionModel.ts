import { callNative } from "./bridge";
import type {
  SmartSessionReadResult,
  SmartSessionRevision,
  SmartSessionSemanticField,
  SmartSessionSemanticMessage,
  SmartSessionSnapshot,
} from "./types";

export const SMART_SESSION_SEMANTIC_KINDS = {
  currentActivity: "coding_agent.current_activity",
  sessionPhase: "coding_agent.session_phase",
  threadIntent: "coding_agent.thread_intent",
  turnIntent: "coding_agent.turn_intent",
} as const;

export type SmartSessionStatus =
  | "idle"
  | "loading"
  | "available"
  | "missingSession"
  | "unavailable"
  | "noSupportedCodingAgentDetected"
  | "agentDetectedAwaitingFirstPrompt"
  | "promptObservedAssociationPending"
  | "associationEstablishedProjectionPending"
  | "ingestionFailed"
  | "identityReconciliationFailed"
  | "projectionFailed"
  | "unsupportedOrUnassociatedSession"
  | "notFound"
  | "failed";

export type SmartSessionState = {
  requestId: number;
  status: SmartSessionStatus;
  snapshot?: SmartSessionSnapshot;
  reason?: string;
  sessionId?: string;
  diagnostics?: Record<string, unknown>;
};

export type SmartSessionAction =
  | { type: "refreshStarted"; requestId: number }
  | { type: "refreshSucceeded"; requestId: number; result: SmartSessionReadResult }
  | { type: "refreshFailed"; requestId: number };

export function initialSmartSessionState(): SmartSessionState {
  return {
    requestId: 0,
    status: "idle",
  };
}

export function shouldRefreshSmartSession(hasContext: boolean, isActive: boolean): boolean {
  return hasContext && isActive;
}

export function reduceSmartSession(state: SmartSessionState, action: SmartSessionAction): SmartSessionState {
  if (action.requestId < state.requestId) {
    return state;
  }

  switch (action.type) {
    case "refreshStarted":
      return {
        ...state,
        requestId: action.requestId,
        status: state.snapshot ? state.status : "loading",
      };
    case "refreshFailed":
      return {
        ...state,
        requestId: action.requestId,
        status: state.snapshot ? "available" : "failed",
      };
    case "refreshSucceeded": {
      if (action.result.status !== "available") {
        return {
          requestId: action.requestId,
          status: action.result.status,
          reason: action.result.reason,
          sessionId: action.result.sessionId,
          diagnostics: action.result.diagnostics,
          snapshot: state.snapshot,
        };
      }

      if (
        state.snapshot &&
        compareSmartSessionRevisions(action.result.snapshot.revision, state.snapshot.revision) < 0
      ) {
        return {
          ...state,
          requestId: action.requestId,
          status: "available",
        };
      }

      return {
        requestId: action.requestId,
        status: "available",
        snapshot: action.result.snapshot,
      };
    }
    default:
      return state;
  }
}

export async function loadSmartSessionSnapshot(): Promise<SmartSessionReadResult> {
  return callNative<SmartSessionReadResult>("smartSession.snapshot");
}

export type SmartSessionSemanticMessageFilter = {
  kind: string;
  scope?: SmartSessionSemanticMessage["scope"];
  scopeId?: string;
};

export type SmartSessionSemanticFieldFilter = {
  kind: string;
  scope?: SmartSessionSemanticField["scope"];
  scopeId?: string;
};

export function semanticMessageForKind(
  snapshot: SmartSessionSnapshot | undefined,
  filter: SmartSessionSemanticMessageFilter,
): SmartSessionSemanticMessage | undefined {
  return snapshot?.semanticMessages.find((message) => {
    if (message.status !== "active") {
      return false;
    }
    if (message.semanticInferenceKind !== filter.kind) {
      return false;
    }
    if (filter.scope && message.scope !== filter.scope) {
      return false;
    }
    if (filter.scopeId && message.scopeId !== filter.scopeId) {
      return false;
    }
    return true;
  });
}

export function semanticFieldForKind(
  snapshot: SmartSessionSnapshot | undefined,
  filter: SmartSessionSemanticFieldFilter,
): SmartSessionSemanticField | undefined {
  const fields = [
    snapshot?.workModel?.thread?.intent,
    snapshot?.workModel?.currentTurn?.intent,
    snapshot?.workModel?.currentTurn?.currentActivity,
    snapshot?.workModel?.sessionPhase,
  ].filter((field): field is SmartSessionSemanticField => Boolean(field));
  return fields.find((field) => {
    if (field.kind !== filter.kind) {
      return false;
    }
    if (filter.scope && field.scope !== filter.scope) {
      return false;
    }
    if (filter.scopeId && field.scopeId !== filter.scopeId) {
      return false;
    }
    return true;
  });
}

export function compareSmartSessionRevisions(left: SmartSessionRevision, right: SmartSessionRevision): number {
  if (left.factualRevision !== right.factualRevision) {
    if (left.factualRevision == null) {
      return -1;
    }
    if (right.factualRevision == null) {
      return 1;
    }
    return left.factualRevision > right.factualRevision ? 1 : -1;
  }
  const leftInference = Date.parse(left.latestSemanticInferenceCreatedAt ?? "");
  const rightInference = Date.parse(right.latestSemanticInferenceCreatedAt ?? "");
  const leftHasInference = Number.isFinite(leftInference);
  const rightHasInference = Number.isFinite(rightInference);
  if (leftHasInference && rightHasInference && leftInference !== rightInference) {
    return leftInference > rightInference ? 1 : -1;
  }
  if (leftHasInference !== rightHasInference) {
    return leftHasInference ? 1 : -1;
  }
  const leftInferenceIds = left.semanticInferenceIds?.join("\u0000") ?? "";
  const rightInferenceIds = right.semanticInferenceIds?.join("\u0000") ?? "";
  if (leftInferenceIds !== rightInferenceIds) {
    const leftCount = left.semanticInferenceIds?.length ?? 0;
    const rightCount = right.semanticInferenceIds?.length ?? 0;
    if (leftCount !== rightCount) {
      return leftCount > rightCount ? 1 : -1;
    }
    return 0;
  }
  const leftSemantic = Date.parse(left.latestSemanticMessageCreatedAt ?? "");
  const rightSemantic = Date.parse(right.latestSemanticMessageCreatedAt ?? "");
  const leftHasSemantic = Number.isFinite(leftSemantic);
  const rightHasSemantic = Number.isFinite(rightSemantic);
  if (leftHasSemantic && rightHasSemantic && leftSemantic !== rightSemantic) {
    return leftSemantic > rightSemantic ? 1 : -1;
  }
  if (leftHasSemantic !== rightHasSemantic) {
    return leftHasSemantic ? 1 : -1;
  }
  if (left.semanticMessageCount !== right.semanticMessageCount) {
    return left.semanticMessageCount > right.semanticMessageCount ? 1 : -1;
  }
  return 0;
}
