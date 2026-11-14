import React, { useCallback, useEffect, useReducer, useState } from "react";
import { initialSmartSessionState, loadSmartSessionSnapshot, reduceSmartSession, sortSmartSessionTurnReferencesNewestFirst, type SmartSessionState } from "../shared/smartSessionModel";
import type { AgentSessionCopy, AppContext, SmartSessionSnapshot, SmartSessionTurn, SmartSessionTurnReference } from "../shared/types";

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
  return h("div", { className: "focus-workbench", "data-view": view, "data-theme-source": context?.theme.isDark ? "dark" : "light" },
    h(WorkspaceRail, { copy, workspaceName, title: currentTitle, state, onSelect: () => setView("focus") }),
    h("main", { className: "focus-workbench-main" },
      h(WorkspaceHeader, { copy, workspaceName, title: currentTitle, state, onInspect: setInspector, inspector }),
      h(SmartSessionFreshnessBanner, { copy, state, onRefresh: refresh }),
      snapshot ? h(SemanticReportsNotice, { copy, status: snapshot.semanticMessagesReadStatus }) : null,
      h(ViewTabs, { copy, view, onChange: setView }),
      h("div", { className: "focus-workbench-body" },
        view === "focus" ? h(FocusView, { copy, state, onRefresh: refresh, expandedTurnID, onExpandTurn: setExpandedTurnID }) :
          view === "chat" ? h(ViewFrame, { className: "focus-chat-frame", children: renderChat ? renderChat() : h(UnsupportedView, { copy, kind: "chat" }) }) :
            view === "terminal" ? h(ViewFrame, { className: "focus-terminal-frame", children: renderTerminal ? renderTerminal() : h(UnsupportedView, { copy, kind: "terminal" }) }) :
              h(LearningsView, { copy }),
      ),
    ),
  );
}

export function SmartSessionFreshnessBanner({ copy, state, onRefresh }: { copy?: AgentSessionCopy; state: SmartSessionState; onRefresh: () => void }) {
  if (!state.snapshot || state.status === "available") return null;
  return h("div", { role: "status", className: "focus-coverage-note" },
    state.status === "loading" ? text(copy, "smartSessionLoading", "Loading session") : text(copy, "smartSessionStale", "Could not refresh. Showing last known session data."),
    state.lastSuccessfulReadAt && Number.isFinite(Date.parse(state.lastSuccessfulReadAt)) ? ` ${text(copy, "smartSessionLastRead", "Session data last read")}: ${new Date(state.lastSuccessfulReadAt).toLocaleString()}` : null,
    state.status !== "loading" ? h("button", { type: "button", onClick: onRefresh }, text(copy, "smartSessionRefresh", "Refresh")) : null,
  );
}

function WorkspaceRail({ copy, workspaceName, title, state, onSelect }: { copy?: AgentSessionCopy; workspaceName: string; title: string; state: SmartSessionState; onSelect: () => void }) {
  return h("aside", { className: "focus-workspace-rail", "aria-label": text(copy, "smartSessionWorkspace", "Workspace") },
    h("div", { className: "focus-rail-heading" }, h("span", null, text(copy, "smartSessionCurrent", "Current")), h("span", { className: "focus-rail-count" }, "1")),
    h("button", { type: "button", className: "focus-workspace-card is-selected", "aria-pressed": true, onClick: onSelect },
      h("span", { className: "focus-card-repository" }, workspaceName), h("strong", null, title), h("span", { className: "focus-card-status" }, sessionStatusText(state, copy)),
      h("span", { className: "focus-card-activity" }, text(copy, "smartSessionWorkspace", "Workspace")),
    ),
    h("p", { className: "focus-rail-note" }, text(copy, "smartSessionUnavailable", "Workspace links are unavailable for this surface.")),
  );
}

function WorkspaceHeader({ copy, workspaceName, title, state, inspector, onInspect }: { copy?: AgentSessionCopy; workspaceName: string; title: string; state: SmartSessionState; inspector: string | null; onInspect: (value: string | null) => void }) {
  const snapshot = state.snapshot;
  const provider = snapshot?.identity.agentKind ?? "provider";
  return h("header", { className: "focus-workspace-header" },
    h("div", { className: "focus-header-copy" }, h("div", { className: "focus-breadcrumb" }, `${workspaceName} / ${provider}`), h("h1", null, title), snapshot?.identity.sessionId ? h("p", { className: "focus-header-identity" }, `${text(copy, "smartSessionSessionID", "Session ID")}: ${snapshot.identity.sessionId}`) : null),
    h("div", { className: "focus-header-status" }, h("span", null, sessionStatusText(state, copy)), h("button", { type: "button", className: "focus-inspector-link", onClick: () => onInspect("workspace") }, text(copy, "smartSessionIdentity", "Workspace details")), inspector === "workspace" ? h(Inspector, { title: text(copy, "smartSessionIdentity", "Workspace details"), onClose: () => onInspect(null), children: h(WorkspaceDetails, { copy, snapshot }) }) : null),
  );
}

function ViewTabs({ copy, view, onChange }: { copy?: AgentSessionCopy; view: AgentSessionViewMode; onChange: (view: AgentSessionViewMode) => void }) {
  const tabs: Array<[AgentSessionViewMode, string]> = [["focus", text(copy, "smartSessionFocus", "Focus")], ["chat", copy?.terminalView ?? "Chat"], ["terminal", text(copy, "smartSessionTerminal", "Terminal")], ["learnings", text(copy, "smartSessionLearnings", "Learnings")]];
  return h("nav", { className: "focus-view-tabs", role: "tablist", "aria-label": text(copy, "smartSessionWorkspace", "Workspace views") }, ...tabs.map(([id, label]) => h("button", { key: id, type: "button", role: "tab", "aria-selected": view === id, className: `focus-view-tab${view === id ? " is-active" : ""}`, onClick: () => onChange(id) }, label)));
}

function FocusView({ copy, state, onRefresh, expandedTurnID, onExpandTurn }: { copy?: AgentSessionCopy; state: SmartSessionState; onRefresh: () => void; expandedTurnID: string | null; onExpandTurn: (turnID: string | null) => void }) {
  if (state.status === "loading" && !state.snapshot) return h(EmptyState, { message: text(copy, "smartSessionLoading", "Loading session") });
  if (!state.snapshot) return h(EmptyState, { message: statusMessage(state, copy), action: h("button", { type: "button", onClick: onRefresh }, text(copy, "smartSessionRefresh", "Refresh")) });
  const snapshot = state.snapshot;
  const current = snapshot.factual.latestTurn;
  const history = sortSmartSessionTurnReferencesNewestFirst(snapshot.factual.priorTurns);
  const related = snapshot.crossSessionAwareness.status === "available" && (snapshot.crossSessionAwareness.relatedSessions.length > 0 || snapshot.crossSessionAwareness.collisions.length > 0);
  return h("div", { className: "focus-reading-column" },
    current ? h(CurrentTurnCard, { key: JSON.stringify([snapshot.identity.sessionId, current.turnId]), copy, turn: current }) : h(EmptyState, { message: text(copy, "smartSessionNoCurrentTurn", "Latest turn unavailable.") }),
    related ? h(RelatedWorkStrip, { copy, snapshot }) : null,
    h(RelatedAwarenessNotice, { copy, awareness: snapshot.crossSessionAwareness }),
    h("section", { className: "focus-history-section" }, h("div", { className: "focus-section-heading" }, h("h2", null, text(copy, "smartSessionPriorTurns", "History")), h("span", { className: "focus-section-meta" }, `${history.length}`)), history.length ? h("div", { className: "focus-history-list" }, ...history.map(turn => h(PriorTurnCard, { key: turn.turnId, copy, turn, expanded: expandedTurnID === turn.turnId, onToggle: () => onExpandTurn(expandedTurnID === turn.turnId ? null : turn.turnId) }))) : h("p", { className: "focus-muted" }, text(copy, "smartSessionNoEvidence", "No completed turns yet."))),
    snapshot.factual.turnCount > history.length + (current ? 1 : 0) ? h("p", { className: "focus-coverage-note" }, text(copy, "smartSessionUnavailable", "History is partial; only same-identity records are shown.")) : null,
  );
}

function CurrentTurnCard({ copy, turn }: { copy?: AgentSessionCopy; turn: SmartSessionTurn }) {
  const [expanded, setExpanded] = useState(false);
  const [pageState, setPageState] = useState<{ turn?: SmartSessionTurn; page: number }>({ page: 0 });
  const evidenceTurn = pageState.turn ?? turn;
  const recordedEvidence = recordedEvidenceForTurn(turn);
  const fileEntries = (changes: SmartSessionTurn["fileChangeAttributions"]) => changes.flatMap(change => [change.paths.join(", "), change.summary?.trim() ? `${text(copy, "smartSessionRecordedDescription", "Recorded description (unverified)")}: ${change.summary}` : ""]);
  const commandEntries = (commands: SmartSessionTurn["completedCommands"]) => commands.map(command => `${command.command} · ${command.status}`);
  const resultTurn = expanded ? evidenceTurn : turn;
  const results = [...commandEntries(resultTurn.completedCommands.slice(0, 3)), ...fileEntries(resultTurn.fileChangeAttributions.slice(0, 2)), ...resultTurn.assistantMessages.slice(-1).map(message => message.text)].filter(Boolean);
  const commandCount = Math.max(0, evidenceTurn.completedCommands.length - 3);
  const fileCount = Math.max(0, evidenceTurn.fileChangeAttributions.length - 2);
  const messageCount = Math.max(0, evidenceTurn.assistantMessages.length - 1);
  const remainingCount = commandCount + fileCount + messageCount;
  const pageSize = 10;
  const activePage = Math.min(pageState.page, Math.max(0, Math.ceil(remainingCount / pageSize) - 1));
  const pageCount = Math.max(1, Math.ceil(remainingCount / pageSize));
  const pageRecords = expanded ? Array.from({ length: Math.min(pageSize, remainingCount - activePage * pageSize) }, (_, offset) => {
    const index = activePage * pageSize + offset;
    if (index < commandCount) return commandEntries(evidenceTurn.completedCommands.slice(index + 3, index + 4));
    if (index < commandCount + fileCount) return fileEntries(evidenceTurn.fileChangeAttributions.slice(index - commandCount + 2, index - commandCount + 3));
    return [evidenceTurn.assistantMessages[index - commandCount - fileCount]?.text ?? ""];
  }).flat().filter(Boolean) : [];
  return h("article", { className: "focus-current-card" },
    h("div", { className: "focus-card-kicker" }, text(copy, "smartSessionCurrentTurn", "Latest turn"), h("span", { className: `focus-turn-status focus-turn-${turn.status}` }, turn.status)),
    h("h2", null, turn.prompt?.text ?? text(copy, "smartSessionUnknown", "Unknown")),
    h("div", { className: "focus-current-grid" }, h(SummaryBlock, { label: text(copy, "smartSessionLatestTurnPrompt", "Latest turn prompt"), value: turn.prompt?.text ?? text(copy, "smartSessionUnknown", "Unknown") }), h(SummaryBlock, { label: text(copy, "smartSessionRecordedEvidence", "Recorded evidence"), value: recordedEvidence ?? text(copy, "smartSessionUnknown", "Unknown") })),
    h("section", { className: "focus-results" }, h("h3", null, text(copy, "smartSessionFinalOutput", "Evidence")), results.length ? h("ul", null, ...results.map((result, index) => h("li", { key: `${turn.turnId}-${index}` }, result))) : h("p", { className: "focus-muted" }, text(copy, "smartSessionNoEvidence", "No evidence yet.")), (remainingCount > 0 || expanded) ? h("div", null, h("button", { type: "button", className: "focus-secondary-button focus-evidence-disclosure", "aria-expanded": expanded, onClick: () => { setPageState(expanded ? { page: 0 } : { turn, page: 0 }); setExpanded(!expanded); } }, expanded ? text(copy, "smartSessionHideLoadedEvidence", "Hide additional evidence") : text(copy, "smartSessionShowLoadedEvidence", "Show more recorded evidence")), expanded ? h("div", { className: "focus-evidence-page" }, h("p", null, text(copy, "smartSessionEvidenceMayPredate", "This evidence view may predate the latest refresh.")), h("button", { type: "button", className: "focus-secondary-button focus-evidence-update", onClick: () => setPageState({ turn, page: 0 }) }, text(copy, "smartSessionUpdateEvidence", "Update evidence view")), h("ul", null, ...pageRecords.map((result, index) => h("li", { key: `${turn.turnId}-page-${activePage}-${index}` }, result))), h("p", { role: "status", "aria-live": "polite" }, text(copy, "smartSessionEvidencePage", "Page {current} of {total}").replace("{current}", String(activePage + 1)).replace("{total}", String(pageCount))), h("button", { type: "button", className: "focus-secondary-button focus-evidence-previous", "aria-disabled": activePage === 0, onClick: () => { if (activePage > 0) setPageState({ turn: evidenceTurn, page: activePage - 1 }); } }, text(copy, "smartSessionPreviousEvidence", "Previous evidence")), h("button", { type: "button", className: "focus-secondary-button focus-evidence-next", "aria-disabled": activePage + 1 >= pageCount, onClick: () => { if (activePage + 1 < pageCount) setPageState({ turn: evidenceTurn, page: activePage + 1 }); } }, text(copy, "smartSessionNextEvidence", "Next evidence"))) : null) : null),
    h("div", { className: "focus-current-actions" }, h("span", { className: "focus-source-note" }, turn.provider)),
  );
}

function PriorTurnCard({ copy, turn, expanded, onToggle }: { copy?: AgentSessionCopy; turn: SmartSessionTurnReference; expanded: boolean; onToggle: () => void }) {
  return h("article", { className: `focus-history-card${expanded ? " is-expanded" : ""}` }, h("button", { type: "button", className: "focus-history-toggle", "aria-expanded": expanded, onClick: onToggle }, h("span", { className: "focus-history-date" }, formatTurnDate(turn.completedAt ?? turn.startedAt ?? turn.updatedAt)), h("strong", null, turn.providerTurnId), h("span", { className: "focus-history-status" }, turn.status), h("span", { className: "focus-disclosure", "aria-hidden": true }, expanded ? "−" : "+")), expanded ? h("div", { className: "focus-history-details" }, h(DetailList, { copy })) : null);
}

function DetailList({ copy }: { copy?: AgentSessionCopy }) {
  return h("div", { className: "focus-detail-grid" }, h("div", null, h("h3", null, text(copy, "smartSessionChanged", "Changed")), h("p", null, text(copy, "smartSessionFiles", "Source-linked files are available when captured."))), h("div", null, h("h3", null, text(copy, "smartSessionChecked", "Checked")), h("p", null, text(copy, "smartSessionValidations", "Validation records remain scoped to this turn."))), h("div", null, h("h3", null, text(copy, "smartSessionRemains", "Remains")), h("p", null, text(copy, "smartSessionResume", "Resume point is unavailable unless captured by the producer."))));
}

export function SemanticReportsNotice({ copy, status }: { copy?: AgentSessionCopy; status?: "available" | "unavailable" }) {
  return h("p", { role: "status", className: "focus-coverage-note" }, status === "available"
    ? text(copy, "smartSessionReportsIncomplete", "Additional session reports may be incomplete.")
    : text(copy, "smartSessionReportsUnavailable", "Additional session reports are unavailable or unknown."));
}

export function RelatedAwarenessNotice({ copy, awareness }: { copy?: AgentSessionCopy; awareness: SmartSessionSnapshot["crossSessionAwareness"] }) {
  const partial = awareness.relatedReadStatus !== "available" || awareness.collisionReadStatus !== "available";
  const message = awareness.status === "unavailable"
    ? text(copy, "smartSessionRelatedUnavailable", "Related work is unavailable.")
    : partial
      ? text(copy, "smartSessionRelatedPartial", "Some related-work information is incomplete or unavailable. Current state is unknown.")
      : text(copy, "smartSessionRelatedUncertain", "Related work was observed separately and may be incomplete; its current state is unknown.");
  return h("p", { className: "focus-coverage-note" }, message);
}

function RelatedWorkStrip({ copy, snapshot }: { copy?: AgentSessionCopy; snapshot: SmartSessionSnapshot }) {
  const related = snapshot.crossSessionAwareness.relatedSessions[0];
  const collision = snapshot.crossSessionAwareness.collisions[0];
  const reason = related?.relationshipReasons[0] ?? text(copy, "smartSessionRelatedWork", "Shared-file activity");
  return h("div", { className: "focus-related-strip" }, h("span", { className: "focus-related-icon", "aria-hidden": true }, "↗"), h("span", null, h("strong", null, text(copy, "smartSessionRelatedWork", "Related work")), h("small", null, `${reason}${collision ? ` · ${collision.path}` : ""}`)));
}

function LearningsView({ copy }: { copy?: AgentSessionCopy }) {
  return h("div", { className: "focus-reading-column focus-learnings" }, h("div", { className: "focus-learnings-heading" }, h("div", null, h("span", { className: "focus-card-kicker" }, text(copy, "smartSessionLearnings", "Learnings")), h("h2", null, text(copy, "smartSessionNoLearnings", "Useful next time. Grounded in this time."))), h("span", { className: "focus-proposed-badge" }, text(copy, "smartSessionUnavailable", "Unavailable"))), h("div", { className: "focus-empty-panel" }, h("div", { className: "focus-empty-icon", "aria-hidden": true }, "◇"), h("h3", null, text(copy, "smartSessionNoLearnings", "No saved learnings yet")), h("p", null, text(copy, "smartSessionUnavailable", "A knowledge producer and review lifecycle are not connected to this surface. Related-session history remains evidence, not curated knowledge."))));
}

function WorkspaceDetails({ copy, snapshot }: { copy?: AgentSessionCopy; snapshot?: SmartSessionSnapshot }) { return h("dl", { className: "focus-inspector-list" }, h("dt", null, text(copy, "smartSessionIdentity", "Identity")), h("dd", null, snapshot?.identity.sessionId ?? text(copy, "smartSessionUnknown", "Unknown")), h("dt", null, text(copy, "smartSessionThread", "Thread")), h("dd", null, snapshot?.identity.providerThreads[0]?.providerThreadId ?? text(copy, "smartSessionUnknown", "Unknown")), h("dt", null, text(copy, "smartSessionRevision", "Revision")), h("dd", null, snapshot?.revision.key ?? text(copy, "smartSessionUnknown", "Unknown"))); }
function Inspector({ title, children, onClose }: { title: string; children: React.ReactNode; onClose: () => void }) { useEffect(() => { const handler = (event: KeyboardEvent) => { if (event.key === "Escape") onClose(); }; document.addEventListener("keydown", handler); return () => document.removeEventListener("keydown", handler); }, [onClose]); return h("div", { className: "focus-inspector-backdrop", role: "presentation", onMouseDown: onClose }, h("aside", { className: "focus-inspector", role: "dialog", "aria-modal": true, "aria-label": title, onMouseDown: event => event.stopPropagation() }, h("header", null, h("h2", null, title), h("button", { type: "button", onClick: onClose, "aria-label": "Close" }, "×")), h("div", { className: "focus-inspector-content" }, children))); }
function SummaryBlock({ label, value }: { label: string; value: string }) { return h("div", { className: "focus-summary-block" }, h("h3", null, label), h("p", null, value)); }
function ViewFrame({ className, children }: { className: string; children: React.ReactNode }) { return h("div", { className: `focus-view-frame ${className}` }, children); }
function UnsupportedView({ copy, kind }: { copy?: AgentSessionCopy; kind: "chat" | "terminal" }) { return h(EmptyState, { message: kind === "chat" ? text(copy, "chatReadOnly", "Chat is unavailable for this identity. Use Terminal for interaction.") : text(copy, "smartSessionUnavailable", "Terminal is unavailable for this identity.") }); }
function EmptyState({ message, action }: { copy?: AgentSessionCopy; message: string; action?: React.ReactNode }) { return h("div", { className: "focus-empty-state" }, h("p", null, message), action ?? null); }
function statusMessage(state: SmartSessionState, copy?: AgentSessionCopy): string { switch (state.status) { case "missingSession": return text(copy, "smartSessionNoSession", "No linked session"); case "failed": return text(copy, "smartSessionFailed", "Session refresh failed"); case "notFound": return text(copy, "smartSessionNotFound", "Session not found"); default: return text(copy, "smartSessionUnavailable", "Session data unavailable"); } }
function sessionStatusText(state: SmartSessionState, copy?: AgentSessionCopy): string { const status = state.snapshot?.identity.status; return status ? `${text(copy, "smartSessionLastReportedStatus", "Last reported status")}: ${statusLabel(status, copy)}` : state.status === "loading" ? text(copy, "smartSessionLoading", "Loading session") : statusMessage(state, copy); }
function statusLabel(status: string, copy?: AgentSessionCopy): string { if (status === "active" || status === "running") return copy?.runningStatus ?? "Running"; if (status === "completed" || status === "complete") return copy?.chatCompleted ?? "Completed"; if (status === "unavailable" || status === "failed") return copy?.failedStatus ?? "Unavailable"; return status || text(copy, "smartSessionUnknown", "Unknown"); }
function recordedEvidenceForTurn(turn: SmartSessionTurn): string | undefined { const command = turn.completedCommands.at(-1); if (command) return `${command.command} · ${command.status}`; return turn.fileChangeAttributions.at(-1)?.paths.join(", ") || undefined; }
function formatTurnDate(value: string): string { const date = new Date(value); return Number.isNaN(date.getTime()) ? value : date.toLocaleString(undefined, { month: "short", day: "numeric", hour: "numeric", minute: "2-digit" }); }
function repositoryName(path?: string): string | undefined { return path?.split(/[\\/]/).filter(Boolean).at(-1); }
function text(copy: AgentSessionCopy | undefined, key: keyof AgentSessionCopy, fallback: string): string { return copy?.[key] ?? fallback; }
