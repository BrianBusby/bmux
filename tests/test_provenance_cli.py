#!/usr/bin/env python3
"""Regression checks for the provenance CLI."""

from __future__ import annotations

import json
import hashlib
import os
import sqlite3
import subprocess
import tempfile
from pathlib import Path

from claude_teams_test_utils import resolve_bmux_cli


def stable_id(prefix: str, value: str) -> str:
    return f"{prefix}-{hashlib.sha256(value.encode()).hexdigest()[:24]}"


def stable_repository_id(repository_root: str) -> str:
    return stable_id("repository", repository_root)


def stable_worktree_id(repository_root: str) -> str:
    return stable_id("worktree", repository_root)


def create_provenance_database(path: Path) -> None:
    if path.exists():
        path.unlink()
    with sqlite3.connect(path) as conn:
        conn.executescript(
            """
            CREATE TABLE sessions (
                id TEXT PRIMARY KEY,
                agent_kind TEXT NOT NULL,
                workspace_id TEXT,
                surface_id TEXT,
                worktree_id TEXT,
                cwd TEXT,
                status TEXT NOT NULL,
                started_at REAL,
                updated_at REAL NOT NULL
            );
            CREATE TABLE session_relationships (
                session_id TEXT PRIMARY KEY,
                parent_session_id TEXT NOT NULL,
                root_session_id TEXT NOT NULL,
                inbound_delegation_id TEXT,
                depth INTEGER NOT NULL,
                source TEXT NOT NULL,
                confidence TEXT NOT NULL,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL
            );
            CREATE TABLE session_external_identities (
                id TEXT PRIMARY KEY,
                session_id TEXT NOT NULL,
                system TEXT NOT NULL,
                kind TEXT NOT NULL,
                external_id TEXT NOT NULL,
                source TEXT NOT NULL,
                confidence TEXT NOT NULL,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL
            );
            PRAGMA user_version = 3;
            """
        )
        conn.executemany(
            """
            INSERT INTO sessions (
                id, agent_kind, workspace_id, surface_id, worktree_id,
                cwd, status, started_at, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    "codex-parent",
                    "codex",
                    "workspace-1",
                    "surface-1",
                    "worktree-1",
                    "/repo",
                    "active",
                    100.0,
                    100.0,
                ),
                (
                    "codex-child",
                    "codex",
                    "workspace-1",
                    "surface-2",
                    "worktree-1",
                    "/repo",
                    "completed",
                    120.0,
                    140.0,
                ),
                (
                    "codex-grandchild",
                    "codex",
                    "workspace-1",
                    "surface-3",
                    "worktree-1",
                    "/repo",
                    "active",
                    130.0,
                    130.0,
                ),
                (
                    "unrelated",
                    "claude",
                    "workspace-9",
                    "surface-9",
                    "worktree-9",
                    "/other",
                    "active",
                    200.0,
                    200.0,
                ),
            ],
        )
        conn.executemany(
            """
            INSERT INTO session_relationships (
                session_id, parent_session_id, root_session_id,
                inbound_delegation_id, depth, source, confidence,
                created_at, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    "codex-child",
                    "codex-parent",
                    "codex-parent",
                    None,
                    1,
                    "observed",
                    "high",
                    120.0,
                    140.0,
                ),
                (
                    "codex-grandchild",
                    "codex-child",
                    "codex-parent",
                    None,
                    2,
                    "observed",
                    "high",
                    130.0,
                    130.0,
                ),
            ],
        )
        conn.executemany(
            """
            INSERT INTO session_external_identities (
                id, session_id, system, kind, external_id, source,
                confidence, created_at, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    "identity-child",
                    "codex-child",
                    "codex",
                    "subsession",
                    "subagent-1",
                    "observed",
                    "high",
                    120.0,
                    140.0,
                ),
                (
                    "identity-grandchild",
                    "codex-grandchild",
                    "codex",
                    "subsession",
                    "subagent-2",
                    "observed",
                    "high",
                    130.0,
                    130.0,
                ),
                (
                    "identity-unrelated",
                    "unrelated",
                    "claude",
                    "thread",
                    "claude-thread",
                    "observed",
                    "high",
                    200.0,
                    200.0,
                ),
            ],
        )


def create_provenance_explain_database(
    path: Path,
    repository_root: str,
    include_worktree: bool = True,
    include_file: bool = True,
) -> None:
    if path.exists():
        path.unlink()
    repository_id = stable_repository_id(repository_root)
    worktree_id = stable_worktree_id(repository_root)
    with sqlite3.connect(path) as conn:
        conn.executescript(
            """
            CREATE TABLE repositories (
                id TEXT PRIMARY KEY NOT NULL,
                path TEXT NOT NULL,
                common_directory TEXT,
                remote_slug TEXT,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL
            );
            CREATE TABLE worktrees (
                id TEXT PRIMARY KEY NOT NULL,
                repository_id TEXT NOT NULL,
                path TEXT NOT NULL,
                branch TEXT,
                base_commit TEXT,
                current_head TEXT,
                is_dirty INTEGER NOT NULL,
                status TEXT NOT NULL,
                last_reconciled_at REAL,
                updated_at REAL NOT NULL
            );
            CREATE TABLE sessions (
                id TEXT PRIMARY KEY NOT NULL,
                agent_kind TEXT NOT NULL,
                workspace_id TEXT,
                surface_id TEXT,
                worktree_id TEXT,
                cwd TEXT,
                status TEXT NOT NULL,
                started_at REAL,
                updated_at REAL NOT NULL
            );
            CREATE TABLE session_relationships (
                session_id TEXT PRIMARY KEY NOT NULL,
                parent_session_id TEXT NOT NULL,
                root_session_id TEXT NOT NULL,
                inbound_delegation_id TEXT,
                depth INTEGER NOT NULL,
                source TEXT NOT NULL,
                confidence TEXT NOT NULL,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL
            );
            CREATE TABLE session_external_identities (
                id TEXT PRIMARY KEY NOT NULL,
                session_id TEXT NOT NULL,
                system TEXT NOT NULL,
                kind TEXT NOT NULL,
                external_id TEXT NOT NULL,
                source TEXT NOT NULL,
                confidence TEXT NOT NULL,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL
            );
            CREATE TABLE work_items (
                id TEXT PRIMARY KEY NOT NULL,
                title TEXT NOT NULL,
                status TEXT NOT NULL,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL
            );
            CREATE TABLE work_contributions (
                id TEXT PRIMARY KEY NOT NULL,
                session_id TEXT NOT NULL,
                worktree_id TEXT NOT NULL,
                work_item_id TEXT NOT NULL,
                declared_intent TEXT,
                expected_scope_json TEXT NOT NULL,
                status TEXT NOT NULL,
                started_at REAL NOT NULL,
                ended_at REAL,
                assignment_confidence TEXT NOT NULL,
                updated_at REAL NOT NULL
            );
            CREATE TABLE checkpoints (
                id TEXT PRIMARY KEY NOT NULL,
                contribution_id TEXT NOT NULL,
                sequence INTEGER NOT NULL,
                git_head TEXT,
                diff_fingerprint TEXT,
                summary TEXT,
                status TEXT NOT NULL,
                validation_state TEXT,
                semantic_confidence TEXT NOT NULL,
                freshness TEXT NOT NULL,
                created_at REAL NOT NULL
            );
            CREATE TABLE change_sets (
                id TEXT PRIMARY KEY NOT NULL,
                checkpoint_id TEXT,
                contribution_id TEXT,
                worktree_id TEXT NOT NULL,
                summary TEXT,
                diff_fingerprint TEXT,
                created_at REAL NOT NULL
            );
            CREATE TABLE file_changes (
                id TEXT PRIMARY KEY NOT NULL,
                change_set_id TEXT NOT NULL,
                repository_id TEXT NOT NULL,
                worktree_id TEXT NOT NULL,
                path TEXT NOT NULL,
                status TEXT NOT NULL,
                before_hash TEXT,
                after_hash TEXT,
                attribution_source TEXT NOT NULL,
                attribution_confidence TEXT NOT NULL,
                updated_at REAL NOT NULL
            );
            CREATE TABLE validation_runs (
                id TEXT PRIMARY KEY NOT NULL,
                checkpoint_id TEXT,
                contribution_id TEXT,
                command TEXT NOT NULL,
                status TEXT NOT NULL,
                summary TEXT,
                started_at REAL,
                ended_at REAL
            );
            PRAGMA user_version = 3;
            """
        )
        if not include_worktree:
            return
        conn.execute(
            """
            INSERT INTO repositories (
                id, path, common_directory, remote_slug, created_at, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (repository_id, repository_root, None, "manaflow-ai/bmux", 100.0, 160.0),
        )
        conn.execute(
            """
            INSERT INTO worktrees (
                id, repository_id, path, branch, base_commit, current_head,
                is_dirty, status, last_reconciled_at, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                worktree_id,
                repository_id,
                repository_root,
                "provenance-extraction-phase2-contracts",
                None,
                "abc123",
                1,
                "active",
                150.0,
                160.0,
            ),
        )
        if not include_file:
            return
        conn.execute(
            """
            INSERT INTO sessions (
                id, agent_kind, workspace_id, surface_id, worktree_id,
                cwd, status, started_at, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                "session-1",
                "codex",
                "workspace-1",
                "surface-1",
                worktree_id,
                repository_root,
                "active",
                110.0,
                155.0,
            ),
        )
        conn.execute(
            """
            INSERT INTO work_items (id, title, status, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?)
            """,
            ("WI-1", "Explain dirty files", "active", 105.0, 155.0),
        )
        conn.execute(
            """
            INSERT INTO work_contributions (
                id, session_id, worktree_id, work_item_id, declared_intent,
                expected_scope_json, status, started_at, ended_at,
                assignment_confidence, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                "contribution-1",
                "session-1",
                worktree_id,
                "WI-1",
                "Capture work provenance",
                json.dumps(["Sources/WorkspaceManager.swift"]),
                "active",
                110.0,
                None,
                "medium",
                155.0,
            ),
        )
        conn.execute(
            """
            INSERT INTO checkpoints (
                id, contribution_id, sequence, git_head, diff_fingerprint,
                summary, status, validation_state, semantic_confidence,
                freshness, created_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                "checkpoint-1",
                "contribution-1",
                1,
                "head",
                "diff-1",
                "Recorded first batch",
                "in_progress",
                "not_run",
                "medium",
                "fresh",
                140.0,
            ),
        )
        conn.execute(
            """
            INSERT INTO change_sets (
                id, checkpoint_id, contribution_id, worktree_id,
                summary, diff_fingerprint, created_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (
                "changeset-1",
                "checkpoint-1",
                "contribution-1",
                worktree_id,
                "Workspace provenance",
                "diff-1",
                145.0,
            ),
        )
        conn.execute(
            """
            INSERT INTO file_changes (
                id, change_set_id, repository_id, worktree_id, path, status,
                before_hash, after_hash, attribution_source,
                attribution_confidence, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                "file-1",
                "changeset-1",
                repository_id,
                worktree_id,
                "Sources/WorkspaceManager.swift",
                "modified",
                "before",
                "after",
                "observed",
                "high",
                150.0,
            ),
        )


def create_observability_database(path: Path) -> None:
    if path.exists():
        path.unlink()
    with sqlite3.connect(path) as conn:
        conn.executescript(
            """
            CREATE TABLE pipeline_runs (
                pipeline_run_id TEXT PRIMARY KEY NOT NULL,
                pipeline_kind TEXT NOT NULL,
                trigger_source TEXT NOT NULL,
                parent_session_id TEXT,
                child_session_id TEXT,
                lifecycle_event_id TEXT,
                relationship_session_id TEXT,
                external_identity_id TEXT,
                status TEXT NOT NULL,
                started_at REAL NOT NULL,
                ended_at REAL NOT NULL,
                duration_ms REAL NOT NULL,
                input_count INTEGER NOT NULL,
                output_count INTEGER NOT NULL,
                error_count INTEGER NOT NULL,
                error_summary TEXT,
                implementation_version TEXT NOT NULL
            );
            CREATE TABLE pipeline_stage_executions (
                stage_execution_id TEXT PRIMARY KEY NOT NULL,
                pipeline_run_id TEXT NOT NULL,
                stage_name TEXT NOT NULL,
                stage_version TEXT NOT NULL,
                status TEXT NOT NULL,
                started_at REAL NOT NULL,
                ended_at REAL NOT NULL,
                duration_ms REAL NOT NULL,
                input_count INTEGER NOT NULL,
                output_count INTEGER NOT NULL,
                error_count INTEGER NOT NULL,
                error_summary TEXT
            );
            CREATE TABLE identity_resolution_attempts (
                identity_resolution_id TEXT PRIMARY KEY NOT NULL,
                pipeline_run_id TEXT NOT NULL,
                resolver_name TEXT NOT NULL,
                resolver_version TEXT NOT NULL,
                trigger_source TEXT NOT NULL,
                input_phase TEXT NOT NULL,
                input_agent_kind TEXT NOT NULL,
                input_parent_session_id TEXT NOT NULL,
                input_subsession_id_state TEXT NOT NULL,
                input_workspace_present INTEGER NOT NULL,
                input_surface_present INTEGER NOT NULL,
                input_working_directory_present INTEGER NOT NULL,
                input_display_name_present INTEGER NOT NULL,
                input_identity_kind TEXT NOT NULL,
                input_identity_value_hash TEXT NOT NULL,
                selected_identity_kind TEXT NOT NULL,
                selected_identity_value_category TEXT NOT NULL,
                candidate_count INTEGER NOT NULL,
                selected_child_session_id TEXT,
                selected_lifecycle_event_id TEXT,
                selected_relationship_session_id TEXT,
                selected_external_identity_id TEXT,
                confidence TEXT NOT NULL,
                outcome TEXT NOT NULL,
                fallback_state TEXT NOT NULL,
                unresolved_reason TEXT,
                conflict_reason TEXT,
                started_at REAL NOT NULL,
                ended_at REAL NOT NULL,
                duration_ms REAL NOT NULL
            );
            CREATE TABLE projection_lineage (
                projection_lineage_id TEXT PRIMARY KEY NOT NULL,
                pipeline_run_id TEXT NOT NULL,
                stage_name TEXT NOT NULL,
                projection_kind TEXT NOT NULL,
                source_event_id TEXT NOT NULL,
                source_event_type TEXT NOT NULL,
                source_event_schema_version INTEGER NOT NULL,
                source_payload_hash TEXT NOT NULL,
                target_table TEXT NOT NULL,
                target_entity_kind TEXT NOT NULL,
                target_entity_id TEXT NOT NULL,
                operation TEXT NOT NULL,
                generator_version TEXT NOT NULL,
                confidence TEXT NOT NULL,
                started_at REAL NOT NULL,
                ended_at REAL NOT NULL,
                duration_ms REAL NOT NULL
            );
            """
        )
        conn.executemany(
            """
            INSERT INTO pipeline_runs (
                pipeline_run_id, pipeline_kind, trigger_source,
                parent_session_id, child_session_id, lifecycle_event_id,
                relationship_session_id, external_identity_id, status,
                started_at, ended_at, duration_ms, input_count, output_count,
                error_count, error_summary, implementation_version
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    "run-success",
                    "lifecycle_ingestion",
                    "AgentSubsessionLifecycleChange",
                    "codex-parent",
                    "codex-child",
                    "event-child-start",
                    "codex-child",
                    "identity-child",
                    "succeeded",
                    120.0,
                    121.0,
                    1000.0,
                    1,
                    1,
                    0,
                    None,
                    "o1",
                ),
                (
                    "run-failed",
                    "lifecycle_ingestion",
                    "AgentSubsessionLifecycleChange",
                    "codex-parent",
                    "codex-child",
                    "event-child-start",
                    "codex-child",
                    "identity-child",
                    "failed",
                    130.0,
                    131.0,
                    1000.0,
                    1,
                    0,
                    1,
                    "UNIQUE constraint failed: events.id",
                    "o1",
                ),
                (
                    "run-second-parent",
                    "lifecycle_ingestion",
                    "AgentSubsessionLifecycleChange",
                    "other-parent",
                    "other-child",
                    "event-other-start",
                    "other-child",
                    "identity-other",
                    "succeeded",
                    135.0,
                    136.0,
                    1000.0,
                    1,
                    1,
                    0,
                    None,
                    "o2",
                ),
                (
                    "run-other",
                    "retrieval",
                    "not-o1",
                    None,
                    None,
                    None,
                    None,
                    None,
                    "succeeded",
                    140.0,
                    141.0,
                    1000.0,
                    1,
                    1,
                    0,
                    None,
                    "future",
                ),
            ],
        )
        conn.executemany(
            """
            INSERT INTO pipeline_stage_executions (
                stage_execution_id, pipeline_run_id, stage_name,
                stage_version, status, started_at, ended_at, duration_ms,
                input_count, output_count, error_count, error_summary
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    "run-success:lifecycle_change_received",
                    "run-success",
                    "lifecycle_change_received",
                    "o1",
                    "succeeded",
                    120.0,
                    120.1,
                    100.0,
                    1,
                    1,
                    0,
                    None,
                ),
                (
                    "run-success:work_provenance_event_append",
                    "run-success",
                    "work_provenance_event_append",
                    "o1",
                    "succeeded",
                    121.0,
                    121.1,
                    100.0,
                    1,
                    1,
                    0,
                    None,
                ),
                (
                    "run-success:work_provenance_projection_update",
                    "run-success",
                    "work_provenance_projection_update",
                    "o1",
                    "succeeded",
                    122.0,
                    122.1,
                    100.0,
                    1,
                    3,
                    0,
                    None,
                ),
                (
                    "run-second-parent:lifecycle_change_received",
                    "run-second-parent",
                    "lifecycle_change_received",
                    "o1",
                    "succeeded",
                    135.0,
                    135.1,
                    100.0,
                    1,
                    1,
                    0,
                    None,
                ),
                (
                    "run-second-parent:work_provenance_event_append",
                    "run-second-parent",
                    "work_provenance_event_append",
                    "o1",
                    "succeeded",
                    136.0,
                    136.1,
                    100.0,
                    1,
                    1,
                    0,
                    None,
                ),
                (
                    "run-second-parent:work_provenance_projection_update",
                    "run-second-parent",
                    "work_provenance_projection_update",
                    "o1",
                    "succeeded",
                    137.0,
                    137.1,
                    100.0,
                    1,
                    3,
                    0,
                    None,
                ),
                (
                    "run-failed:lifecycle_change_received",
                    "run-failed",
                    "lifecycle_change_received",
                    "o1",
                    "succeeded",
                    130.0,
                    130.1,
                    100.0,
                    1,
                    1,
                    0,
                    None,
                ),
                (
                    "run-failed:work_provenance_event_append",
                    "run-failed",
                    "work_provenance_event_append",
                    "o1",
                    "failed",
                    131.0,
                    131.1,
                    100.0,
                    1,
                    0,
                    1,
                    "failed",
                ),
                (
                    "run-failed:work_provenance_projection_update",
                    "run-failed",
                    "work_provenance_projection_update",
                    "o1",
                    "failed",
                    132.0,
                    132.1,
                    100.0,
                    0,
                    0,
                    1,
                    "skipped",
                ),
            ],
        )
        conn.executemany(
            """
            INSERT INTO identity_resolution_attempts (
                identity_resolution_id, pipeline_run_id, resolver_name,
                resolver_version, trigger_source, input_phase, input_agent_kind,
                input_parent_session_id, input_subsession_id_state,
                input_workspace_present, input_surface_present,
                input_working_directory_present, input_display_name_present,
                input_identity_kind, input_identity_value_hash,
                selected_identity_kind, selected_identity_value_category,
                candidate_count, selected_child_session_id,
                selected_lifecycle_event_id, selected_relationship_session_id,
                selected_external_identity_id, confidence, outcome,
                fallback_state, unresolved_reason, conflict_reason,
                started_at, ended_at, duration_ms
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    "run-success:subsession_identity",
                    "run-success",
                    "subsession_lifecycle_identity",
                    "o2",
                    "AgentSubsessionLifecycleChange",
                    "started",
                    "codex",
                    "codex-parent",
                    "present",
                    1,
                    1,
                    1,
                    1,
                    "subsession",
                    "identity-input-native",
                    "subsession",
                    "native_subsession_id",
                    1,
                    "codex-child",
                    "event-child-start",
                    "codex-child",
                    "identity-child",
                    "high",
                    "resolved",
                    "native",
                    None,
                    None,
                    120.0,
                    120.1,
                    100.0,
                ),
                (
                    "run-second-parent:subsession_identity",
                    "run-second-parent",
                    "subsession_lifecycle_identity",
                    "o2",
                    "AgentSubsessionLifecycleChange",
                    "started",
                    "codex",
                    "other-parent",
                    "missing",
                    0,
                    0,
                    1,
                    0,
                    "unresolved_subsession",
                    "identity-input-fallback",
                    "unresolved_subsession",
                    "stable_parent_fallback",
                    0,
                    "other-child",
                    "event-other-start",
                    "other-child",
                    "identity-other",
                    "low",
                    "unresolved",
                    "fallback_unresolved",
                    "missing_native_subsession_identifier",
                    None,
                    135.0,
                    135.1,
                    100.0,
                ),
                (
                    "run-failed:subsession_identity",
                    "run-failed",
                    "subsession_lifecycle_identity",
                    "o2",
                    "AgentSubsessionLifecycleChange",
                    "started",
                    "codex",
                    "codex-parent",
                    "present",
                    1,
                    1,
                    1,
                    1,
                    "subsession",
                    "identity-input-native",
                    "subsession",
                    "native_subsession_id",
                    1,
                    "codex-child",
                    "event-child-start",
                    "codex-child",
                    "identity-child",
                    "high",
                    "resolved",
                    "native",
                    None,
                    "UNIQUE constraint failed: events.id",
                    130.0,
                    130.1,
                    100.0,
                ),
            ],
        )

        conn.executemany(
            """
            INSERT INTO projection_lineage (
                projection_lineage_id, pipeline_run_id, stage_name,
                projection_kind, source_event_id, source_event_type,
                source_event_schema_version, source_payload_hash, target_table,
                target_entity_kind, target_entity_id, operation, generator_version,
                confidence, started_at, ended_at, duration_ms
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    "run-success:projection:session",
                    "run-success",
                    "work_provenance_projection_update",
                    "lifecycle_ingestion_projection",
                    "event-child-start",
                    "subsession_started",
                    1,
                    "payload-success",
                    "sessions",
                    "session",
                    "codex-child",
                    "upsert",
                    "o3",
                    "high",
                    122.0,
                    122.1,
                    100.0,
                ),
                (
                    "run-success:projection:relationship",
                    "run-success",
                    "work_provenance_projection_update",
                    "lifecycle_ingestion_projection",
                    "event-child-start",
                    "subsession_started",
                    1,
                    "payload-success",
                    "session_relationships",
                    "session_relationship",
                    "codex-child",
                    "upsert",
                    "o3",
                    "high",
                    122.0,
                    122.1,
                    100.0,
                ),
                (
                    "run-success:projection:identity",
                    "run-success",
                    "work_provenance_projection_update",
                    "lifecycle_ingestion_projection",
                    "event-child-start",
                    "subsession_started",
                    1,
                    "payload-success",
                    "session_external_identities",
                    "session_external_identity",
                    "identity-child",
                    "upsert",
                    "o3",
                    "high",
                    122.0,
                    122.1,
                    100.0,
                ),
                (
                    "run-second-parent:projection:session",
                    "run-second-parent",
                    "work_provenance_projection_update",
                    "lifecycle_ingestion_projection",
                    "event-other-start",
                    "subsession_started",
                    1,
                    "payload-second-parent",
                    "sessions",
                    "session",
                    "other-child",
                    "upsert",
                    "o3",
                    "low",
                    137.0,
                    137.1,
                    100.0,
                ),
                (
                    "run-second-parent:projection:relationship",
                    "run-second-parent",
                    "work_provenance_projection_update",
                    "lifecycle_ingestion_projection",
                    "event-other-start",
                    "subsession_started",
                    1,
                    "payload-second-parent",
                    "session_relationships",
                    "session_relationship",
                    "other-child",
                    "upsert",
                    "o3",
                    "low",
                    137.0,
                    137.1,
                    100.0,
                ),
                (
                    "run-second-parent:projection:identity",
                    "run-second-parent",
                    "work_provenance_projection_update",
                    "lifecycle_ingestion_projection",
                    "event-other-start",
                    "subsession_started",
                    1,
                    "payload-second-parent",
                    "session_external_identities",
                    "session_external_identity",
                    "identity-other",
                    "upsert",
                    "o3",
                    "low",
                    137.0,
                    137.1,
                    100.0,
                ),
            ],
        )


def run_cli(
    cli_path: str,
    args: list[str],
    cwd: Path | None = None,
) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        [cli_path, *args],
        capture_output=True,
        text=True,
        check=False,
        timeout=10,
        cwd=cwd,
    )
    if result.returncode != 0:
        raise AssertionError(
            f"bmux {' '.join(args)} failed with {result.returncode}\nSTDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}"
    )
    return result


def create_git_repo(root: Path) -> str:
    root.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["git", "init"],
        cwd=root,
        capture_output=True,
        text=True,
        check=True,
        timeout=10,
    )
    target = root / "Sources" / "WorkspaceManager.swift"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text("struct WorkspaceManager {}\n", encoding="utf-8")
    return str(root)


def check_provenance_explain_json(cli_path: str, root: Path) -> None:
    repo = root / "repo"
    repository_root = create_git_repo(repo)
    database = root / "explain-work-provenance.sqlite"
    create_provenance_explain_database(database, repository_root)

    result = run_cli(
        cli_path,
        [
            "--json",
            "provenance",
            "explain",
            "Sources/WorkspaceManager.swift",
            "--database",
            str(database),
        ],
        cwd=repo,
    )
    payload = json.loads(result.stdout)
    if not payload["found"]:
        raise AssertionError(f"expected a found file explanation: {payload!r}")
    if payload["relative_path"] != "Sources/WorkspaceManager.swift":
        raise AssertionError(f"expected repository-relative path: {payload!r}")
    if payload["repository_path"] != repository_root:
        raise AssertionError(f"expected resolved repository path: {payload!r}")
    if payload["file_status"] != "modified":
        raise AssertionError(f"expected file status from contract response: {payload!r}")
    if payload["attribution_source"] != "observed" or payload["attribution_confidence"] != "high":
        raise AssertionError(f"expected attribution fields from contract response: {payload!r}")
    if payload["change_set"]["summary"] != "Workspace provenance":
        raise AssertionError(f"expected change set payload: {payload!r}")
    if payload["change_set"]["diff_fingerprint"] != "diff-1":
        raise AssertionError(f"expected change set diff fingerprint: {payload!r}")
    if payload["checkpoint"]["summary"] != "Recorded first batch":
        raise AssertionError(f"expected checkpoint payload: {payload!r}")
    if payload["contribution"]["declared_intent"] != "Capture work provenance":
        raise AssertionError(f"expected contribution payload: {payload!r}")
    if payload["session"]["id"] != "session-1" or payload["session"]["agent_kind"] != "codex":
        raise AssertionError(f"expected session payload: {payload!r}")
    if payload["work_item"]["title"] != "Explain dirty files":
        raise AssertionError(f"expected work item payload: {payload!r}")
    if payload["worktree"]["id"] != stable_worktree_id(repository_root):
        raise AssertionError(f"expected stable worktree id: {payload!r}")
    if payload["repository"]["remote_slug"] != "manaflow-ai/bmux":
        raise AssertionError(f"expected repository payload: {payload!r}")

    no_file_database = root / "explain-no-file.sqlite"
    create_provenance_explain_database(no_file_database, repository_root, include_file=False)
    no_file_result = run_cli(
        cli_path,
        [
            "--json",
            "provenance",
            "explain",
            "Sources/WorkspaceManager.swift",
            "--database",
            str(no_file_database),
        ],
        cwd=repo,
    )
    no_file = json.loads(no_file_result.stdout)
    if no_file["found"] or no_file["reason"] != "no file-level provenance has been recorded for this path":
        raise AssertionError(f"missing file should preserve bounded no-file JSON: {no_file!r}")
    if no_file["worktree"]["path"] != repository_root:
        raise AssertionError(f"missing file should still include recorded worktree: {no_file!r}")

    no_worktree_database = root / "explain-no-worktree.sqlite"
    create_provenance_explain_database(no_worktree_database, repository_root, include_worktree=False)
    no_worktree_result = run_cli(
        cli_path,
        [
            "--json",
            "provenance",
            "explain",
            "Sources/WorkspaceManager.swift",
            "--database",
            str(no_worktree_database),
        ],
        cwd=repo,
    )
    no_worktree = json.loads(no_worktree_result.stdout)
    if no_worktree["found"] or no_worktree["reason"] != "no provenance has been recorded for this Git worktree":
        raise AssertionError(f"missing worktree should preserve bounded no-worktree JSON: {no_worktree!r}")
    if no_worktree["worktree"] != {"path": repository_root}:
        raise AssertionError(f"missing worktree should fall back to repository path: {no_worktree!r}")

    no_database_result = run_cli(
        cli_path,
        [
            "--json",
            "provenance",
            "explain",
            "Sources/WorkspaceManager.swift",
            "--database",
            str(root / "missing-explain-work-provenance.sqlite"),
        ],
        cwd=repo,
    )
    no_database = json.loads(no_database_result.stdout)
    if no_database["found"] or no_database["reason"] != "no provenance database exists yet":
        raise AssertionError(f"missing database should preserve bounded no-database JSON: {no_database!r}")


def check_provenance_explain_text(cli_path: str, root: Path) -> None:
    repo = root / "repo-text"
    repository_root = create_git_repo(repo)
    database = root / "explain-text-work-provenance.sqlite"
    create_provenance_explain_database(database, repository_root)

    result = run_cli(
        cli_path,
        [
            "provenance",
            "explain",
            "Sources/WorkspaceManager.swift",
            "--database",
            str(database),
        ],
        cwd=repo,
    )
    output = result.stdout
    for expected in [
        "Provenance for Sources/WorkspaceManager.swift",
        "Status: modified",
        "Attribution: observed (high confidence)",
        "Change set: Workspace provenance",
        "Contribution: contribution-1 · active",
        "Intent: Capture work provenance",
        "Session: session-1 · codex",
        "Work item: WI-1 · Explain dirty files",
        f"Repository: {repository_root}",
    ]:
        if expected not in output:
            raise AssertionError(f"expected text output to include {expected!r}:\n{output}")


def check_provenance_session_tree_json(cli_path: str, root: Path) -> None:
    database = root / "work-provenance.sqlite"
    create_provenance_database(database)

    result = run_cli(
        cli_path,
        [
            "--json",
            "provenance",
            "sessions",
            "tree",
            "codex-parent",
            "--database",
            str(database),
        ],
    )
    payload = json.loads(result.stdout)
    if payload["root_session_id"] != "codex-parent" or not payload["found"]:
        raise AssertionError(f"expected a found parent session tree: {payload!r}")
    if payload["summary"] != {
        "external_identity_count": 2,
        "max_depth": 2,
        "relationship_count": 2,
        "session_count": 3,
    }:
        raise AssertionError(f"unexpected session tree summary: {payload!r}")
    session_ids = [row["id"] for row in payload["sessions"]]
    if session_ids != ["codex-parent", "codex-child", "codex-grandchild"]:
        raise AssertionError(f"expected depth-first session order: {payload!r}")
    if any(row["id"] == "unrelated" for row in payload["sessions"]):
        raise AssertionError(f"unrelated session leaked into tree: {payload!r}")
    relationships = payload["relationships"]
    if [row["parent_session_id"] for row in relationships] != ["codex-parent", "codex-child"]:
        raise AssertionError(f"expected bounded parent-child relationships: {payload!r}")
    identities = payload["external_identities"]
    if [row["external_id"] for row in identities] != ["subagent-1", "subagent-2"]:
        raise AssertionError(f"expected only tree external identities: {payload!r}")

    missing_result = run_cli(
        cli_path,
        [
            "--json",
            "provenance",
            "sessions",
            "tree",
            "missing-session",
            "--database",
            str(database),
        ],
    )
    missing = json.loads(missing_result.stdout)
    if missing["found"] or missing["summary"]["session_count"] != 0:
        raise AssertionError(f"missing session should return bounded empty JSON: {missing!r}")

    no_database_result = run_cli(
        cli_path,
        [
            "--json",
            "provenance",
            "sessions",
            "tree",
            "codex-parent",
            "--database",
            str(root / "missing-work-provenance.sqlite"),
        ],
    )
    no_database = json.loads(no_database_result.stdout)
    if no_database["found"] or no_database["reason"] != "no provenance database exists yet":
        raise AssertionError(f"missing database should preserve bounded empty JSON: {no_database!r}")


def check_provenance_session_tree_text(cli_path: str, root: Path) -> None:
    database = root / "work-provenance.sqlite"
    create_provenance_database(database)

    result = run_cli(
        cli_path,
        [
            "provenance",
            "sessions",
            "tree",
            "codex-parent",
            "--database",
            str(database),
        ],
    )
    output = result.stdout
    for expected in [
        "Session tree for codex-parent",
        "Sessions: 3",
        "codex-parent",
        "codex-child",
        "codex-grandchild",
    ]:
        if expected not in output:
            raise AssertionError(f"expected text output to include {expected!r}:\n{output}")


def check_provenance_lifecycle_trace_json(cli_path: str, root: Path) -> None:
    database = root / "ProvenanceObservability.sqlite"
    create_observability_database(database)

    result = run_cli(
        cli_path,
        [
            "--json",
            "provenance",
            "traces",
            "lifecycle-ingestion",
            "--observability-database",
            str(database),
            "--limit",
            "10",
        ],
    )
    payload = json.loads(result.stdout)
    if payload["summary"] != {
        "conflicted_identity_resolution_count": 1,
        "failed_run_count": 1,
        "identity_resolution_count": 3,
        "projection_lineage_count": 6,
        "resolved_identity_resolution_count": 2,
        "run_count": 3,
        "stage_count": 9,
        "unresolved_identity_resolution_count": 1,
    }:
        raise AssertionError(f"unexpected trace summary: {payload!r}")
    run_ids = [row["pipeline_run_id"] for row in payload["runs"]]
    if run_ids != ["run-second-parent", "run-failed", "run-success"]:
        raise AssertionError(f"expected bounded lifecycle trace order: {payload!r}")
    if any(row["pipeline_run_id"] == "run-other" for row in payload["runs"]):
        raise AssertionError(f"non-lifecycle trace leaked into output: {payload!r}")
    stage_names = [row["stage_name"] for row in payload["stages"][:3]]
    if stage_names != [
        "lifecycle_change_received",
        "work_provenance_event_append",
        "work_provenance_projection_update",
    ]:
        raise AssertionError(f"expected O1 stage sequence: {payload!r}")
    identity_rows = payload["identity_resolutions"]
    if [row["pipeline_run_id"] for row in identity_rows] != [
        "run-second-parent",
        "run-failed",
        "run-success",
    ]:
        raise AssertionError(f"expected O2 identity rows to follow trace order: {payload!r}")
    failed_identity = identity_rows[1]
    if failed_identity["selected_child_session_id"] != "codex-child":
        raise AssertionError(f"expected selected child session id in identity row: {payload!r}")
    if failed_identity["input_identity_value_hash"] == "subagent-1":
        raise AssertionError(f"identity row should not expose raw subsession id: {payload!r}")
    if failed_identity.get("conflict_reason") is None:
        raise AssertionError(f"expected failed trace identity conflict reason: {payload!r}")

    lineage_rows = payload["projection_lineage"]
    if len(lineage_rows) != 6:
        raise AssertionError(f"expected O3 projection lineage rows: {payload!r}")
    if {row["pipeline_run_id"] for row in lineage_rows} != {"run-success", "run-second-parent"}:
        raise AssertionError(f"expected lineage only for successful projections: {payload!r}")
    if any(row["pipeline_run_id"] == "run-failed" for row in lineage_rows):
        raise AssertionError(f"failed projection should not have lineage rows: {payload!r}")
    success_lineage = [row for row in lineage_rows if row["pipeline_run_id"] == "run-success"]
    if [row["target_entity_kind"] for row in success_lineage] != [
        "session",
        "session_relationship",
        "session_external_identity",
    ]:
        raise AssertionError(f"expected bounded O3 target lineage order: {payload!r}")
    if any(row["source_payload_hash"] == "subagent-1" for row in lineage_rows):
        raise AssertionError(f"lineage rows should not expose raw subsession ids: {payload!r}")

    failed_result = run_cli(
        cli_path,
        [
            "--json",
            "provenance",
            "traces",
            "lifecycle-ingestion",
            "--observability-database",
            str(database),
            "--status",
            "failed",
        ],
    )
    failed_payload = json.loads(failed_result.stdout)
    if [row["pipeline_run_id"] for row in failed_payload["runs"]] != ["run-failed"]:
        raise AssertionError(f"expected status filter to return only failed trace: {failed_payload!r}")
    if failed_payload["summary"]["failed_run_count"] != 1:
        raise AssertionError(f"expected filtered failed summary: {failed_payload!r}")

    run_result = run_cli(
        cli_path,
        [
            "--json",
            "provenance",
            "traces",
            "lifecycle-ingestion",
            "--observability-database",
            str(database),
            "--run",
            "run-success",
        ],
    )
    run_payload = json.loads(run_result.stdout)
    if [row["pipeline_run_id"] for row in run_payload["runs"]] != ["run-success"]:
        raise AssertionError(f"expected run filter to return exact trace: {run_payload!r}")
    if [row["pipeline_run_id"] for row in run_payload["stages"]] != [
        "run-success",
        "run-success",
        "run-success",
    ]:
        raise AssertionError(f"expected run filter to scope stages: {run_payload!r}")

    if {row["pipeline_run_id"] for row in run_payload["projection_lineage"]} != {"run-success"}:
        raise AssertionError(f"expected run filter to scope projection lineage: {run_payload!r}")

    parent_result = run_cli(
        cli_path,
        [
            "--json",
            "provenance",
            "traces",
            "lifecycle-ingestion",
            "--observability-database",
            str(database),
            "--parent-session",
            "codex-parent",
        ],
    )
    parent_payload = json.loads(parent_result.stdout)
    if [row["pipeline_run_id"] for row in parent_payload["runs"]] != ["run-failed", "run-success"]:
        raise AssertionError(f"expected parent filter to exclude other parent: {parent_payload!r}")

    child_result = run_cli(
        cli_path,
        [
            "--json",
            "provenance",
            "traces",
            "lifecycle-ingestion",
            "--observability-database",
            str(database),
            "--child-session",
            "other-child",
        ],
    )
    child_payload = json.loads(child_result.stdout)
    if [row["pipeline_run_id"] for row in child_payload["runs"]] != ["run-second-parent"]:
        raise AssertionError(f"expected child filter to return matching child trace: {child_payload!r}")


def check_provenance_lifecycle_trace_text(cli_path: str, root: Path) -> None:
    database = root / "ProvenanceObservability.sqlite"
    create_observability_database(database)

    result = run_cli(
        cli_path,
        [
            "provenance",
            "traces",
            "lifecycle-ingestion",
            "--observability-database",
            str(database),
        ],
    )
    output = result.stdout
    for expected in [
        "Lifecycle ingestion traces: 3",
        "run-second-parent",
        "run-failed",
        "run-success",
        "stages: 3",
    ]:
        if expected not in output:
            raise AssertionError(f"expected text output to include {expected!r}:\n{output}")


def main() -> int:
    try:
        bundled_cli = os.environ.get("BMUX_BUNDLED_CLI_PATH")
        if bundled_cli and os.path.exists(bundled_cli) and os.access(bundled_cli, os.X_OK):
            cli_path = bundled_cli
        else:
            cli_path = resolve_bmux_cli()
    except Exception as exc:
        print(f"FAIL: {exc}")
        return 1

    with tempfile.TemporaryDirectory(prefix="bmux-provenance-cli-", dir="/tmp") as td:
        root = Path(td)
        try:
            check_provenance_explain_json(cli_path, root)
            check_provenance_explain_text(cli_path, root)
            check_provenance_session_tree_json(cli_path, root)
            check_provenance_session_tree_text(cli_path, root)
            check_provenance_lifecycle_trace_json(cli_path, root)
            check_provenance_lifecycle_trace_text(cli_path, root)
        except Exception as exc:
            print(f"FAIL: {exc}")
            return 1

    print("PASS: Provenance CLI")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
