import React, { useEffect, useRef, useState } from "react";
import type { AgentSessionCopy } from "../shared/types";
import type { ObservedMessage } from "../shared/terminalChat";
import { chronologicalActivity, planChangeCounts, reportedStepState, visibleStepIndexes, type TurnProgressSnapshot } from "../shared/terminalTurnProgress";

function elapsed(value: string | undefined, now: number): string | undefined {
  if (!value) return undefined;
  const start = Date.parse(value);
  if (!Number.isFinite(start) || start > now) return undefined;
  const seconds = Math.floor((now - start) / 1000);
  return seconds < 60 ? `${seconds}s` : `${Math.floor(seconds / 60)}m`;
}

function duration(startValue: string | undefined, endValue: string | undefined): string | undefined {
  if (!startValue || !endValue) return undefined;
  const start = Date.parse(startValue);
  const end = Date.parse(endValue);
  if (!Number.isFinite(start) || !Number.isFinite(end) || end < start) return undefined;
  const seconds = Math.floor((end - start) / 1000);
  return seconds < 60 ? `${seconds}s` : `${Math.floor(seconds / 60)}m`;
}

function title(message: ObservedMessage, copy: AgentSessionCopy): string {
  const { kind } = message;
  if (kind.type === "prose") return message.role === "assistant" ? copy.chatAssistant ?? "" : copy.chatUser ?? "";
  if (kind.type === "status") return copy.chatInterrupted ?? "";
  return kind.command ?? kind.summary ?? kind.file_path ?? kind.tool_name ?? copy.chatActivity ?? "";
}

export function TerminalTurnProgress({ progress, copy, onOpenActivity }: { progress: TurnProgressSnapshot; copy: AgentSessionCopy; onOpenActivity?: (messageId: string) => void }) {
  const [expanded, setExpanded] = useState(progress.state === "working" || progress.state === "unknown");
  const [showAll, setShowAll] = useState(false);
  const [showActivity, setShowActivity] = useState(false);
  const [showWhy, setShowWhy] = useState(false);
  const [showHistory, setShowHistory] = useState(false);
  const [openStep, setOpenStep] = useState<number | null>(null);
  const [now, setNow] = useState(Date.now());
  const activityToggle = useRef<HTMLButtonElement>(null);
  useEffect(() => {
    if (progress.state !== "working") return;
    const timer = setInterval(() => setNow(Date.now()), 10000);
    return () => clearInterval(timer);
  }, [progress.state]);
  const plan = progress.plan;
  const steps = plan?.steps ?? [];
  const visible = showAll ? steps.map((_, index) => index) : visibleStepIndexes(steps);
  const running = progress.activity.filter(message => message.kind.is_running || message.kind.status === "running");
  const failed = [...progress.activity].reverse().find(message => message.kind.status === "failed" || message.kind.exit_code !== undefined && message.kind.exit_code !== 0);
  const stateLabel = progress.state === "completed" ? copy.chatCompleted : progress.state === "ended" ? copy.chatTurnEnded : progress.state === "interrupted" ? copy.chatInterrupted : progress.state === "working" ? copy.chatWorking : copy.chatUnknown;
  const groups = chronologicalActivity(progress.timeline);
  const commandCount = progress.activity.filter(message => ["terminal", "tool_use", "file_edit"].includes(message.kind.type)).length;
  const failedCount = progress.activity.filter(message => message.kind.status === "failed" || message.kind.exit_code !== undefined && message.kind.exit_code !== 0).length;
  const activeStepCount = steps.filter(step => reportedStepState(step.status) === "active").length;
  const changedFileCount = new Set(progress.activity.filter(message => message.kind.type === "file_edit" && message.kind.file_path).map(message => message.kind.file_path)).size;
  const completedSummary = progress.state === "working" || progress.state === "unknown" ? undefined : [
    plan ? `${copy.chatPlan} · ${steps.filter(step => reportedStepState(step.status) === "done").length} ${copy.chatOf} ${steps.length} ${copy.chatPlanDone}` : stateLabel,
    changedFileCount ? `${changedFileCount} ${copy.chatFilesChanged}` : undefined,
    duration(progress.startedAt, progress.timeline.at(-1)?.timestamp),
  ].filter(Boolean).join(" · ");
  const handleActivityKey = (event: React.KeyboardEvent<HTMLButtonElement>) => {
    if (event.key === "Escape") { setShowActivity(false); activityToggle.current?.focus(); return; }
    const buttons = [...event.currentTarget.parentElement!.querySelectorAll<HTMLButtonElement>("button")];
    const index = buttons.indexOf(event.currentTarget);
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault();
      buttons[Math.max(0, Math.min(buttons.length - 1, index + (event.key === "ArrowDown" ? 1 : -1)))]?.focus();
    } else if (event.key === "f") {
      event.preventDefault();
      buttons.slice(index + 1).find(button => button.dataset.failed === "true")?.focus();
    }
  };
  return <section className="terminal-turn-progress" aria-label={copy.chatTurnProgress}>
    <button className="terminal-turn-progress-toggle" type="button" aria-expanded={expanded} onClick={() => setExpanded(!expanded)}>
      <strong>{completedSummary ?? copy.chatTurnProgress}</strong><span>{completedSummary ? (expanded ? "⌄" : "›") : `${stateLabel}${progress.state === "working" && elapsed(progress.startedAt, now) ? ` · ${elapsed(progress.startedAt, now)}` : ""}`}</span>
    </button>
    {expanded && <>
      <div className="terminal-turn-progress-content">
        {progress.stale && <span className="terminal-turn-stale">{copy.chatMayBeStale}</span>}
        {progress.plans.length > 1 && <button type="button" className="terminal-turn-plan-update" aria-expanded={showHistory} onClick={() => setShowHistory(!showHistory)}>{copy.chatPlanUpdated} · {progress.plans.length - 1} {copy.chatUpdates}</button>}
        {showHistory && <div className="terminal-turn-plan-history" aria-label={copy.chatPlanUpdates}>{progress.plans.map((report, index) => {
          const changes = index ? planChangeCounts(progress.plans[index - 1], report) : undefined;
          return <p key={report.messageId}>{index + 1}. {report.steps.length} {copy.chatSteps}{changes ? ` · +${changes.added} ${copy.chatAdded} · -${changes.removed} ${copy.chatRemoved}${changes.textChanged ? ` · ${changes.textChanged} ${copy.chatTextChanged}` : ""}` : ""} · {report.explanation ?? copy.chatNoReasonReported}</p>;
        })}</div>}
        {plan ? <>
          {!showAll && visible[0] > 0 && <p className="terminal-turn-omitted">{visible[0]} {copy.chatEarlierSteps}</p>}
          <ol className="terminal-turn-plan">{visible.map(index => {
            const step = steps[index];
            const state = reportedStepState(step.status);
            const status = state === "unknown" ? `${copy.chatUnknown}: ${step.status}` : ({ done: copy.chatCompleted, active: copy.chatPlanActive, upcoming: copy.chatPlanUpcoming, blocked: copy.chatPlanBlocked, skipped: copy.chatPlanSkipped })[state];
            return <li key={index} className={`terminal-turn-step terminal-turn-step-${state}${progress.stale ? " terminal-turn-step-stale" : ""}`}><span aria-hidden="true">{state === "done" ? "✓" : state === "active" ? "●" : state === "blocked" ? "✕" : state === "skipped" ? "–" : "○"}</span><div><button type="button" className="terminal-turn-step-button" aria-label={`${status}: ${step.text}`} aria-expanded={openStep === index} onClick={() => setOpenStep(openStep === index ? null : index)}>{step.text}{state === "unknown" && <small className="terminal-turn-unknown">{status}</small>}</button>{openStep === index && <div className="terminal-turn-step-detail"><div>{copy.chatReportedBy}: {plan.source}</div>{plan.timestamp && <div>{copy.chatReportedAt}: {plan.timestamp}</div>}<div>{copy.chatStepStatus}: {status}</div><div>{copy.chatLinkedActivity}: {copy.chatNoStepLink}</div><div>{copy.chatVerified}: {copy.chatNoCheckDefined}</div></div>}</div></li>;
          })}</ol>
          {steps.length > 7 && (showAll || visible.length < steps.length) && <button type="button" className="terminal-turn-show-all" aria-expanded={showAll} onClick={() => setShowAll(!showAll)}>{showAll ? copy.chatShowFewer : `${copy.chatShowAll} ${steps.length}`}</button>}
        </> : <div className="terminal-turn-no-plan"><span>{progress.partial ? copy.chatPlanNotLoaded : copy.chatNoPlanReported}</span> <button type="button" className="terminal-turn-why" aria-expanded={showWhy} onClick={() => setShowWhy(!showWhy)}>{copy.chatWhy}</button>{showWhy && <p>{copy.chatNoPlanExplanation}</p>}</div>}
        {(progress.state === "working" || progress.state === "unknown") && <div className="terminal-turn-current" aria-live="polite"><strong>{copy.chatCurrentActivity}</strong>{activeStepCount >= 2 && <small>{copy.chatActivityUnlinked}</small>}
          {running.length ? running.map(message => <p key={message.id}><span aria-hidden="true">●</span> {title(message, copy)}{elapsed(message.timestamp, now) ? ` · ${elapsed(message.timestamp, now)}` : ""}</p>) : !failed && <p>{copy.chatNoCommandRunning}</p>}
          {failed && <p className="terminal-turn-failed">{title(failed, copy)}{failed.kind.exit_code !== undefined ? ` · ${copy.chatExitCode} ${failed.kind.exit_code}` : ""}</p>}
        </div>}
      </div>
      <div className="terminal-turn-footer">
        <button ref={activityToggle} type="button" className="terminal-turn-activity-toggle" aria-expanded={showActivity} onClick={() => setShowActivity(!showActivity)}>{copy.chatActivity} <span>{commandCount} {copy.chatCommands}{failedCount ? ` · ${failedCount} ${copy.chatFailed}` : ""}{running.length ? ` · ${running.length} ${copy.chatRunning}` : ""}</span><span aria-hidden="true">{showActivity ? "⌃" : "⌄"}</span></button>
        <span className="terminal-turn-footer-meta">{changedFileCount ? `${changedFileCount} ${copy.chatFilesChanged} · ` : ""}{plan ? `${copy.chatPlan} · ${plan.source}` : copy.chatNoPlanReported}{plan && progress.plans.length > 1 ? ` · ${progress.plans.length} ${copy.chatUpdates}` : ""}{plan && elapsed(plan.timestamp, now) ? ` · ${elapsed(plan.timestamp, now)} ${copy.chatAgo}` : ""}</span>
      </div>
      {showActivity && <div className="terminal-turn-activity-list" aria-label={copy.chatActivity}>
        {groups.map((group, index) => <button type="button" key={index} data-failed={group.some(message => message.kind.status === "failed" || message.kind.exit_code !== undefined && message.kind.exit_code !== 0)} onKeyDown={handleActivityKey} onClick={() => onOpenActivity?.(group[0].id)}><span aria-hidden="true">{group.some(message => message.kind.status === "failed" || message.kind.exit_code !== undefined && message.kind.exit_code !== 0) ? "!" : "•"}</span><span>{group.length > 1 ? `${group.length} ${copy.chatReadCommands}` : title(group[0], copy)}</span><small>{elapsed(group.at(-1)?.timestamp, now)}</small></button>)}
        {progress.plans.length > 1 && <div className="terminal-turn-plan-history"><strong>{copy.chatPlanUpdates}</strong>{progress.plans.slice(0, -1).map((earlier, index) => <p key={earlier.messageId}>{index + 1}. {earlier.steps.length} {copy.chatSteps}{earlier.explanation ? ` · ${earlier.explanation}` : ` · ${copy.chatNoReasonReported}`}</p>)}</div>}
      </div>}
    </>}
  </section>;
}
