import { isComposingEnter, type ComposingEnterEvent } from "./keyboard";

export type ConnectedAction = {
  id: string;
  threadID: string;
  operation: "queue" | "steer";
  expectedTurnID?: string;
  text: string;
  delivery: "pending" | "accepted" | "failed" | "uncertain";
  providerID?: string;
};
export type ConnectedControl = {
  threadId: string;
  status: "connected" | "unavailable";
  queueFollowUp?: boolean;
  steerTurn?: boolean;
  activeTurnId?: string;
  actions?: ConnectedAction[];
  draft?: { revision: string; text: string };
};

export function shouldSubmitConnectedChatOnEnter(event: ComposingEnterEvent & { altKey?: boolean; shiftKey?: boolean }): boolean {
  return event.key === "Enter" && !event.altKey && !event.shiftKey && !isComposingEnter(event);
}

/** Only the verified connection may enable a mutation; transcript activity cannot. */
export function canUseConnectedControl(control: ConnectedControl | undefined, sessionId: string | undefined): boolean {
  return control?.status === "connected" && control.threadId === sessionId;
}
