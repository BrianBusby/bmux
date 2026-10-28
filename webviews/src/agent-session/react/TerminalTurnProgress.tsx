import React, { useState } from "react";
import type { AgentSessionCopy } from "../shared/types";
import { reportedStepState, type TurnProgressSnapshot } from "../shared/terminalTurnProgress";

export function TerminalTurnProgress({ progress, copy }: { progress: TurnProgressSnapshot; copy: AgentSessionCopy }) {
  const [expanded, setExpanded] = useState(progress.state !== "completed");
  const plan = progress.plan;
  const done = plan?.steps.filter(step => reportedStepState(step.status) === "done").length ?? 0;
  const running = progress.activity.filter(message => message.kind.is_running || message.kind.status === "running");
  const last = progress.activity.at(-1);
  const failed = last && (last.kind.status === "failed" || last.kind.exit_code !== undefined && last.kind.exit_code !== 0) ? last : undefined;
  const label = progress.state === "completed" ? copy.chatCompleted : progress.state === "working" ? copy.runningStatus : copy.chatUnknown;
  return <section className="terminal-turn-progress" aria-label={copy.chatTurnProgress}>
    <button className="terminal-turn-progress-toggle" type="button" aria-expanded={expanded} onClick={() => setExpanded(!expanded)}>
      <strong>{copy.chatTurnProgress}</strong><span>{plan ? `${done}/${plan.steps.length} ${copy.chatPlanDone}` : label}</span>
    </button>
    {expanded && <div className="terminal-turn-progress-content">
      {plan ? <ol className="terminal-turn-plan">{plan.steps.map((step, index) => {
        const state = reportedStepState(step.status);
        const status = state === "unknown" ? `${copy.chatUnknown}: ${step.status}` : ({ done: copy.chatCompleted, active: copy.chatPlanActive, upcoming: copy.chatPlanUpcoming, blocked: copy.chatPlanBlocked, skipped: copy.chatPlanSkipped })[state];
        return <li key={`${index}:${step.text}`}><span aria-hidden="true">{state === "done" ? "✓" : state === "active" ? "●" : "○"}</span><span>{step.text}</span><small>{status}</small></li>;
      })}</ol> : <p>{progress.partial ? copy.chatPlanNotLoaded : copy.chatNoPlanReported}</p>}
      {progress.state !== "completed" && <div className="terminal-turn-current"><strong>{copy.chatCurrentActivity}</strong>
        {running.length ? running.map(message => <p key={message.id}>{message.kind.command ?? message.kind.summary ?? message.kind.tool_name ?? copy.chatActivity}</p>) : !failed && <p>{copy.chatNoCommandRunning}</p>}
        {failed && <p className="terminal-turn-failed">{failed.kind.command ?? failed.kind.summary ?? failed.kind.tool_name ?? copy.chatActivity}{failed.kind.exit_code !== undefined ? ` · ${copy.chatExitCode} ${failed.kind.exit_code}` : ""}</p>}
      </div>}
    </div>}
  </section>;
}
