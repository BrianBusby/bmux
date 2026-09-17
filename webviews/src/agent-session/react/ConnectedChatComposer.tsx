import React, { useEffect, useRef, useState } from "react";
import { callNative } from "../shared/bridge";
import type { AppContext } from "../shared/types";
import { shouldSubmitConnectedChatOnEnter, type ConnectedAction, type ConnectedControl } from "../shared/connectedChat";

/** Draft state remains in the panel's retained webview across view switches. */
export function ConnectedChatComposer({ context, control, enabled }: { context: AppContext; control: ConnectedControl; enabled: boolean }) {
  const [draft, setDraft] = useState(() => {
    const last = control.actions?.at(-1);
    return control.draft?.text ?? (last && last.delivery !== "accepted" ? last.text : "");
  });
  const revision = useRef(control.draft?.revision ?? crypto.randomUUID());
  const [action, setAction] = useState<(ConnectedAction & { draftRevision?: string })>();
  const inFlight = useRef(false);
  const [sending, setSending] = useState(false);
  const copy = context.copy;
  const observed = action && control.actions?.find(item => item.id.toLowerCase() === action.id.toLowerCase());
  const latest = observed ?? action ?? control.actions?.at(-1);
  const submittedRevision = action?.id.toLowerCase() === latest?.id.toLowerCase() ? action.draftRevision : undefined;
  const previousReceipt = useRef(latest);
  useEffect(() => {
    const previous = previousReceipt.current;
    previousReceipt.current = latest;
    // An accepted historical action must not erase a newly restored draft.
    if (latest?.delivery === "accepted" && previous?.id === latest.id && previous.delivery !== "accepted") {
      if (submittedRevision === revision.current) setDraft("");
    }
  }, [latest]);
  const blocked = sending || latest?.delivery === "pending" || latest?.delivery === "uncertain";
  const slashCommand = draft.trimStart().startsWith("/");
  const submit = async (operation: "queue" | "steer") => {
    if (inFlight.current || !enabled || blocked || !draft.trim() || slashCommand) return;
    const request: ConnectedAction & { draftRevision: string } = { id: crypto.randomUUID(), threadID: control.threadId, operation, text: draft, draftRevision: revision.current,
      expectedTurnID: operation === "steer" ? control.activeTurnId : undefined, delivery: "pending" };
    inFlight.current = true;
    setAction(request);
    setSending(true);
    try {
      const result = await callNative<ConnectedAction>("terminalChat.action", { requestId: request.id,
        sessionId: request.threadID, draftRevision: request.draftRevision, text: request.text, expectedTurnId: request.expectedTurnID });
      setAction(result);
      if (result.delivery === "accepted" && revision.current === request.draftRevision) setDraft("");
    } catch {
      // A lost bridge reply is not proof of a failed native/provider mutation.
      setAction({ ...request, delivery: "uncertain" });
    } finally { inFlight.current = false; setSending(false); }
  };
  const updateDraft = (text: string) => {
    setDraft(text);
    revision.current = crypto.randomUUID();
    void callNative("terminalChat.draft", { sessionId: control.threadId, draftRevision: revision.current, text }).catch(() => {
      // Keep the local draft if the native consumer is unavailable.
    });
  };
  const deliveryCopy = { pending: copy.connectedPending, accepted: copy.connectedAccepted,
    failed: copy.connectedFailed, uncertain: copy.connectedUncertain };
  return <footer className="terminal-chat-composer">
    <label htmlFor="connected-chat-draft">{copy.connectedPrompt}</label>
    <textarea aria-label={copy.connectedPrompt} id="connected-chat-draft" value={draft} onChange={event => updateDraft(event.target.value)}
      onKeyDown={event => {
        if (!shouldSubmitConnectedChatOnEnter(event.nativeEvent)) return;
        event.preventDefault();
        void submit("queue");
      }} rows={2} maxLength={16000} />
    <div className="terminal-chat-composer-actions">
      <button disabled={!enabled || !control.queueFollowUp || blocked || !draft.trim() || slashCommand} onClick={() => void submit("queue")}>{copy.connectedQueue}</button>
      {control.steerTurn && <button disabled={!enabled || blocked || !draft.trim() || slashCommand} onClick={() => void submit("steer")}>{copy.connectedSteer}</button>}
      <button onClick={() => void callNative("terminalChat.openTerminal")}>{copy.chatInteract}</button>
    </div>
    {latest && <output aria-live="polite">{deliveryCopy[latest.delivery]}</output>}
    <p>{slashCommand ? copy.connectedSlashCommands : enabled ? copy.connectedQueuePolicy : copy.connectedUnavailable}</p>
  </footer>;
}
