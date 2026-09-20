import React, { useCallback, useEffect, useReducer, useState } from "react";
import { initialSmartSessionState, loadSmartSessionSnapshot, reduceSmartSession, semanticFieldForKind, sortSmartSessionTurnReferencesNewestFirst, SMART_SESSION_SEMANTIC_KINDS, type SmartSessionState } from "../shared/smartSessionModel";
import type { AgentSessionCopy, AppContext, SmartSessionPlanStep, SmartSessionSemanticField, SmartSessionSnapshot, SmartSessionTurn, SmartSessionTurnReference } from "../shared/types";

const h = React.createElement;

export type AgentSessionViewMode = "focus" | "chat" | "terminal" | "learnings";
type Props = { context?: AppContext; initialView?: AgentSessionViewMode; isActive?: boolean; renderChat?: () => React.ReactNode; renderTerminal?: () => React.ReactNode };

export function SmartSessionSurface({ context, initialView = "focus", isActive = true, renderChat, renderTerminal }: Props) {
  const [state, dispatch] = useReducer(reduceSmartSession, initialSmartSessionState());
  const [view, setView] = useState<AgentSessionViewMode>(initialView);
  const [inspector, setInspector] = useState<string | null>(null);
  const [expandedTurnID, setExpandedTurnID] = useState<string | null>(null);
  const requestIdRef = React.useRef(0);
  const copy = context?.copy;
  const refreshIdentity = context?.stableWorkspaceId ?? context?.workspaceId ?? "";
  const refresh = useCallback(() => {
    const requestId = requestIdRef.current + 1;
    requestIdRef.current = requestId;
    dispatch({ type: "refreshStarted", requestId });
    void loadSmartSessionSnapshot().then(result => dispatch({ type: "refreshSucceeded", requestId, result })).catch(() => dispatch({ type: "refreshFailed", requestId }));
  }, []);
  useEffect(() => { if (isActive && refreshIdentity) refresh(); }, [isActive, refreshIdentity, refresh]);

  const snapshot = state.snapshot;
  const workspaceName = repositoryName(context?.workingDirectory) ?? text(copy, "smartSessionWorkspace", "Workspace");
  const currentTitle = snapshot?.factual.latestTurn?.prompt?.text?.split("\n")[0] ?? text(copy, "smartSessionCurrent", "Current workspace");
  const status = snapshot?.identity.status ?? state.status;
  return h("div", { className: "focus-workbench", "data-view": view, "data-theme-source": context?.theme.isDark ? "dark" : "light" },
    h(WorkspaceRail, { copy, workspaceName, title: currentTitle, status, onSelect: () => setView("focus") }),
    h("main", { className: "focus-workbench-main" },
      h(WorkspaceHeader, { copy, workspaceName, title: currentTitle, snapshot, onInspect: setInspector, inspector }),
      h(ViewTabs, { copy, view, onChange: setView }),
      h("div", { className: "focus-workbench-body" },
        view === "focus" ? h(FocusView, { copy, state, onRefresh: refresh, expandedTurnID, onExpandTurn: setExpandedTurnID, onInspect: setInspector }) :
          view === "chat" ? h(ViewFrame, { className: "focus-chat-frame", children: renderChat ? renderChat() : h(UnsupportedView, { copy, kind: "chat" }) }) :
            view === "terminal" ? h(ViewFrame, { className: "focus-terminal-frame", children: renderTerminal ? renderTerminal() : h(UnsupportedView, { copy, kind: "terminal" }) }) :
              h(LearningsView, { copy, onInspect: setInspector }),
      ),
    ),
  );
}

function WorkspaceRail({ copy, workspaceName, title, status, onSelect }: { copy?: AgentSessionCopy; workspaceName: string; title: string; status: string; onSelect: () => void }) {
  return h("aside", { className: "focus-workspace-rail", "aria-label": text(copy, "smartSessionWorkspace", "Workspace") },
    h("div", { className: "focus-rail-heading" }, h("span", null, text(copy, "smartSessionCurrent", "Current")), h("span", { className: "focus-rail-count" }, "1")),
    h("button", { type: "button", className: "focus-workspace-card is-selected", "aria-pressed": true, onClick: onSelect },
      h("span", { className: "focus-card-repository" }, workspaceName), h("strong", null, title), h("span", { className: "focus-card-status" }, h("i", { "aria-hidden": true }), statusLabel(status, copy)),
      h("span", { className: "focus-card-activity" }, text(copy, "smartSessionIdentity", "Verified workspace identity")),
    ),
    h("p", { className: "focus-rail-note" }, text(copy, "smartSessionUnavailable", "Workspace links are unavailable for this surface.")),
  );
}

function WorkspaceHeader({ copy, workspaceName, title, snapshot, inspector, onInspect }: { copy?: AgentSessionCopy; workspaceName: string; title: string; snapshot?: SmartSessionSnapshot; inspector: string | null; onInspect: (value: string | null) => void }) {
  const provider = snapshot?.identity.agentKind ?? "provider";
  return h("header", { className: "focus-workspace-header" },
    h("div", { className: "focus-header-copy" }, h("div", { className: "focus-breadcrumb" }, `${workspaceName} / ${provider}`), h("h1", null, title), snapshot?.identity.sessionId ? h("p", { className: "focus-header-identity" }, `${text(copy, "smartSessionSessionID", "Session ID")}: ${snapshot.identity.sessionId}`) : null),
    h("div", { className: "focus-header-status" }, h("span", { className: "focus-connected-dot", "aria-hidden": true }), h("span", null, statusLabel(snapshot?.identity.status ?? "unavailable", copy)), h("button", { type: "button", className: "focus-inspector-link", onClick: () => onInspect("workspace") }, text(copy, "smartSessionIdentity", "Workspace details")), inspector === "workspace" ? h(Inspector, { title: text(copy, "smartSessionIdentity", "Workspace details"), onClose: () => onInspect(null), children: h(WorkspaceDetails, { copy, snapshot }) }) : null),
  );
}

function ViewTabs({ copy, view, onChange }: { copy?: AgentSessionCopy; view: AgentSessionViewMode; onChange: (view: AgentSessionViewMode) => void }) {
  const tabs: Array<[AgentSessionViewMode, string]> = [["focus", text(copy, "smartSessionFocus", "Focus")], ["chat", copy?.terminalView ?? "Chat"], ["terminal", text(copy, "smartSessionTerminal", "Terminal")], ["learnings", text(copy, "smartSessionLearnings", "Learnings")]];
  return h("nav", { className: "focus-view-tabs", role: "tablist", "aria-label": text(copy, "smartSessionWorkspace", "Workspace views") }, ...tabs.map(([id, label]) => h("button", { key: id, type: "button", role: "tab", "aria-selected": view === id, className: `focus-view-tab${view === id ? " is-active" : ""}`, onClick: () => onChange(id) }, label)));
}

function FocusView({ copy, state, onRefresh, expandedTurnID, onExpandTurn, onInspect }: { copy?: AgentSessionCopy; state: SmartSessionState; onRefresh: () => void; expandedTurnID: string | null; onExpandTurn: (turnID: string | null) => void; onInspect: (value: string | null) => void }) {
  if (state.status === "loading" && !state.snapshot) return h(EmptyState, { message: text(copy, "smartSessionLoading", "Loading session") });
  if (!state.snapshot) return h(EmptyState, { message: statusMessage(state, copy), action: h("button", { type: "button", onClick: onRefresh }, text(copy, "smartSessionRefresh", "Refresh")) });
  const snapshot = state.snapshot;
  const current = snapshot.factual.latestTurn;
  const purpose = semanticFieldForKind(snapshot, { kind: SMART_SESSION_SEMANTIC_KINDS.threadIntent, scope: "thread" });
  const activity = semanticFieldForKind(snapshot, { kind: SMART_SESSION_SEMANTIC_KINDS.currentActivity, scope: "turn", scopeId: current?.turnId });
  const history = sortSmartSessionTurnReferencesNewestFirst(snapshot.factual.priorTurns);
  const related = snapshot.crossSessionAwareness.status === "available" && (snapshot.crossSessionAwareness.relatedSessions.length > 0 || snapshot.crossSessionAwareness.collisions.length > 0);
  return h("div", { className: "focus-reading-column" },
    current ? h(CurrentTurnCard, { copy, turn: current, purpose, activity, onInspect }) : h(EmptyState, { message: text(copy, "smartSessionNoCurrentTurn", "No current turn. The latest supported outcome appears below.") }),
    related ? h(RelatedWorkStrip, { copy, snapshot, onInspect }) : null,
    h("section", { className: "focus-history-section" }, h("div", { className: "focus-section-heading" }, h("h2", null, text(copy, "smartSessionPriorTurns", "History")), h("span", { className: "focus-section-meta" }, `${history.length}`)), history.length ? h("div", { className: "focus-history-list" }, ...history.map(turn => h(PriorTurnCard, { key: turn.turnId, copy, turn, expanded: expandedTurnID === turn.turnId, onToggle: () => onExpandTurn(expandedTurnID === turn.turnId ? null : turn.turnId), onInspect }))) : h("p", { className: "focus-muted" }, text(copy, "smartSessionNoEvidence", "No completed turns yet."))),
    snapshot.factual.turnCount > history.length + (current ? 1 : 0) ? h("p", { className: "focus-coverage-note" }, text(copy, "smartSessionUnavailable", "History is partial; only same-identity records are shown.")) : null,
  );
}

function CurrentTurnCard({ copy, turn, purpose, activity, onInspect }: { copy?: AgentSessionCopy; turn: SmartSessionTurn; purpose?: SmartSessionSemanticField; activity?: SmartSessionSemanticField; onInspect: (value: string | null) => void }) {
  const output = turn.assistantMessages.at(-1);
  const results = [...turn.completedCommands.slice(0, 3).map(command => `${command.command} · ${command.status}`), ...turn.fileChangeAttributions.slice(0, 2).map(change => change.summary ?? change.paths.join(", ")), ...(output ? [output.text] : [])].filter(Boolean);
  return h("article", { className: "focus-current-card" },
    h("div", { className: "focus-card-kicker" }, text(copy, "smartSessionCurrentTurn", "Current turn"), h("span", { className: `focus-turn-status focus-turn-${turn.status}` }, turn.status)),
    h("h2", null, turn.prompt?.text ?? text(copy, "smartSessionUnknown", "Objective unavailable")),
    h("div", { className: "focus-current-grid" }, h(SummaryBlock, { label: text(copy, "smartSessionPurpose", "Objective"), value: purpose?.summary ?? turn.prompt?.text ?? text(copy, "smartSessionUnknown", "Unknown") }), h(SummaryBlock, { label: text(copy, "smartSessionCurrentActivity", "Current activity"), value: activity?.summary ?? latestActivity(turn, copy) })),
    h("section", { className: "focus-results" }, h("h3", null, text(copy, "smartSessionFinalOutput", "Results")), results.length ? h("ul", null, ...results.map((result, index) => h("li", { key: `${turn.turnId}-${index}` }, result))) : h("p", { className: "focus-muted" }, text(copy, "smartSessionNoEvidence", "No evidence yet."))),
    h("div", { className: "focus-current-actions" }, h("button", { type: "button", className: "focus-secondary-button", onClick: () => onInspect(`turn:${turn.turnId}`) }, text(copy, "smartSessionEvidence", "Inspect evidence")), h("span", { className: "focus-source-note" }, turn.provider)),
  );
}

function PriorTurnCard({ copy, turn, expanded, onToggle, onInspect }: { copy?: AgentSessionCopy; turn: SmartSessionTurnReference; expanded: boolean; onToggle: () => void; onInspect: (value: string | null) => void }) {
  return h("article", { className: `focus-history-card${expanded ? " is-expanded" : ""}` }, h("button", { type: "button", className: "focus-history-toggle", "aria-expanded": expanded, onClick: onToggle }, h("span", { className: "focus-history-date" }, formatTurnDate(turn.completedAt ?? turn.startedAt ?? turn.updatedAt)), h("strong", null, turn.providerTurnId), h("span", { className: "focus-history-status" }, turn.status), h("span", { className: "focus-disclosure", "aria-hidden": true }, expanded ? "−" : "+")), expanded ? h("div", { className: "focus-history-details" }, h(DetailList, { copy, turnID: turn.turnId, onInspect })) : null);
}

function DetailList({ copy, turnID, onInspect }: { copy?: AgentSessionCopy; turnID: string; onInspect: (value: string | null) => void }) {
  return h("div", { className: "focus-detail-grid" }, h("div", null, h("h3", null, text(copy, "smartSessionChanged", "Changed")), h("p", null, text(copy, "smartSessionFiles", "Source-linked files are available when captured."))), h("div", null, h("h3", null, text(copy, "smartSessionChecked", "Checked")), h("p", null, text(copy, "smartSessionValidations", "Validation records remain scoped to this turn."))), h("div", null, h("h3", null, text(copy, "smartSessionRemains", "Remains")), h("p", null, text(copy, "smartSessionResume", "Resume point is unavailable unless captured by the producer."))), h("button", { type: "button", className: "focus-inspector-link", onClick: () => onInspect(`turn:${turnID}`) }, text(copy, "smartSessionEvidence", "Inspect evidence")));
}

function RelatedWorkStrip({ copy, snapshot, onInspect }: { copy?: AgentSessionCopy; snapshot: SmartSessionSnapshot; onInspect: (value: string | null) => void }) {
  const related = snapshot.crossSessionAwareness.relatedSessions[0];
  const collision = snapshot.crossSessionAwareness.collisions[0];
  const reason = related?.relationshipReasons[0] ?? text(copy, "smartSessionRelatedWork", "Shared-file activity");
  return h("button", { type: "button", className: "focus-related-strip", onClick: () => onInspect("related") }, h("span", { className: "focus-related-icon", "aria-hidden": true }, "↗"), h("span", null, h("strong", null, text(copy, "smartSessionRelatedWork", "Related work")), h("small", null, `${reason}${collision ? ` · ${collision.path}` : ""}`)), h("span", { className: "focus-related-chevron", "aria-hidden": true }, "›"));
}

function LearningsView({ copy, onInspect }: { copy?: AgentSessionCopy; onInspect: (value: string | null) => void }) {
  return h("div", { className: "focus-reading-column focus-learnings" }, h("div", { className: "focus-learnings-heading" }, h("div", null, h("span", { className: "focus-card-kicker" }, text(copy, "smartSessionLearnings", "Learnings")), h("h2", null, text(copy, "smartSessionNoLearnings", "Useful next time. Grounded in this time."))), h("span", { className: "focus-proposed-badge" }, text(copy, "smartSessionUnavailable", "Unavailable"))), h("div", { className: "focus-empty-panel" }, h("div", { className: "focus-empty-icon", "aria-hidden": true }, "◇"), h("h3", null, text(copy, "smartSessionNoLearnings", "No saved learnings yet")), h("p", null, text(copy, "smartSessionUnavailable", "A knowledge producer and review lifecycle are not connected to this surface. Related-session history remains evidence, not curated knowledge.")), h("button", { type: "button", className: "focus-secondary-button", onClick: () => onInspect("learnings") }, text(copy, "smartSessionEvidence", "View availability"))));
}

function WorkspaceDetails({ copy, snapshot }: { copy?: AgentSessionCopy; snapshot?: SmartSessionSnapshot }) { return h("dl", { className: "focus-inspector-list" }, h("dt", null, text(copy, "smartSessionIdentity", "Identity")), h("dd", null, snapshot?.identity.sessionId ?? text(copy, "smartSessionUnknown", "Unknown")), h("dt", null, text(copy, "smartSessionThread", "Thread")), h("dd", null, snapshot?.identity.providerThreads[0]?.providerThreadId ?? text(copy, "smartSessionUnknown", "Unknown")), h("dt", null, text(copy, "smartSessionRevision", "Revision")), h("dd", null, snapshot?.revision.key ?? text(copy, "smartSessionUnknown", "Unknown"))); }
function Inspector({ title, children, onClose }: { title: string; children: React.ReactNode; onClose: () => void }) { useEffect(() => { const handler = (event: KeyboardEvent) => { if (event.key === "Escape") onClose(); }; document.addEventListener("keydown", handler); return () => document.removeEventListener("keydown", handler); }, [onClose]); return h("div", { className: "focus-inspector-backdrop", role: "presentation", onMouseDown: onClose }, h("aside", { className: "focus-inspector", role: "dialog", "aria-modal": true, "aria-label": title, onMouseDown: event => event.stopPropagation() }, h("header", null, h("h2", null, title), h("button", { type: "button", onClick: onClose, "aria-label": "Close" }, "×")), h("div", { className: "focus-inspector-content" }, children))); }
function SummaryBlock({ label, value }: { label: string; value: string }) { return h("div", { className: "focus-summary-block" }, h("h3", null, label), h("p", null, value)); }
function ViewFrame({ className, children }: { className: string; children: React.ReactNode }) { return h("div", { className: `focus-view-frame ${className}` }, children); }
function UnsupportedView({ copy, kind }: { copy?: AgentSessionCopy; kind: "chat" | "terminal" }) { return h(EmptyState, { message: kind === "chat" ? text(copy, "chatReadOnly", "Chat is unavailable for this identity. Use Terminal for interaction.") : text(copy, "smartSessionUnavailable", "Terminal is unavailable for this identity.") }); }
function EmptyState({ message, action }: { copy?: AgentSessionCopy; message: string; action?: React.ReactNode }) { return h("div", { className: "focus-empty-state" }, h("p", null, message), action ?? null); }
function statusMessage(state: SmartSessionState, copy?: AgentSessionCopy): string { switch (state.status) { case "missingSession": return text(copy, "smartSessionNoSession", "No linked session"); case "failed": return text(copy, "smartSessionFailed", "Session refresh failed"); case "notFound": return text(copy, "smartSessionNotFound", "Session not found"); default: return text(copy, "smartSessionUnavailable", "Session data unavailable"); } }
function statusLabel(status: string, copy?: AgentSessionCopy): string { if (status === "active" || status === "running") return copy?.runningStatus ?? "Running"; if (status === "completed" || status === "complete") return copy?.chatCompleted ?? "Completed"; if (status === "unavailable" || status === "failed") return copy?.failedStatus ?? "Unavailable"; return status || text(copy, "smartSessionUnknown", "Unknown"); }
function latestActivity(turn: SmartSessionTurn, copy?: AgentSessionCopy): string { const command = turn.completedCommands.at(-1); if (command) return `${command.command} · ${command.status}`; const change = turn.fileChangeAttributions.at(-1); return change?.summary ?? change?.paths.join(", ") ?? text(copy, "smartSessionUnknown", "Unknown"); }
function formatTurnDate(value: string): string { const date = new Date(value); return Number.isNaN(date.getTime()) ? value : date.toLocaleString(undefined, { month: "short", day: "numeric", hour: "numeric", minute: "2-digit" }); }
function repositoryName(path?: string): string | undefined { return path?.split(/[\\/]/).filter(Boolean).at(-1); }
function text(copy: AgentSessionCopy | undefined, key: keyof AgentSessionCopy, fallback: string): string { return copy?.[key] ?? fallback; }
