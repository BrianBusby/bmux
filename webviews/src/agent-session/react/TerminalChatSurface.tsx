/* oxlint-disable jsx-a11y/no-noninteractive-tabindex -- The scrollable history region must be keyboard reachable. */
import React, { useEffect, useLayoutEffect, useRef, useState } from "react";
import { callNative } from "../shared/bridge";
import { renderMarkdownHTML } from "../shared/markdown";
import { initialTerminalChat, reconcileTerminalChat, terminalCapabilities, type ObservedMessage, type TerminalChatSnapshot } from "../shared/terminalChat";
import type { AppContext } from "../shared/types";


export function TerminalChatSurface({ context }: { context: AppContext }) {
  const [state, setState] = useState(initialTerminalChat);
  const scroll = useRef<HTMLDivElement>(null);
  const following = useRef(true);
  const copy = context.copy;
  useEffect(() => {
    let cancelled = false;
    let timer: ReturnType<typeof setTimeout>;
    const refresh = async () => {
      try {
        const snapshot = await callNative<TerminalChatSnapshot>("terminalChat.snapshot");
        if (!cancelled) setState(previous => reconcileTerminalChat(previous, snapshot, context));
      } catch {
        if (!cancelled) setState(previous => ({ ...previous, status: previous.messages.length ? "stale" : "unavailable" }));
      }
      // One outstanding read at a time; never retry provider actions.
      if (!cancelled) timer = setTimeout(refresh, 2000);
    };
    void refresh();
    return () => { cancelled = true; clearTimeout(timer); };
  }, [context]);
  useLayoutEffect(() => {
    if (following.current && scroll.current) scroll.current.scrollTop = scroll.current.scrollHeight;
  }, [state.messages]);
  const capabilities = terminalCapabilities(state.status === "observed" || state.status === "ended");
  const statuses = { loading: copy.chatLoading, observed: copy.chatObserved, ended: copy.chatEnded, stale: copy.chatStale, unavailable: copy.chatUnavailable };
  const turnStatus = state.status === "observed" && state.observedTurn ? {
    working: copy.runningStatus, completed: copy.chatCompleted, interrupted: copy.chatInterrupted,
  }[state.observedTurn.state] : undefined;
  return <section className="terminal-chat">
    <header className="terminal-chat-header"><output>{state.reason === "ambiguous" ? copy.chatAmbiguous : turnStatus ?? statuses[state.status]}</output>
      <button onClick={() => void callNative("terminalChat.openTerminal")}>{copy.chatInteract}</button>
    </header>
    <section className="terminal-chat-history" ref={scroll} tabIndex={0} aria-label={copy.chatConversation}
      onScroll={() => { const node = scroll.current; if (node) following.current = node.scrollHeight - node.scrollTop - node.clientHeight < 48; }}>
      {state.partial && <p className="terminal-chat-notice">{copy.chatPartial}</p>}
      <div className="terminal-chat-messages" key={`${state.sessionId}:${state.sourceRevision}`}>
        {state.messages.map(message => <ObservedRow key={message.id} message={message} context={context} sessionId={state.sessionId!} />)}
      </div>
    </section>
    {!capabilities.submitPrompt.available && <footer className="terminal-chat-footer">{copy.chatReadOnly}</footer>}
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
