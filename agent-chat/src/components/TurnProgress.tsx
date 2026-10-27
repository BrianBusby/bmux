import { useState } from "react";
import { useTicker } from "../hooks/useTicker";
import type { Block } from "../session";
import { planChanges, stepState, type PlanBlock } from "../plan";
import type { TurnGroup } from "../turns";

const copy = navigator.language.startsWith("ja") ? {
  title: "ターンの進行状況", plan: "プラン", notLoaded: "プランのデータは読み込まれていません", noPlan: "プランは報告されていません", working: "作業中", complete: "完了",
  current: "現在の作業", noCommand: "実行中のコマンドはありません", unlinked: "手順との関連付けはありません", activity: "操作", failed: "失敗",
  showAll: "すべて表示", showFewer: "折りたたむ", history: "プランの履歴", noReason: "理由の報告なし",
  reported: "報告元", unknown: "不明", done: "完了", active: "進行中", upcoming: "予定", blocked: "ブロック中",
  skipped: "スキップ", exit: "終了コード", details: "詳細", changes: "変更", of: "/", linked: "関連する操作なし（手順の参照情報がありません）",
  added: "追加", removed: "削除", reopened: "再開", moved: "移動", textChanged: "文言変更",
} : {
  title: "Turn progress", plan: "Plan", noPlan: "No plan reported", notLoaded: "Plan data not loaded", working: "Working", complete: "Completed",
  current: "Current activity", noCommand: "No command running", unlinked: "not linked to steps", activity: "Activity", failed: "failed",
  showAll: "Show all", showFewer: "Show fewer", history: "Plan history", noReason: "no reason reported",
  reported: "Reported by", unknown: "Unknown", done: "Done", active: "In progress", upcoming: "Upcoming", blocked: "Blocked",
  skipped: "Skipped", exit: "exit", details: "Details", changes: "changes", of: "of", linked: "none — provider sends no step reference",
  added: "added", removed: "removed", reopened: "reopened", moved: "moved", textChanged: "text changed",
};

function glyph(status: string): string {
  switch (stepState(status)) {
    case "done": return "✓";
    case "active": return "●";
    case "upcoming": return "○";
    case "blocked": return "✕";
    case "skipped": return "–";
    case "unknown": return "?";
  }
}

function stepLabel(status: string): string {
  return copy[stepState(status)];
}

function visibleIndexes(plan: PlanBlock): number[] {
  const steps = plan.steps;
  if (steps.length <= 7) return steps.map((_, index) => index);
  const active = steps.flatMap((step, index) => stepState(step.status) === "active" ? [index] : []);
  const first = active[0] ?? steps.findIndex((step) => stepState(step.status) !== "done");
  const anchor = first < 0 ? steps.length - 1 : first;
  const start = Math.max(0, anchor - 1);
  const end = Math.min(steps.length, (active.at(-1) ?? anchor) + 3);
  return steps.flatMap((_, index) => index >= start && index < end ? [index] : []);
}

export function TurnProgress({ group }: { group: TurnGroup }) {
  const [all, setAll] = useState(false);
  const [open, setOpen] = useState(false);
  const plans = group.activity.filter((block): block is PlanBlock => block.kind === "plan");
  const plan = plans.at(-1);
  const truncated = group.activity.some((block) => block.kind === "status" && block.text.startsWith("(transcript truncated"));
  const tools = group.activity.filter((block): block is Extract<Block, { kind: "tool" }> => block.kind === "tool");
  const running = tools.filter((tool) => tool.status === "running");
  const failed = tools.at(-1)?.status === "fail" ? tools.at(-1) : undefined;
  const now = useTicker(!group.done && running.length > 0);
  const doneCount = plan?.steps.filter((step) => stepState(step.status) === "done").length ?? 0;
  const indexes = plan ? all ? plan.steps.map((_, index) => index) : visibleIndexes(plan) : [];
  const hidden = plan ? indexes.length < plan.steps.length : false;
  const content = (
    <>
      {plan ? (
        <>
          <ol className="turn-plan-steps" aria-label={copy.title}>
            {indexes.map((index) => {
              const step = plan.steps[index];
              return <li key={`${index}:${step.id ?? step.text}`} className={`turn-plan-step state-${stepState(step.status)}`}>
                <details><summary aria-label={`${stepLabel(step.status)}: ${step.text}`}><span aria-hidden="true">{glyph(step.status)}</span><span>{step.text}</span></summary>
                  <div className="turn-plan-detail">{copy.reported}: {plan.source} · {new Date(plan.at).toLocaleTimeString()}<br />
                    {stepState(step.status) === "unknown" ? `${copy.unknown}: ${step.status}` : stepLabel(step.status)}<br />
                    {copy.linked}</div>
                </details>
              </li>;
            })}
          </ol>
          {(hidden || all && plan.steps.length > 7) ? <button type="button" className="turn-plan-more" onClick={() => setAll(!all)}>{all ? copy.showFewer : `${copy.showAll} ${plan.steps.length}`}</button> : null}
        </>
      ) : <p className="turn-plan-empty">{truncated ? copy.notLoaded : copy.noPlan}</p>}
      {!group.done ? <div className="turn-current" aria-label={copy.current}>
        <div className="turn-current-heading">{copy.current}{(plan?.steps.filter((step) => stepState(step.status) === "active").length ?? 0) > 1 ? ` · ${copy.unlinked}` : ""}</div>
        {running.map((tool) => <div key={tool.toolId}>● {tool.name}{tool.detail ? ` · ${tool.detail}` : ""}{tool.startedAt ? ` · ${Math.max(0, Math.floor((now - tool.startedAt) / 1000))}s` : ""}</div>)}
        {!running.length && !failed ? <div>{copy.noCommand}</div> : null}
        {failed ? <div className="turn-current-failed">✕ {failed.name}{failed.exitCode !== undefined ? ` · ${copy.exit} ${failed.exitCode}` : ""}{failed.out ? ` · ${failed.out}` : ""}</div> : null}
      </div> : null}
      {plans.length > 1 ? <details className="turn-plan-history"><summary>{copy.history} · {plans.length}</summary>
        {plans.slice(1).map((report, index) => <div key={`${report.at}:${index}`}>
          {new Date(report.at).toLocaleTimeString()} · {report.explanation || copy.noReason}
          <ul>{planChanges(plans[index], report).map((change, changeIndex) => <li key={changeIndex}>{copy[change.kind === "text changed" ? "textChanged" : change.kind]}: {change.text}</li>)}</ul>
        </div>)}
      </details> : null}
    </>
  );
  return <section className="turn-progress" aria-label={copy.title}>
    {group.done ? <><button type="button" className="turn-progress-compact" aria-expanded={open} onClick={() => setOpen(!open)}>
      {plan ? `${copy.plan} · ${doneCount} ${copy.of} ${plan.steps.length} ${copy.done.toLowerCase()}` : truncated ? copy.notLoaded : copy.noPlan} ▸
    </button>{open ? content : null}</> : <><div className="turn-progress-heading"><strong>{copy.title}</strong><span>{copy.working}</span></div>{content}</>}
  </section>;
}
