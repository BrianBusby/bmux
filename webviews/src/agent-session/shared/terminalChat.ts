import type { ConnectedControl } from "./connectedChat";
/** Ordinary CLI observation never confers authority to write to its PTY. */
export type SessionControlOperation = "readConversation" | "submitPrompt" | "steerTurn" | "queueFollowUp" | "interruptTurn" | "answerApproval" | "answerQuestion" | "changeSettings";
export type SessionCapability = { available: boolean; reason?: "noAttachedControlTransport" | "historyUnavailable" };
export type ObservedMessage = {
  id: string;
  seq: number;
  role: string;
  kind: {
    [key: string]: unknown;
    output_metadata?: { raw_output_ref?: string };
    type: string;
    text?: string;
    command?: string;
    output?: string;
    summary?: string;
    input_detail?: string;
    tool_name?: string;
    status?: string;
    is_running?: boolean;
    exit_code?: number;
    file_path?: string;
    unified_diff?: string;
  };
};
export type ObservedTurn = { id: string; state: "working" | "completed" | "interrupted" };
export type TerminalChatSnapshot = {
  control?: ConnectedControl;
  status: "observed" | "ended" | "unavailable";
  reason?: "ambiguous" | "unassociated" | "historyUnavailable";
  sessionId?: string;
  workspaceId?: string;
  surfaceId?: string;
  history?: { messages: ObservedMessage[]; has_more: boolean; observed_turn?: ObservedTurn; source_revision?: string };
};
export type TerminalChatState = {
  control?: ConnectedControl;
  status: "loading" | "observed" | "ended" | "stale" | "unavailable";
  sessionId?: string;
  messages: ObservedMessage[];
  partial: boolean;
  observedTurn?: ObservedTurn;
  sourceRevision?: string;
  reason?: "ambiguous" | "unassociated" | "historyUnavailable";
};
export const initialTerminalChat: TerminalChatState = { status: "loading", messages: [], partial: false };
export function terminalCapabilities(historyAvailable: boolean): Record<SessionControlOperation, SessionCapability> {
  const unavailable: SessionCapability = { available: false, reason: "noAttachedControlTransport" };
  return {
    readConversation: historyAvailable ? { available: true } : { available: false, reason: "historyUnavailable" },
    submitPrompt: unavailable, steerTurn: unavailable, queueFollowUp: unavailable,
    interruptTurn: unavailable, answerApproval: unavailable, answerQuestion: unavailable, changeSettings: unavailable,
  };
}
/** Full bounded snapshots replace the window, including after truncation; never append a replay. */
export function reconcileTerminalChat(previous: TerminalChatState, snapshot: TerminalChatSnapshot, scope: { workspaceId: string; panelId: string }): TerminalChatState {
  const control = snapshot.workspaceId === scope.workspaceId && snapshot.surfaceId === scope.panelId &&
    snapshot.control?.threadId === snapshot.sessionId ? snapshot.control : undefined;
  if (snapshot.reason === "ambiguous" || snapshot.reason === "unassociated") {
    return { ...initialTerminalChat, status: "unavailable", reason: snapshot.reason, control, sessionId: control?.threadId };
  }
  if (!snapshot.history || !snapshot.sessionId || snapshot.status === "unavailable") {
    const cached = control && previous.sessionId !== control.threadId ? initialTerminalChat : previous;
    return { ...cached, control, sessionId: control?.threadId ?? cached.sessionId, status: cached.messages.length ? "stale" : "unavailable" };
  }
  if (snapshot.workspaceId !== scope.workspaceId || snapshot.surfaceId !== scope.panelId) {
    return { ...initialTerminalChat, status: "unavailable" };
  }
  const byId = new Map(snapshot.history.messages.map(message => [message.id, message]));
  const ordered = [...byId.values()].sort((a, b) => a.seq - b.seq);
  return {
    status: snapshot.status, control, sessionId: snapshot.sessionId, observedTurn: snapshot.history.observed_turn, sourceRevision: snapshot.history.source_revision,
    messages: ordered.slice(-500), partial: snapshot.history.has_more || ordered.length > 500,
  };
}
