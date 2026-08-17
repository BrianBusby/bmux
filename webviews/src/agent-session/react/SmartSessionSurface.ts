import React, { useCallback, useEffect, useReducer, useRef } from "react";
import {
  initialSmartSessionState,
  loadSmartSessionSnapshot,
  reduceSmartSession,
  semanticMessageForKind,
  SMART_SESSION_SEMANTIC_KINDS,
  type SmartSessionState,
} from "../shared/smartSessionModel";
import type {
  AgentSessionCopy,
  AppContext,
  SmartSessionCommand,
  SmartSessionFileChangeAttribution,
  SmartSessionPlanStep,
  SmartSessionReasoningSummary,
  SmartSessionSnapshot,
  SmartSessionTurnReference,
} from "../shared/types";

const h = React.createElement;

export function SmartSessionSurface({ context }: { context?: AppContext }) {
  const [state, dispatch] = useReducer(reduceSmartSession, initialSmartSessionState());
  const requestIdRef = useRef(0);
  const copy = context?.copy;

  const refresh = useCallback(() => {
    const requestId = requestIdRef.current + 1;
    requestIdRef.current = requestId;
    dispatch({ type: "refreshStarted", requestId });
    void loadSmartSessionSnapshot()
      .then((result) => dispatch({ type: "refreshSucceeded", requestId, result }))
      .catch(() => dispatch({ type: "refreshFailed", requestId }));
  }, []);

  useEffect(() => {
    if (context) {
      refresh();
    }
  }, [context?.stableWorkspaceId, context?.workspaceId, refresh]);

  return h(
    "section",
    { className: "smart-session-shell", "data-status": state.status },
    h(
      "header",
      { className: "smart-session-header" },
      h("div", { className: "smart-session-heading" }, copyText(copy, "sessionView", "Session")),
      h(
        "button",
        {
          className: "smart-session-refresh",
          type: "button",
          onClick: refresh,
          disabled: !context || state.status === "loading",
        },
        copyText(copy, "smartSessionRefresh", "Refresh"),
      ),
    ),
    renderSmartSessionBody(state, copy),
  );
}

function renderSmartSessionBody(state: SmartSessionState, copy?: AgentSessionCopy) {
  if (state.status === "loading" && !state.snapshot) {
    return h("div", { className: "smart-session-state" }, copyText(copy, "smartSessionLoading", "Loading session"));
  }

  if (!state.snapshot) {
    return h("div", { className: "smart-session-state" }, statusMessage(state, copy));
  }

  return h(SmartSessionSnapshotView, { snapshot: state.snapshot, copy });
}

function SmartSessionSnapshotView({
  snapshot,
  copy,
}: {
  snapshot: SmartSessionSnapshot;
  copy?: AgentSessionCopy;
}) {
  const latestTurn = snapshot.factual.latestTurn;
  const threadID = latestTurn?.threadId ?? snapshot.identity.providerThreads[0]?.threadId;
  const turnID = latestTurn?.turnId;
  const threadIntent = semanticMessageForKind(snapshot, {
    kind: SMART_SESSION_SEMANTIC_KINDS.threadIntent,
    scope: "thread",
    scopeId: threadID,
  });
  const turnIntent = semanticMessageForKind(snapshot, {
    kind: SMART_SESSION_SEMANTIC_KINDS.turnIntent,
    scope: "turn",
    scopeId: turnID,
  });
  const currentActivity = semanticMessageForKind(snapshot, {
    kind: SMART_SESSION_SEMANTIC_KINDS.currentActivity,
    scope: "turn",
    scopeId: turnID,
  });
  const phase = semanticMessageForKind(snapshot, {
    kind: SMART_SESSION_SEMANTIC_KINDS.sessionPhase,
    scope: "session",
    scopeId: snapshot.identity.sessionId,
  });

  return h(
    "div",
    { className: "smart-session-content" },
    h(
      "div",
      { className: "smart-session-grid" },
      h(SmartSessionPanel, {
        title: copyText(copy, "smartSessionPurpose", "Purpose"),
        children: semanticText(threadIntent, copy),
        detail: threadIntent?.expandedMeaning,
      }),
      h(SmartSessionPanel, {
        title: copyText(copy, "smartSessionCurrentTurn", "Current turn"),
        children: semanticText(turnIntent, copy),
        detail: latestTurn?.prompt?.text,
      }),
      h(SmartSessionPanel, {
        title: copyText(copy, "smartSessionCurrentActivity", "Current activity"),
        children: semanticText(currentActivity, copy),
        detail: currentActivity?.expandedMeaning,
      }),
      h(SmartSessionPanel, {
        title: copyText(copy, "smartSessionPhase", "Phase"),
        children: semanticText(phase, copy),
        detail: phase?.expandedMeaning,
      }),
    ),
    h(
      "div",
      { className: "smart-session-sections" },
      h(IdentitySection, { snapshot, copy }),
      h(PromptSection, { snapshot, copy }),
      h(PlanSection, { snapshot, copy }),
      h(EvidenceSection, { snapshot, copy }),
      h(PriorTurnsSection, { snapshot, copy }),
    ),
  );
}

function SmartSessionPanel({
  title,
  children,
  detail,
}: {
  title: string;
  children: React.ReactNode;
  detail?: string;
}) {
  return h(
    "section",
    { className: "smart-session-panel" },
    h("h2", null, title),
    h("div", { className: "smart-session-panel-primary" }, children),
    detail ? h("p", { className: "smart-session-panel-detail" }, detail) : null,
  );
}

function IdentitySection({
  snapshot,
  copy,
}: {
  snapshot: SmartSessionSnapshot;
  copy?: AgentSessionCopy;
}) {
  const latestTurn = snapshot.factual.latestTurn;
  const threadID = latestTurn?.threadId ?? snapshot.identity.providerThreads[0]?.threadId;
  return h(
    "section",
    { className: "smart-session-section" },
    h("h2", null, copyText(copy, "smartSessionIdentity", "Identity")),
    h(
      "dl",
      { className: "smart-session-definition-list" },
      h(DefinitionRow, {
        label: copyText(copy, "smartSessionSessionID", "Session ID"),
        value: snapshot.identity.sessionId,
      }),
      h(DefinitionRow, {
        label: copyText(copy, "smartSessionThread", "Thread"),
        value: threadID ?? copyText(copy, "smartSessionUnknown", "Unknown"),
      }),
      h(DefinitionRow, {
        label: copyText(copy, "smartSessionTurn", "Turn"),
        value: latestTurn?.turnId ?? copyText(copy, "smartSessionUnknown", "Unknown"),
      }),
      h(DefinitionRow, {
        label: copyText(copy, "smartSessionRevision", "Revision"),
        value: snapshot.revision.key,
      }),
    ),
  );
}

function PromptSection({
  snapshot,
  copy,
}: {
  snapshot: SmartSessionSnapshot;
  copy?: AgentSessionCopy;
}) {
  const prompt = snapshot.factual.latestTurn?.prompt?.text;
  return h(
    "section",
    { className: "smart-session-section" },
    h("h2", null, copyText(copy, "smartSessionPrompt", "Prompt")),
    prompt
      ? h("p", { className: "smart-session-prewrap" }, prompt)
      : h("p", { className: "smart-session-muted" }, copyText(copy, "smartSessionUnknown", "Unknown")),
  );
}

function PlanSection({
  snapshot,
  copy,
}: {
  snapshot: SmartSessionSnapshot;
  copy?: AgentSessionCopy;
}) {
  const plan = snapshot.factual.latestTurn?.plan;
  return h(
    "section",
    { className: "smart-session-section" },
    h("h2", null, copyText(copy, "smartSessionPlan", "Plan")),
    plan?.explanation ? h("p", { className: "smart-session-prewrap" }, plan.explanation) : null,
    plan?.steps.length
      ? h("ol", { className: "smart-session-plan-list" }, plan.steps.map((step) => h(PlanStepRow, { key: step.stepId, step })))
      : h("p", { className: "smart-session-muted" }, copyText(copy, "smartSessionNoPlan", "No plan evidence")),
  );
}

function PlanStepRow({ step }: { step: SmartSessionPlanStep }) {
  return h(
    "li",
    null,
    h("span", { className: "smart-session-status-pill" }, step.status),
    h("span", null, step.text),
  );
}

function EvidenceSection({
  snapshot,
  copy,
}: {
  snapshot: SmartSessionSnapshot;
  copy?: AgentSessionCopy;
}) {
  const turn = snapshot.factual.latestTurn;
  const commands = turn?.completedCommands ?? [];
  const fileChanges = turn?.fileChangeAttributions ?? [];
  const reasoning = turn?.visibleReasoningSummaries ?? [];
  const hasEvidence = commands.length > 0 || fileChanges.length > 0 || reasoning.length > 0;
  return h(
    "section",
    { className: "smart-session-section" },
    h("h2", null, copyText(copy, "smartSessionEvidence", "Evidence")),
    hasEvidence
      ? h(
          "div",
          { className: "smart-session-evidence-grid" },
          h(EvidenceList, {
            title: copyText(copy, "smartSessionCommands", "Commands"),
            items: commands.slice(0, 6),
            emptyLabel: copyText(copy, "smartSessionNoEvidence", "No evidence yet"),
            renderItem: (item: SmartSessionEvidenceItem) => renderCommand(item as SmartSessionCommand),
          }),
          h(EvidenceList, {
            title: copyText(copy, "smartSessionFiles", "Files"),
            items: fileChanges.slice(0, 6),
            emptyLabel: copyText(copy, "smartSessionNoEvidence", "No evidence yet"),
            renderItem: (item: SmartSessionEvidenceItem) => renderFileChange(item as SmartSessionFileChangeAttribution),
          }),
          h(EvidenceList, {
            title: copyText(copy, "smartSessionReasoning", "Reasoning"),
            items: reasoning.slice(0, 4),
            emptyLabel: copyText(copy, "smartSessionNoEvidence", "No evidence yet"),
            renderItem: (item: SmartSessionEvidenceItem) => renderReasoning(item as SmartSessionReasoningSummary),
          }),
        )
      : h("p", { className: "smart-session-muted" }, copyText(copy, "smartSessionNoEvidence", "No evidence yet")),
  );
}

type SmartSessionEvidenceItem =
  | SmartSessionCommand
  | SmartSessionFileChangeAttribution
  | SmartSessionReasoningSummary;

function EvidenceList({
  title,
  emptyLabel,
  items,
  renderItem,
}: {
  title: string;
  emptyLabel: string;
  items: SmartSessionEvidenceItem[];
  renderItem: (item: SmartSessionEvidenceItem) => React.ReactNode;
}) {
  return h(
    "div",
    { className: "smart-session-evidence-list" },
    h("h3", null, title),
    items.length
      ? h("ul", null, items.map((item, index) => h("li", { key: index }, renderItem(item))))
      : h("p", { className: "smart-session-muted" }, emptyLabel),
  );
}

function PriorTurnsSection({
  snapshot,
  copy,
}: {
  snapshot: SmartSessionSnapshot;
  copy?: AgentSessionCopy;
}) {
  const priorTurns = snapshot.factual.priorTurns.slice(0, 8);
  return h(
    "section",
    { className: "smart-session-section" },
    h("h2", null, copyText(copy, "smartSessionPriorTurns", "Prior turns")),
    priorTurns.length
      ? h("ul", { className: "smart-session-prior-list" }, priorTurns.map((turn) => h(PriorTurnRow, { key: turn.turnId, turn })))
      : h("p", { className: "smart-session-muted" }, copyText(copy, "smartSessionNoEvidence", "No evidence yet")),
  );
}

function PriorTurnRow({ turn }: { turn: SmartSessionTurnReference }) {
  return h(
    "li",
    null,
    h("span", null, turn.providerTurnId),
    h("span", { className: "smart-session-status-pill" }, turn.status),
  );
}

function DefinitionRow({ label, value }: { label: string; value: string }) {
  return h(
    React.Fragment,
    null,
    h("dt", null, label),
    h("dd", null, value),
  );
}

function renderCommand(command: SmartSessionCommand) {
  return h(
    "div",
    { className: "smart-session-evidence-item" },
    h("code", null, command.command),
    h("span", { className: "smart-session-status-pill" }, command.status),
  );
}

function renderFileChange(change: SmartSessionFileChangeAttribution) {
  return h(
    "div",
    { className: "smart-session-evidence-item" },
    h("span", null, change.summary ?? change.paths.join(", ")),
    change.paths.length ? h("small", null, change.paths.join(", ")) : null,
  );
}

function renderReasoning(summary: SmartSessionReasoningSummary) {
  return h("p", { className: "smart-session-prewrap" }, summary.text);
}

function semanticText(
  message: ReturnType<typeof semanticMessageForKind>,
  copy?: AgentSessionCopy,
) {
  return message?.concisePhrase ?? copyText(copy, "smartSessionUnknown", "Unknown");
}

function statusMessage(state: SmartSessionState, copy?: AgentSessionCopy): string {
  switch (state.status) {
    case "missingSession":
      return copyText(copy, "smartSessionNoSession", "No linked session");
    case "unavailable":
      return copyText(copy, "smartSessionUnavailable", "Session data unavailable");
    case "notFound":
      return copyText(copy, "smartSessionNotFound", "Session not found");
    case "failed":
      return copyText(copy, "smartSessionFailed", "Session refresh failed");
    case "idle":
    case "loading":
      return copyText(copy, "smartSessionLoading", "Loading session");
    case "available":
      return "";
  }
}

function copyText<K extends keyof AgentSessionCopy>(
  copy: AgentSessionCopy | undefined,
  key: K,
  fallback: string,
): string {
  return copy?.[key] ?? fallback;
}
