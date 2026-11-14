import { callNative } from "./bridge";
import type {
  SmartSessionReadResult,
  SmartSessionRevision,
  SmartSessionSemanticField,
  SmartSessionSemanticMessage,
  SmartSessionSnapshot,
  SmartSessionTurnReference,
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
  lastSuccessfulReadAt?: string;
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

// Bridge values are JSON data. Compare object keys without assuming serialization order.
function equalData(left: unknown, right: unknown): boolean {
  if (Object.is(left, right)) return true;
  if (Array.isArray(left) && Array.isArray(right)) {
    return left.length === right.length && left.every((value, index) => equalData(value, right[index]));
  }
  if (!left || !right || typeof left !== "object" || typeof right !== "object" || Array.isArray(left) || Array.isArray(right)) return false;
  const leftEntries = Object.entries(left);
  const rightEntries = new Map(Object.entries(right));
  return leftEntries.length === rightEntries.size && leftEntries.every(([key, value]) => rightEntries.has(key) && equalData(value, rightEntries.get(key)));
}

function samePrimary(left: SmartSessionSnapshot, right: SmartSessionSnapshot): boolean {
  return equalData(left.revision, right.revision) && equalData(left.identity, right.identity) &&
    equalData(left.workModel, right.workModel) && equalData(left.factual, right.factual) &&
    equalData(left.semanticMessages, right.semanticMessages) && left.schemaVersion === right.schemaVersion;
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
        status: "loading",
      };
    case "refreshFailed":
      return {
        ...state,
        requestId: action.requestId,
        status: "failed",
      };
    case "refreshSucceeded": {
      if (action.result.status !== "available") {
        const failed = action.result.status === "failed" || action.result.status === "projectionFailed";
        const priorMatches = !action.result.sessionId || action.result.sessionId === state.snapshot?.identity.sessionId;
        const suppliedMatches = action.result.snapshot &&
          (!action.result.sessionId || action.result.sessionId === action.result.snapshot.identity.sessionId);
        const keepPrior = priorMatches && state.snapshot && (!suppliedMatches || !action.result.snapshot ||
          (state.snapshot.identity.sessionId === action.result.snapshot.identity.sessionId &&
            (compareSmartSessionRevisions(state.snapshot.revision, action.result.snapshot.revision) > 0 ||
              (compareSmartSessionRevisions(state.snapshot.revision, action.result.snapshot.revision) === 0 &&
                !samePrimary(state.snapshot, action.result.snapshot)))));
        return {
          requestId: action.requestId,
          status: action.result.status,
          reason: action.result.reason,
          sessionId: action.result.sessionId,
          diagnostics: action.result.diagnostics,
          snapshot: failed ? (keepPrior && state.snapshot ? { ...state.snapshot, semanticMessagesReadStatus: "unavailable", crossSessionAwareness: suppliedMatches && action.result.snapshot ? action.result.snapshot.crossSessionAwareness : state.snapshot.crossSessionAwareness } : suppliedMatches ? action.result.snapshot : undefined) : undefined,
          lastSuccessfulReadAt: failed ? (keepPrior ? state.lastSuccessfulReadAt : action.result.lastSuccessfulReadAt) : undefined,
        };
      }

      if (
        state.snapshot &&
        state.snapshot.identity.sessionId === action.result.snapshot.identity.sessionId &&
        (compareSmartSessionRevisions(action.result.snapshot.revision, state.snapshot.revision) < 0 ||
          (compareSmartSessionRevisions(action.result.snapshot.revision, state.snapshot.revision) === 0 &&
            !samePrimary(action.result.snapshot, state.snapshot)))
      ) {
        return {
          ...state,
          snapshot: { ...state.snapshot, semanticMessagesReadStatus: "unavailable", crossSessionAwareness: action.result.snapshot.crossSessionAwareness },
          requestId: action.requestId,
          status: "failed",
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

/** Orders completed turns by canonical turn time, not projection update time. */
export function sortSmartSessionTurnReferencesNewestFirst(turns: SmartSessionTurnReference[]): SmartSessionTurnReference[] {
  return [...turns].sort((left, right) => {
    const timeDifference = turnTime(right) - turnTime(left);
    return timeDifference || right.turnId.localeCompare(left.turnId);
  });
}

function turnTime(turn: SmartSessionTurnReference): number {
  return Date.parse(turn.completedAt ?? turn.startedAt ?? turn.updatedAt) || 0;
}

export function compareSmartSessionRevisions(left: SmartSessionRevision, right: SmartSessionRevision): number {
  if (left.factualRevision == null || right.factualRevision == null) return 0;
  if (left.factualRevision !== right.factualRevision) return left.factualRevision > right.factualRevision ? 1 : -1;
  if (left.schemaVersion !== 3 || right.schemaVersion !== 3) return 0;
  const leftInference = Date.parse(left.latestSemanticInferenceCreatedAt ?? "");
  const rightInference = Date.parse(right.latestSemanticInferenceCreatedAt ?? "");
  const leftHasInference = Number.isFinite(leftInference);
  const rightHasInference = Number.isFinite(rightInference);
  if (leftHasInference && rightHasInference && leftInference !== rightInference) {
    return leftInference > rightInference ? 1 : -1;
  }
  if (leftHasInference !== rightHasInference) {
    return 0;
  }
  const leftInferenceIds = left.semanticInferenceIds?.join("\u0000") ?? "";
  const rightInferenceIds = right.semanticInferenceIds?.join("\u0000") ?? "";
  if (leftInferenceIds !== rightInferenceIds) {
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
    return 0;
  }
  return 0;
}
