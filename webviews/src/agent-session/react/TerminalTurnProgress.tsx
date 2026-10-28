import React, { useEffect, useState } from "react";
import type { AgentSessionCopy } from "../shared/types";
import type { ObservedMessage } from "../shared/terminalChat";
import { chronologicalActivity, reportedStepState, visibleStepIndexes, type TurnProgressSnapshot } from "../shared/terminalTurnProgress";

function elapsed(value: string | undefined, now: number): string | undefined {
  if (!value) return undefined;
  const start = Date.parse(value);
  if (!Number.isFinite(start) || start > now) return undefined;
  const seconds = Math.floor((now - start) / 1000);
  return seconds < 60 ? `${seconds}s` : `${Math.floor(seconds / 60)}m`;
}

function title(message: ObservedMessage, copy: AgentSessionCopy): string {
  const { kind } = message;
  if (kind.type === "prose") return message.role === "assistant" ? copy.chatAssistant ?? "" : copy.chatUser ?? "";
  if (kind.type === "status") return copy.chatInterrupted ?? "";
  return kind.command ?? kind.summary ?? kind.file_path ?? kind.tool_name ?? copy.chatActivity ?? "";
}

export function TerminalTurnProgress({ progress, copy }: { progress: TurnProgressSnapshot; copy: AgentSessionCopy }) {
  const [expanded, setExpanded] = useState(progress.state !== "completed");
  const [showAll, setShowAll] = useState(false);
  const [showActivity, setShowActivity] = useState(false);
  const [now, setNow] = useState(Date.now());
  useEffect(() => {
    if (progress.state !== "working") return;
    const timer = setInterval(() => setNow(Date.now()), 10000);
    return () => clearInterval(timer);
  }, [progress.state]);
  const plan = progress.plan;
  const steps = plan?.steps ?? [];
  const visible = showAll ? steps.map((_, index) => index) : visibleStepIndexes(steps);
  const running = progress.activity.filter(message => message.kind.is_running || message.kind.status === "running");
  const failed = progress.activity.at(-1);
  const showFailure = failed && (failed.kind.status === "failed" || failed.kind.exit_code !== undefined && failed.kind.exit_code !== 0);
  const stateLabel = progress.state === "completed" ? copy.chatCompleted : progress.state === "interrupted" ? copy.chatInterrupted : progress.state === "working" ? copy.chatWorking : copy.chatUnknown;
  const groups = chronologicalActivity(progress.timeline);
  const commandCount = progress.activity.filter(message => ["terminal", "tool_use", "file_edit"].includes(message.kind.type)).length;
  const changedFileCount = new Set(progress.activity.filter(message => message.kind.type === "file_edit" && message.kind.file_path).map(message => message.kind.file_path)).size;
  return <section className="terminal-turn-progress" aria-label={copy.chatTurnProgress}>
    <button className="terminal-turn-progress-toggle" type="button" aria-expanded={expanded} onClick={() => setExpanded(!expanded)}>
      <strong>{copy.chatTurnProgress}</strong><span>{stateLabel}{progress.state === "working" && elapsed(progress.startedAt, now) ? ` · ${elapsed(progress.startedAt, now)}` : ""}</span>
    </button>
    {expanded && <>
      <div className="terminal-turn-progress-content">
        {plan ? <>
          {!showAll && visible[0] > 0 && <p className="terminal-turn-omitted">{visible[0]} {copy.chatEarlierSteps}</p>}
          <ol className="terminal-turn-plan">{visible.map(index => {
            const step = steps[index];
            const state = reportedStepState(step.status);
            const status = state === "unknown" ? `${copy.chatUnknown}: ${step.status}` : ({ done: copy.chatCompleted, active: copy.chatPlanActive, upcoming: copy.chatPlanUpcoming, blocked: copy.chatPlanBlocked, skipped: copy.chatPlanSkipped })[state];
            return <li key={index} className={`terminal-turn-step terminal-turn-step-${state}`} title={status}><span aria-hidden="true">{state === "done" ? "✓" : state === "active" ? "●" : "○"}</span><span>{step.text}{state === "unknown" && <small className="terminal-turn-unknown">{status}</small>}</span>{state !== "unknown" && <span className="sr-only">{status}</span>}</li>;
          })}</ol>
          {!showAll && visible.length < steps.length && <button type="button" className="terminal-turn-show-all" onClick={() => setShowAll(true)}>{copy.chatShowAll} {steps.length}</button>}
        </> : <p className="terminal-turn-no-plan">{progress.partial ? copy.chatPlanNotLoaded : copy.chatNoPlanReported}</p>}
        {progress.state === "working" && <div className="terminal-turn-current"><strong>{copy.chatCurrentActivity}</strong>
          {running.length ? running.map(message => <p key={message.id}><span aria-hidden="true">●</span> {title(message, copy)}{elapsed(message.timestamp, now) ? ` · ${elapsed(message.timestamp, now)}` : ""}</p>) : !showFailure && <p>{copy.chatNoCommandRunning}</p>}
          {showFailure && <p className="terminal-turn-failed">{title(failed, copy)}{failed.kind.exit_code !== undefined ? ` · ${copy.chatExitCode} ${failed.kind.exit_code}` : ""}</p>}
        </div>}
      </div>
      <div className="terminal-turn-footer">
        <button type="button" className="terminal-turn-activity-toggle" aria-expanded={showActivity} onClick={() => setShowActivity(!showActivity)}>{copy.chatActivity} <span>{commandCount} {copy.chatCommands}{running.length ? ` · ${running.length} ${copy.chatRunning}` : ""}</span><span aria-hidden="true">{showActivity ? "⌃" : "⌄"}</span></button>
        <span className="terminal-turn-footer-meta">{changedFileCount ? `${changedFileCount} ${copy.chatFilesChanged} · ` : ""}{plan ? `${copy.chatPlan} · ${plan.source}` : copy.chatNoPlanReported}{plan && progress.plans.length > 1 ? ` · ${progress.plans.length} ${copy.chatUpdates}` : ""}{plan && elapsed(plan.timestamp, now) ? ` · ${elapsed(plan.timestamp, now)} ${copy.chatAgo}` : ""}</span>
      </div>
      {showActivity && <div className="terminal-turn-activity-list" aria-label={copy.chatActivity}>
        {groups.map((group, index) => <button type="button" key={index} onClick={() => document.getElementById(`terminal-chat-row-${group[0].id}`)?.scrollIntoView({ block: "center", behavior: "smooth" })}><span aria-hidden="true">{group.some(message => message.kind.status === "failed") ? "!" : "•"}</span><span>{group.length > 1 ? `${group.length} ${copy.chatReadCommands}` : title(group[0], copy)}</span><small>{elapsed(group.at(-1)?.timestamp, now)}</small></button>)}
        {progress.plans.length > 1 && <div className="terminal-turn-plan-history"><strong>{copy.chatPlanUpdates}</strong>{progress.plans.slice(0, -1).map((earlier, index) => <p key={earlier.messageId}>{index + 1}. {earlier.steps.length} {copy.chatSteps}{earlier.explanation ? ` · ${earlier.explanation}` : ""}</p>)}</div>}
      </div>}
    </>}
  </section>;
}
