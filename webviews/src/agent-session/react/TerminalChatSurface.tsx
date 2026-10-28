/* oxlint-disable jsx-a11y/no-noninteractive-tabindex -- The scrollable history region must be keyboard reachable. */
import React, { useEffect, useLayoutEffect, useRef, useState } from "react";
import { callNative } from "../shared/bridge";
import { renderMarkdownHTML } from "../shared/markdown";
import { initialTerminalChat, reconcileTerminalChat, terminalCapabilities, type ObservedMessage, type TerminalChatSnapshot } from "../shared/terminalChat";
import { ConnectedChatComposer } from "./ConnectedChatComposer";
import { canUseConnectedControl } from "../shared/connectedChat";
import { turnProgressReports } from "../shared/terminalTurnProgress";
import { TerminalTurnProgress } from "./TerminalTurnProgress";
import type { AppContext } from "../shared/types";


export function TerminalChatSurface({ context }: { context: AppContext }) {
  const [state, setState] = useState(initialTerminalChat);
  const [starting, setStarting] = useState(false);
  const [startFailed, setStartFailed] = useState(false);
  const [viewMode, setViewMode] = useState<"chat" | "turn">(context.terminalChatMode ?? "chat");
  const scroll = useRef<HTMLDivElement>(null);
  const following = useRef(true);
  const automaticStartAttempted = useRef(false);
  const pendingActivityRow = useRef<string | undefined>(undefined);
  const copy = context.copy;
  useEffect(() => {
    const onMode = (event: Event) => setViewMode((event as CustomEvent<{ mode: "chat" | "turn" }>).detail.mode);
    window.addEventListener("bmux-terminal-chat-mode", onMode);
    return () => window.removeEventListener("bmux-terminal-chat-mode", onMode);
  }, []);
  useEffect(() => {
    let cancelled = false;
    let visible = true;
    let timer: ReturnType<typeof setTimeout>;
    const onVisibility = (event: Event) => {
      visible = (event as CustomEvent<{ visible: boolean }>).detail.visible;
      clearTimeout(timer);
      if (visible && !cancelled) void refresh();
    };
    const refresh = async () => {
      if (!visible) return;
      try {
        const snapshot = await callNative<TerminalChatSnapshot>("terminalChat.snapshot");
        if (!cancelled) setState(previous => reconcileTerminalChat(previous, snapshot, context));
      } catch {
        if (!cancelled) setState(previous => ({ ...previous, control: undefined, status: previous.messages.length ? "stale" : "unavailable" }));
      }
      // One outstanding read at a time; never retry provider actions.
      if (!cancelled && visible) timer = setTimeout(refresh, 2000);
    };
    window.addEventListener("bmux-terminal-chat-visibility", onVisibility);
    void refresh();
    return () => { cancelled = true; clearTimeout(timer); window.removeEventListener("bmux-terminal-chat-visibility", onVisibility); };
  }, [context]);
  useEffect(() => {
    if (viewMode !== "chat" || !context.automaticallyStartConnectedSession || !context.canStartConnectedSession ||
      state.status !== "unavailable" || state.control || state.sessionId || state.reason === "ambiguous" ||
      automaticStartAttempted.current) return;
    automaticStartAttempted.current = true;
    setStarting(true);
    void callNative("terminalChat.startConnected", { automatic: true })
      .catch(() => setStartFailed(true)).finally(() => setStarting(false));
  }, [context, viewMode, state.status, state.control, state.sessionId, state.reason]);
  useLayoutEffect(() => {
    if (following.current && scroll.current) scroll.current.scrollTop = scroll.current.scrollHeight;
  }, [state.messages]);
  const capabilities = terminalCapabilities(state.status === "observed" || state.status === "ended");
  const reports = turnProgressReports(state.messages, state.observedTurn, state.partial);
  const latest = reports.at(-1);
  const active = latest && (latest.progress.state === "working" || latest.progress.state === "unknown") ? latest : undefined;
  const pastReports = new Map(reports.filter(report => report !== active).map(report => [report.promptIndex, report.progress]));
  const openActivity = (messageId: string) => {
    pendingActivityRow.current = messageId;
    if (viewMode === "turn") void callNative("terminalChat.openChat").catch(() => { pendingActivityRow.current = undefined; });
    else document.getElementById(`terminal-chat-row-${messageId}`)?.scrollIntoView?.({ block: "center", behavior: "smooth" });
  };
  useLayoutEffect(() => {
    if (viewMode !== "chat" || !pendingActivityRow.current) return;
    document.getElementById(`terminal-chat-row-${pendingActivityRow.current}`)?.scrollIntoView?.({ block: "center", behavior: "smooth" });
    pendingActivityRow.current = undefined;
  }, [viewMode, state.messages]);
  const historyNotice = state.reason === "ambiguous" ? copy.chatAmbiguous :
    state.status === "stale" ? copy.chatStale : undefined;
  if (viewMode === "turn") return <section className="terminal-chat terminal-turn-tab">
    <div className="terminal-turn-tab-content">
      {historyNotice && <output className="terminal-chat-notice">{historyNotice}</output>}
      {active ? <TerminalTurnProgress key={state.messages[active.promptIndex]?.id} progress={active.progress} copy={copy} onOpenActivity={openActivity} /> :
        <p className="terminal-turn-tab-empty">{latest ? copy.chatReportInChat : copy.chatNoActiveTurn}</p>}
    </div>
  </section>;
  return <section className="terminal-chat">
    <section className="terminal-chat-history" ref={scroll} tabIndex={0} aria-label={copy.chatConversation}
      onScroll={() => { const node = scroll.current; if (node) following.current = node.scrollHeight - node.scrollTop - node.clientHeight < 48; }}>
      {historyNotice && <output className="terminal-chat-notice">{historyNotice}</output>}
      {state.partial && <p className="terminal-chat-notice">{copy.chatPartial}</p>}
      <div className="terminal-chat-messages" key={`${state.sessionId}:${state.sourceRevision}`}>
        {state.messages.map((message, index) => <React.Fragment key={message.id}>
          <span id={`terminal-chat-row-${message.id}`} className="terminal-chat-row-anchor" aria-hidden="true" />
          <ObservedRow message={message} context={context} sessionId={state.sessionId!} />
          {pastReports.has(index) && <TerminalTurnProgress progress={pastReports.get(index)!} copy={copy} onOpenActivity={openActivity} />}
        </React.Fragment>)}
      </div>
    </section>
    {state.control ? <ConnectedChatComposer context={context} control={state.control}
      enabled={canUseConnectedControl(state.control, state.sessionId)} /> :
      !capabilities.submitPrompt.available && <footer className="terminal-chat-footer">{state.status === "loading" ? copy.chatLoading : starting ? copy.startingStatus : copy.chatReadOnly}</footer>}
    {context.canStartConnectedSession && state.status !== "loading" && !state.control && <div className="terminal-chat-launch">
      <button disabled={starting} onClick={() => {
        setStarting(true); setStartFailed(false);
        void callNative("terminalChat.startConnected").catch(() => setStartFailed(true)).finally(() => setStarting(false));
      }}>{starting ? copy.startingStatus : copy.connectedNewSession}</button>
      {startFailed && <output role="alert">{copy.connectedStartFailed}</output>}
    </div>}
  </section>;
}

function ObservedRow({ message, context, sessionId }: { message: ObservedMessage; context: AppContext; sessionId: string }) {
  const { kind } = message;
  const copy = context.copy;
  const [limit, setLimit] = useState(8192);
  const [raw, setRaw] = useState<string>();
  const [rawFailed, setRawFailed] = useState(false);
  if (kind.type === "prose") {
    return <article className={`terminal-chat-message terminal-chat-${message.role}`}>
      <span className="terminal-chat-role">{message.role === "user" ? copy.chatUser : copy.chatAssistant}</span>
      {message.role === "user" ? <div className="terminal-chat-prose">{kind.text?.slice(0, limit)}</div> :
        <div className="terminal-chat-prose" dangerouslySetInnerHTML={{ __html: renderMarkdownHTML((kind.text ?? "").slice(0, limit)) }} />}
      {(kind.text?.length ?? 0) > limit && <button onClick={() => setLimit(value => value + 16384)}>{copy.showMore}</button>}
    </article>;
  }
  // Internal reasoning is not promoted into a conversation message.
  if (kind.type === "thought") return null;
  if (kind.type === "status") return kind.event === "interrupted" ? <p className="terminal-chat-notice">{copy.chatInterrupted}</p> : null;
  const title = kind.command ?? kind.summary ?? kind.file_path ?? kind.tool_name ?? copy.chatActivity;
  const output = raw ?? kind.output ?? kind.unified_diff ?? kind.input_detail ?? kind.text ?? JSON.stringify(kind, null, 2);
  const status = kind.status === "failed" || (kind.exit_code !== undefined && kind.exit_code !== 0) ? copy.chatFailed :
    kind.status === "succeeded" || kind.exit_code === 0 ? copy.chatCompleted :
    kind.is_running || kind.status === "running" ? copy.chatAwaitingResult : copy.chatUnknown;
  return <details className="terminal-chat-tool">
    <summary><span>{title}</span><span className="terminal-chat-tool-status">{status}</span></summary>
    <pre>{output.slice(0, limit)}</pre>
    {kind.output_metadata?.raw_output_ref && raw === undefined && <button onClick={() => {
      void callNative<{ output: string }>("terminalChat.rawOutput", { sessionId, messageId: message.id })
        .then(result => { setRaw(result.output); setRawFailed(false); }).catch(() => setRawFailed(true));
    }}>{copy.showRawOutput}</button>}
    {rawFailed && <output>{copy.rawOutputUnavailable}</output>}
    {output.length > limit && <button onClick={() => setLimit(value => value + 16384)}>{copy.showMore}</button>}
    {(kind.type === "permission_request" || kind.type === "question") && <p>{copy.chatInteract}</p>}
  </details>;
}
