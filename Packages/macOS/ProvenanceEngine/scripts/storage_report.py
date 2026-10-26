#!/usr/bin/env python3
"""Payload-free PE storage diagnostics; --deep scans physical pages and logical bytes."""
import argparse
import datetime as dt
import json
import os
from pathlib import Path
import sqlite3

GIB = 1024 ** 3
TABLES = {
    "ledger": ("provenance_events", "payload_json"),
    "turn_outcomes": ("provenance_coding_agent_turn_outcome_revisions", "outcome_json"),
    "session_outcomes": ("provenance_coding_agent_session_outcome_revisions", "outcome_json"),
    "semantic_inferences": ("provenance_semantic_inferences", None),
    "semantic_messages": ("provenance_semantic_messages", None),
}


def scalar(db, sql):
    return db.execute(sql).fetchone()[0]


def run(path, deep):
    db = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    db.execute("PRAGMA query_only=ON")
    page_size = scalar(db, "PRAGMA page_size")
    pages = scalar(db, "PRAGMA page_count")
    free_pages = scalar(db, "PRAGMA freelist_count")
    wal = Path(str(path) + "-wal")
    data = {
        "policy_version": 1,
        "schema_version": scalar(db, "PRAGMA user_version"),
        "file_bytes": path.stat().st_size,
        "wal_bytes": wal.stat().st_size if wal.exists() else 0,
        "freelist_bytes": free_pages * page_size,
        "used_page_bytes": (pages - free_pages) * page_size,
        "free_disk_bytes": os.statvfs(path).f_bavail * os.statvfs(path).f_frsize,
        "classes": {},
        "ingestion_lag_seconds": None,
    }
    for kind, (table, column) in TABLES.items():
        if not db.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", (table,)).fetchone():
            continue
        row = {"rows": scalar(db, f"SELECT count(*) FROM {table}")}
        if deep and column:
            row["logical_payload_bytes"] = scalar(db, f"SELECT coalesce(sum(length({column})),0) FROM {table}")
        if deep and column == "outcome_json":
            row["retired_payload_rows"] = scalar(db, f"SELECT count(*) FROM {table} WHERE outcome_json = ''")
        data["classes"][kind] = row
    if deep:
        data["pruning_results"] = {
            "retired_turn_payload_rows": data["classes"].get("turn_outcomes", {}).get("retired_payload_rows", 0),
            "retired_session_payload_rows": data["classes"].get("session_outcomes", {}).get("retired_payload_rows", 0),
        }
    counts = [r[0] for r in db.execute("""
        SELECT count(*) FROM provenance_coding_agent_session_outcome_revisions
        GROUP BY session_id ORDER BY count(*)
    """)]
    data["revisions_per_session"] = {
        "sessions": len(counts),
        "maximum": counts[-1] if counts else 0,
        "p95": counts[min(len(counts)-1, int(len(counts)*0.95))] if counts else 0,
    }
    latest = db.execute("SELECT timestamp_seconds FROM provenance_events ORDER BY sequence DESC LIMIT 1").fetchone()
    data["last_accepted_event_age_seconds"] = max(0, round(dt.datetime.now().timestamp() - latest[0])) if latest else None
    if deep:
        data["objects_bytes"] = {name: size for name, size in db.execute(
            "SELECT name, sum(pgsize) FROM dbstat GROUP BY name ORDER BY sum(pgsize) DESC")}
    db.close()
    sample_path = path.with_name("storage-samples.json")
    samples = json.loads(sample_path.read_text()) if sample_path.exists() else []
    previous = next((s for s in reversed(samples) if s["date"] < dt.date.today().isoformat()), None)
    data["daily_file_growth_bytes"] = data["file_bytes"] - previous["file_bytes"] if previous else None
    alerts = []
    if data["file_bytes"] > 50 * GIB: alerts.append("file_over_50_gib")
    if data["freelist_bytes"] > 10 * GIB and free_pages * 4 > pages: alerts.append("freelist_over_10_gib_and_25_percent")
    if data["wal_bytes"] > GIB: alerts.append("wal_over_1_gib")
    if data["revisions_per_session"]["maximum"] > 256: alerts.append("session_revisions_over_256")
    if data["daily_file_growth_bytes"] is not None and data["daily_file_growth_bytes"] > 5 * GIB:
        alerts.append("daily_growth_over_5_gib")
    data["alerts"] = alerts
    return data, samples, sample_path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=Path.home()/".local/state/provenance-engine/provenance.sqlite")
    parser.add_argument("--deep", action="store_true")
    parser.add_argument("--record-sample", action="store_true")
    args = parser.parse_args()
    data, samples, sample_path = run(args.db, args.deep)
    print(json.dumps(data, indent=2, sort_keys=True))
    if args.record_sample:
        samples = [s for s in samples if s["date"] != dt.date.today().isoformat()]
        samples.append({"date": dt.date.today().isoformat(), "file_bytes": data["file_bytes"]})
        temporary = sample_path.with_suffix(".json.tmp")
        temporary.write_text(json.dumps(sorted(samples, key=lambda s: s["date"])[-32:]))
        os.replace(temporary, sample_path)


if __name__ == "__main__":
    main()
