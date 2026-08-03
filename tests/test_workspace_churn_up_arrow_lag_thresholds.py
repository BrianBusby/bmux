#!/usr/bin/env python3
"""Behavioral tests for workspace churn latency threshold decisions."""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tests" / "test_workspace_churn_up_arrow_lag.py"
spec = importlib.util.spec_from_file_location("workspace_churn_up_arrow_lag", SCRIPT)
assert spec is not None
workspace_churn_up_arrow_lag = importlib.util.module_from_spec(spec)
assert spec.loader is not None
sys.modules[spec.name] = workspace_churn_up_arrow_lag
spec.loader.exec_module(workspace_churn_up_arrow_lag)

LatencyStats = workspace_churn_up_arrow_lag.LatencyStats


def stats(*, avg_ms: float, p95_ms: float) -> LatencyStats:
    return LatencyStats(
        n=180,
        avg_ms=avg_ms,
        p50_ms=avg_ms,
        p95_ms=p95_ms,
        p99_ms=p95_ms,
        max_ms=p95_ms,
    )


def test_fast_baseline_ratio_spike_under_absolute_budgets_passes() -> None:
    failures = workspace_churn_up_arrow_lag.latency_failures(
        baseline=stats(avg_ms=7.17, p95_ms=8.72),
        churn=stats(avg_ms=13.31, p95_ms=21.42),
        cpu_max=228.0,
    )

    assert failures == []


def test_fast_baseline_still_enforces_absolute_churn_ceiling() -> None:
    failures = workspace_churn_up_arrow_lag.latency_failures(
        baseline=stats(avg_ms=7.0, p95_ms=8.0),
        churn=stats(avg_ms=13.0, p95_ms=36.5),
        cpu_max=80.0,
    )

    assert any(failure.startswith("churn p95") for failure in failures)


def test_mature_baseline_still_enforces_ratio_regressions() -> None:
    failures = workspace_churn_up_arrow_lag.latency_failures(
        baseline=stats(avg_ms=10.0, p95_ms=15.0),
        churn=stats(avg_ms=18.0, p95_ms=28.0),
        cpu_max=80.0,
    )

    assert "p95 ratio 1.87x > 1.70x" in failures
    assert "avg ratio 1.80x > 1.70x" in failures


if __name__ == "__main__":
    test_fast_baseline_ratio_spike_under_absolute_budgets_passes()
    test_fast_baseline_still_enforces_absolute_churn_ceiling()
    test_mature_baseline_still_enforces_ratio_regressions()
