#!/usr/bin/env python3
"""Regression checks for the provenance CLI."""

from __future__ import annotations

import json
import hashlib
import os
import sqlite3
import subprocess
import tempfile
import textwrap
from pathlib import Path

from claude_teams_test_utils import resolve_bmux_cli

SESSION_TREE_SEEDER_PACKAGE = (
    Path(__file__).parent / "fixtures" / "provenance-engine-session-tree-seeder"
)
FILE_EXPLANATION_SEEDER_PACKAGE = (
    Path(__file__).parent / "fixtures" / "provenance-engine-file-explanation-seeder"
)
CURRENT_CONTEXT_SEEDER_PACKAGE = (
    Path(__file__).parent / "fixtures" / "provenance-engine-current-context-seeder"
)


def stable_id(prefix: str, value: str) -> str:
    return f"{prefix}-{hashlib.sha256(value.encode()).hexdigest()[:24]}"


def stable_repository_id(repository_root: str) -> str:
    return stable_id("repository", repository_root)


def stable_worktree_id(repository_root: str) -> str:
    return stable_id("worktree", repository_root)


def create_provenance_database(path: Path, scenario: str = "basic") -> None:
    result = subprocess.run(
        [
            "swift",
            "run",
            "--package-path",
            str(SESSION_TREE_SEEDER_PACKAGE),
            "--scratch-path",
            str(path.parent / "session-tree-seeder-build"),
            "ProvenanceEngineSessionTreeSeeder",
            str(path),
            scenario,
        ],
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        raise AssertionError(
            "failed to seed session tree through Provenance Engine SDK\n"
            f"stdout={result.stdout}\nstderr={result.stderr}"
        )


def create_legacy_provenance_context_seed_database(
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


def create_provenance_explain_database(
    path: Path,
    repository_root: str,
    include_worktree: bool = True,
    include_file: bool = True,
) -> None:
    command = [
        "swift",
        "run",
        "--package-path",
        str(FILE_EXPLANATION_SEEDER_PACKAGE),
        "--scratch-path",
        str(path.parent / "file-explanation-seeder-build"),
        "ProvenanceEngineFileExplanationSeeder",
        str(path),
        repository_root,
        stable_repository_id(repository_root),
        stable_worktree_id(repository_root),
    ]
    if not include_worktree:
        command.append("--no-worktree")
    if not include_file:
        command.append("--no-file")
    env = os.environ.copy()
    env.setdefault("CLANG_MODULE_CACHE_PATH", "/tmp/bmux-provenance-engine-clang-cache")
    env.setdefault("SWIFTPM_CACHE_PATH", "/tmp/bmux-provenance-engine-swiftpm-cache")
    result = subprocess.run(command, text=True, capture_output=True, env=env)
    if result.returncode != 0:
        raise AssertionError(
            "failed to seed file explanation through Provenance Engine SDK:\n"
            f"stdout:\n{result.stdout}\nstderr:\n{result.stderr}"
        )


def create_provenance_context_database(path: Path, repository_root: str) -> None:
    if path.exists():
        path.unlink()
    result = subprocess.run(
        [
            "swift",
            "run",
            "--package-path",
            str(CURRENT_CONTEXT_SEEDER_PACKAGE),
            "--scratch-path",
            str(path.parent / "current-context-seeder-build"),
            "ProvenanceEngineCurrentContextSeeder",
            str(path),
            repository_root,
            stable_repository_id(repository_root),
            stable_worktree_id(repository_root),
        ],
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        raise AssertionError(
            "failed to seed current context through Provenance Engine SDK\n"
            f"stdout={result.stdout}\nstderr={result.stderr}"
        )
    return

    create_legacy_provenance_context_seed_database(path, repository_root)
    repository_id = stable_repository_id(repository_root)
    worktree_id = stable_worktree_id(repository_root)
    with sqlite3.connect(path) as conn:
        conn.execute(
            """
            INSERT INTO work_items (id, title, status, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?)
            """,
            ("WI-context", "Current context", "active", 200.0, 200.0),
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
                    f"session-extra-{index:02d}",
                    "codex",
                    f"workspace-{index}",
                    f"surface-{index}",
                    worktree_id,
                    repository_root,
                    "active",
                    200.0 + index,
                    300.0 + index,
                )
                for index in range(11)
            ]
            + [
                (
                    "session-completed",
                    "codex",
                    "workspace-completed",
                    "surface-completed",
                    worktree_id,
                    repository_root,
                    "completed",
                    999.0,
                    999.0,
                )
            ],
        )
        conn.executemany(
            """
            INSERT INTO work_contributions (
                id, session_id, worktree_id, work_item_id, declared_intent,
                expected_scope_json, status, started_at, ended_at,
                assignment_confidence, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    f"contribution-extra-{index:02d}",
                    f"session-extra-{index:02d}",
                    worktree_id,
                    "WI-context",
                    f"Intent {index:02d}",
                    json.dumps([]),
                    "active",
                    200.0 + index,
                    None,
                    "medium",
                    300.0 + index,
                )
                for index in range(11)
            ]
            + [
                (
                    "contribution-completed",
                    "session-completed",
                    worktree_id,
                    "WI-context",
                    "Completed work",
                    json.dumps([]),
                    "completed",
                    999.0,
                    1000.0,
                    "medium",
                    1000.0,
                ),
                (
                    "conflict-a",
                    "session-extra-10",
                    worktree_id,
                    "WI-context",
                    "Conflict A",
                    json.dumps([]),
                    "active",
                    700.0,
                    None,
                    "medium",
                    700.0,
                ),
                (
                    "conflict-b",
                    "session-extra-09",
                    worktree_id,
                    "WI-context",
                    "Conflict B",
                    json.dumps([]),
                    "active",
                    701.0,
                    None,
                    "medium",
                    701.0,
                ),
            ],
        )
        conn.executemany(
            """
            INSERT INTO checkpoints (
                id, contribution_id, sequence, git_head, diff_fingerprint,
                summary, status, validation_state, semantic_confidence,
                freshness, created_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    f"checkpoint-context-{index:02d}",
                    f"contribution-extra-{index:02d}",
                    index,
                    f"head-{index:02d}",
                    f"diff-context-{index:02d}",
                    f"Checkpoint {index:02d}",
                    "in_progress",
                    "not_run",
                    "medium",
                    "fresh",
                    600.0 + index,
                )
                for index in range(7)
            ],
        )
        conn.executemany(
            """
            INSERT INTO validation_runs (
                id, checkpoint_id, contribution_id, command, status,
                summary, started_at, ended_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    f"validation-context-{index:02d}",
                    f"checkpoint-context-{index:02d}",
                    None,
                    f"test-command-{index:02d}",
                    "passed",
                    f"Validation {index:02d}",
                    690.0 + index,
                    700.0 + index,
                )
                for index in range(7)
            ],
        )
        conn.executemany(
            """
            INSERT INTO change_sets (
                id, checkpoint_id, contribution_id, worktree_id,
                summary, diff_fingerprint, created_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    f"changeset-dirty-{index:02d}",
                    None,
                    f"contribution-extra-{index % 11:02d}",
                    worktree_id,
                    f"Dirty {index:02d}",
                    f"dirty-{index:02d}",
                    390.0 + index,
                )
                for index in range(30)
            ]
            + [
                (
                    f"changeset-unattributed-{index:02d}",
                    None,
                    None,
                    worktree_id,
                    f"Unattributed {index:02d}",
                    f"unattributed-{index:02d}",
                    490.0 + index,
                )
                for index in range(18)
            ]
            + [
                (
                    f"changeset-conflict-{index:02d}-a",
                    None,
                    "conflict-a",
                    worktree_id,
                    f"Conflict {index:02d} A",
                    f"conflict-{index:02d}-a",
                    790.0 + index,
                )
                for index in range(12)
            ]
            + [
                (
                    f"changeset-conflict-{index:02d}-b",
                    None,
                    "conflict-b",
                    worktree_id,
                    f"Conflict {index:02d} B",
                    f"conflict-{index:02d}-b",
                    790.1 + index,
                )
                for index in range(12)
            ],
        )
        conn.executemany(
            """
            INSERT INTO file_changes (
                id, change_set_id, repository_id, worktree_id, path, status,
                before_hash, after_hash, attribution_source,
                attribution_confidence, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    f"file-dirty-{index:02d}",
                    f"changeset-dirty-{index:02d}",
                    repository_id,
                    worktree_id,
                    f"Sources/Dirty{index:02d}.swift",
                    "modified",
                    None,
                    None,
                    "observed",
                    "medium",
                    400.0 + index,
                )
                for index in range(30)
            ]
            + [
                (
                    f"file-unattributed-{index:02d}",
                    f"changeset-unattributed-{index:02d}",
                    repository_id,
                    worktree_id,
                    f"Sources/Unattributed{index:02d}.swift",
                    "modified",
                    None,
                    None,
                    "unattributed",
                    "low",
                    500.0 + index,
                )
                for index in range(18)
            ]
            + [
                (
                    f"file-conflict-{index:02d}-a",
                    f"changeset-conflict-{index:02d}-a",
                    repository_id,
                    worktree_id,
                    f"Sources/Conflict{index:02d}.swift",
                    "modified",
                    None,
                    None,
                    "observed",
                    "medium",
                    800.0 + index,
                )
                for index in range(12)
            ]
            + [
                (
                    f"file-conflict-{index:02d}-b",
                    f"changeset-conflict-{index:02d}-b",
                    repository_id,
                    worktree_id,
                    f"Sources/Conflict{index:02d}.swift",
                    "modified",
                    None,
                    None,
                    "observed",
                    "medium",
                    800.1 + index,
                )
                for index in range(12)
            ],
        )



def create_provenance_context_database_with_mode(path: Path, repository_root: str, mode: str) -> None:
    if path.exists():
        path.unlink()
    result = subprocess.run(
        [
            "swift", "run", "--package-path", str(CURRENT_CONTEXT_SEEDER_PACKAGE),
            "--scratch-path", str(path.parent / "current-context-seeder-build"),
            "ProvenanceEngineCurrentContextSeeder", str(path), repository_root,
            stable_repository_id(repository_root), stable_worktree_id(repository_root), mode,
        ],
        text=True, capture_output=True, check=False,
    )
    if result.returncode != 0:
        raise AssertionError(
            "failed to seed current context through Provenance Engine SDK\n"
            f"stdout={result.stdout}\nstderr={result.stderr}"
        )

def create_worktree_list_database(path: Path, include_rows: bool = True) -> None:
    if path.exists():
        path.unlink()
    seed_engine_worktree_database(path, include_rows=include_rows)


def provenance_engine_package_dependency() -> str:
    override = os.environ.get("PROVENANCE_ENGINE_PACKAGE_PATH")
    if override:
        return f'.package(path: "{Path(override).expanduser()}")'

    sibling = Path(__file__).resolve().parents[1].parent / "provenance-engine"
    if sibling.exists():
        return f'.package(path: "{sibling}")'

    return '.package(url: "git@github.com:BrianBusby/provenance-engine.git", revision: "7ed4450410f344f01472ba62f534a04c6c0d2774")'


def ensure_worktree_seed_package(root: Path) -> Path:
    package = root / "provenance-engine-seed"
    source_dir = package / "Sources" / "SeedWorktrees"
    source_dir.mkdir(parents=True, exist_ok=True)
    (package / "Package.swift").write_text(
        textwrap.dedent(
            f"""
            // swift-tools-version: 6.0

            import PackageDescription

            let package = Package(
                name: "SeedWorktrees",
                platforms: [.macOS(.v14)],
                dependencies: [
                    {provenance_engine_package_dependency()},
                ],
                targets: [
                    .executableTarget(
                        name: "SeedWorktrees",
                        dependencies: [
                            .product(name: "ProvenanceEngineContracts", package: "provenance-engine"),
                            .product(name: "ProvenanceEngineSDK", package: "provenance-engine"),
                        ]
                    ),
                ],
                swiftLanguageModes: [.v6]
            )
            """
        ).strip()
        + "\n"
    )
    (source_dir / "main.swift").write_text(
        textwrap.dedent(
            """
            import Foundation
            import ProvenanceEngineContracts
            import ProvenanceEngineSDK

            @main
            struct SeedWorktrees {
                static func main() async throws {
                    let arguments = CommandLine.arguments.dropFirst()
                    guard let databasePath = arguments.first else {
                        throw SeedError.missingDatabasePath
                    }
                    let includeRows = !arguments.contains("--empty")
                    let databaseURL = URL(fileURLWithPath: databasePath)
                    let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: databaseURL)
                    guard includeRows else { return }

                    try await appendWorktree(
                        client: client,
                        eventID: "seed-worktree-old",
                        repositoryID: "repo-1",
                        repositoryPath: "/repo/old",
                        remoteSlug: "manaflow-ai/bmux",
                        worktreeID: "worktree-old",
                        branch: "main",
                        currentHEAD: "oldhead",
                        isDirty: false,
                        reconciledAt: 140,
                        updatedAt: 150
                    )
                    try await appendWorktree(
                        client: client,
                        eventID: "seed-worktree-new",
                        repositoryID: "repo-2",
                        repositoryPath: "/repo/new",
                        remoteSlug: "manaflow-ai/provenance",
                        worktreeID: "worktree-new",
                        branch: "feature/provenance",
                        currentHEAD: "newhead",
                        isDirty: true,
                        reconciledAt: 190,
                        updatedAt: 200
                    )
                }

                private static func appendWorktree(
                    client: any ProvenanceEngineClient,
                    eventID: String,
                    repositoryID: String,
                    repositoryPath: String,
                    remoteSlug: String,
                    worktreeID: String,
                    branch: String,
                    currentHEAD: String,
                    isDirty: Bool,
                    reconciledAt: TimeInterval,
                    updatedAt: TimeInterval
                ) async throws {
                    let createdAt = Date(timeIntervalSince1970: 100)
                    let updatedDate = Date(timeIntervalSince1970: updatedAt)
                    let repository = ProvenanceRepositoryRecord(
                        id: repositoryID,
                        path: repositoryPath,
                        remoteSlug: remoteSlug,
                        createdAt: createdAt,
                        updatedAt: updatedDate
                    )
                    let worktree = ProvenanceWorktreeRecord(
                        id: worktreeID,
                        repositoryID: repositoryID,
                        path: repositoryPath,
                        branch: branch,
                        currentHEAD: currentHEAD,
                        isDirty: isDirty,
                        status: "active",
                        lastReconciledAt: Date(timeIntervalSince1970: reconciledAt),
                        updatedAt: updatedDate
                    )
                    let event = ProvenanceEvent(
                        id: eventID,
                        eventType: .worktreeObserved,
                        timestamp: updatedDate,
                        repositoryID: repositoryID,
                        worktreeID: worktreeID,
                        source: .observed,
                        confidence: .high,
                        payload: ProvenanceEventPayload(
                            repository: repository,
                            worktree: worktree
                        )
                    )
                    _ = try await client.appendEvent(ProvenanceAppendEventRequest(event: event))
                }
            }

            enum SeedError: Error {
                case missingDatabasePath
            }
            """
        ).strip()
        + "\n"
    )
    return package


def seed_engine_worktree_database(path: Path, include_rows: bool) -> None:
    package = ensure_worktree_seed_package(path.parent)
    command = [
        "swift",
        "run",
        "--package-path",
        str(package),
        "--scratch-path",
        str(path.parent / "provenance-engine-seed-build"),
        "SeedWorktrees",
        str(path),
    ]
    if not include_rows:
        command.append("--empty")
    env = os.environ.copy()
    env.setdefault("CLANG_MODULE_CACHE_PATH", "/tmp/bmux-provenance-engine-clang-cache")
    env.setdefault("SWIFTPM_CACHE_PATH", "/tmp/bmux-provenance-engine-swiftpm-cache")
    result = subprocess.run(command, text=True, capture_output=True, env=env)
    if result.returncode != 0:
        raise AssertionError(
            "failed to seed provenance-engine fixture via public SDK:\n"
            f"stdout:\n{result.stdout}\nstderr:\n{result.stderr}"
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
                    "AgentSessionLifecycleChange",
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
                    "AgentSessionLifecycleChange",
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
                    "AgentSessionLifecycleChange",
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
                    "session_lifecycle_identity",
                    "o2",
                    "AgentSessionLifecycleChange",
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
                    "session_lifecycle_identity",
                    "o2",
                    "AgentSessionLifecycleChange",
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
                    "session_lifecycle_identity",
                    "o2",
                    "AgentSessionLifecycleChange",
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
                    "session_started",
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
                    "session_started",
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
                    "session_started",
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
                    "session_started",
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
                    "session_started",
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
                    "session_started",
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
    (target.parent / "Unattributed.swift").write_text("struct Unattributed {}\n", encoding="utf-8")
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
    if payload["updated_at"] != 150.0:
        raise AssertionError(f"expected newest file evidence to win: {payload!r}")

    absolute_result = run_cli(
        cli_path,
        [
            "--json",
            "provenance",
            "explain",
            str(repo / "Sources" / "WorkspaceManager.swift"),
            "--database",
            str(database),
        ],
        cwd=repo,
    )
    absolute = json.loads(absolute_result.stdout)
    if not absolute["found"] or absolute["relative_path"] != "Sources/WorkspaceManager.swift":
        raise AssertionError(f"absolute path should normalize to repository-relative path: {absolute!r}")

    unattributed_result = run_cli(
        cli_path,
        [
            "--json",
            "provenance",
            "explain",
            "Sources/Unattributed.swift",
            "--database",
            str(database),
        ],
        cwd=repo,
    )
    unattributed = json.loads(unattributed_result.stdout)
    if not unattributed["found"] or unattributed["attribution_source"] != "unattributed":
        raise AssertionError(f"expected unattributed file explanation: {unattributed!r}")
    if unattributed["contribution"] is not None or unattributed["session"] is not None:
        raise AssertionError(f"unattributed explanation should not expose attribution records: {unattributed!r}")

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


    unknown_flag = subprocess.run(
        [
            cli_path,
            "provenance",
            "explain",
            "Sources/WorkspaceManager.swift",
            "--bogus",
            "--database",
            str(database),
        ],
        capture_output=True,
        text=True,
        check=False,
        timeout=10,
        cwd=repo,
    )
    if unknown_flag.returncode == 0 or "unknown flag" not in unknown_flag.stderr:
        raise AssertionError(f"unknown flag behavior changed: {unknown_flag!r}")

    extra_argument = subprocess.run(
        [
            cli_path,
            "provenance",
            "explain",
            "Sources/WorkspaceManager.swift",
            "extra",
            "--database",
            str(database),
        ],
        capture_output=True,
        text=True,
        check=False,
        timeout=10,
        cwd=repo,
    )
    if extra_argument.returncode == 0 or "unexpected argument" not in extra_argument.stderr:
        raise AssertionError(f"extra argument behavior changed: {extra_argument!r}")

    no_git = subprocess.run(
        [
            cli_path,
            "provenance",
            "explain",
            "Sources/WorkspaceManager.swift",
            "--database",
            str(database),
        ],
        capture_output=True,
        text=True,
        check=False,
        timeout=10,
        cwd=root,
    )
    if no_git.returncode == 0 or "requires a Git worktree" not in no_git.stderr:
        raise AssertionError(f"missing Git worktree behavior changed: {no_git!r}")

    outside_worktree = subprocess.run(
        [
            cli_path,
            "provenance",
            "explain",
            "../outside/Missing.swift",
            "--database",
            str(database),
        ],
        capture_output=True,
        text=True,
        check=False,
        timeout=10,
        cwd=repo,
    )
    if outside_worktree.returncode == 0 or "outside the current Git worktree" not in outside_worktree.stderr:
        raise AssertionError(f"outside worktree behavior changed: {outside_worktree!r}")


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

    unattributed_result = run_cli(
        cli_path,
        [
            "provenance",
            "explain",
            "Sources/Unattributed.swift",
            "--database",
            str(database),
        ],
        cwd=repo,
    )
    if "Note: bmux observed this dirty file, but no session has claimed it yet." not in unattributed_result.stdout:
        raise AssertionError(f"expected unattributed note in text output:\n{unattributed_result.stdout}")


def check_provenance_context_json(cli_path: str, root: Path) -> None:
    repo = root / "context-repo"
    repository_root = create_git_repo(repo)
    database = root / "context-work-provenance.sqlite"
    create_provenance_context_database(database, repository_root)

    result = run_cli(
        cli_path,
        [
            "--json",
            "provenance",
            "context",
            "current",
            "--database",
            str(database),
        ],
        cwd=repo,
    )
    payload = json.loads(result.stdout)
    if not payload["found"] or payload["reason"] is not None:
        raise AssertionError(f"expected found current context: {payload!r}")
    if payload["repository_path"] != repository_root:
        raise AssertionError(f"expected resolved repository path: {payload!r}")
    if payload["worktree"]["id"] != stable_worktree_id(repository_root):
        raise AssertionError(f"expected worktree payload from contract: {payload!r}")
    if payload["repository"]["remote_slug"] != "manaflow-ai/bmux":
        raise AssertionError(f"expected repository payload from contract: {payload!r}")
    expected_summary = {
        "active_session_count": 10,
        "dirty_file_count": 25,
        "unattributed_change_count": 15,
        "recent_checkpoint_count": 5,
        "validation_run_count": 5,
        "conflict_count": 10,
    }
    if payload["summary"] != expected_summary:
        raise AssertionError(f"expected bounded context summary: {payload!r}")
    if [row["id"] for row in payload["active_sessions"][:4]] != [
        "session-extra-10",
        "session-extra-10",
        "session-extra-09",
        "session-extra-09",
    ]:
        raise AssertionError(f"expected active sessions newest-first and bounded: {payload!r}")
    if any(row["id"] == "session-completed" for row in payload["active_sessions"]):
        raise AssertionError(f"completed session leaked into active sessions: {payload!r}")
    if [row["path"] for row in payload["dirty_files"][:2]] != [
        "Sources/Conflict11.swift",
        "Sources/Conflict10.swift",
    ]:
        raise AssertionError(f"expected dirty files newest-first and bounded: {payload!r}")
    if [row["path"] for row in payload["unattributed_changes"][:2]] != [
        "Sources/Unattributed17.swift",
        "Sources/Unattributed16.swift",
    ]:
        raise AssertionError(f"expected unattributed changes newest-first and bounded: {payload!r}")
    if [row["id"] for row in payload["recent_checkpoints"]] != [
        "checkpoint-context-06",
        "checkpoint-context-05",
        "checkpoint-context-04",
        "checkpoint-context-03",
        "checkpoint-context-02",
    ]:
        raise AssertionError(f"expected recent checkpoints newest-first and bounded: {payload!r}")
    if [row["id"] for row in payload["validation_runs"]] != [
        "validation-context-06",
        "validation-context-05",
        "validation-context-04",
        "validation-context-03",
        "validation-context-02",
    ]:
        raise AssertionError(f"expected validation runs newest-first and bounded: {payload!r}")
    if [row["path"] for row in payload["conflicts"][:2]] != [
        "Sources/Conflict11.swift",
        "Sources/Conflict10.swift",
    ]:
        raise AssertionError(f"expected conflict rows newest-first and bounded: {payload!r}")
    if any(row["active_contribution_count"] != 2 for row in payload["conflicts"]):
        raise AssertionError(f"expected conflict contribution counts: {payload!r}")

    empty_database = root / "context-empty-work-provenance.sqlite"
    create_provenance_context_database_with_mode(empty_database, repository_root, "--empty")
    empty_result = run_cli(
        cli_path,
        [
            "--json",
            "provenance",
            "context",
            "current",
            "--database",
            str(empty_database),
        ],
        cwd=repo,
    )
    empty = json.loads(empty_result.stdout)
    if not empty["found"] or any(empty["summary"].values()):
        raise AssertionError(f"empty sections should preserve found empty context: {empty!r}")

    no_worktree_database = root / "context-no-worktree.sqlite"
    create_provenance_context_database_with_mode(no_worktree_database, repository_root, "--no-worktree")
    no_worktree_result = run_cli(
        cli_path,
        [
            "--json",
            "provenance",
            "context",
            "current",
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
            "context",
            "current",
            "--database",
            str(root / "missing-context-work-provenance.sqlite"),
        ],
        cwd=repo,
    )
    no_database = json.loads(no_database_result.stdout)
    if no_database["found"] or no_database["reason"] != "no provenance database exists yet":
        raise AssertionError(f"missing database should preserve bounded no-database JSON: {no_database!r}")


def check_provenance_context_text(cli_path: str, root: Path) -> None:
    repo = root / "context-text-repo"
    repository_root = create_git_repo(repo)
    database = root / "context-text-work-provenance.sqlite"
    create_provenance_context_database(database, repository_root)

    result = run_cli(
        cli_path,
        [
            "provenance",
            "context",
            "current",
            "--database",
            str(database),
        ],
        cwd=repo,
    )
    output = result.stdout
    for expected in [
        f"Provenance context for {repository_root}",
        "Worktree: provenance-extraction-phase2-contracts · active · dirty",
        "Active sessions: 10",
        "Dirty files: 25",
        "Unattributed changes: 15",
        "Recent checkpoints: 5",
        "Validation runs: 5",
        "Conflicts: 10",
        "Active session rows:",
        "  session-extra-10 · codex · active",
        "Unattributed files:",
        "  modified Sources/Unattributed17.swift · unattributed/low",
        "Potential file overlaps:",
        "  Sources/Conflict11.swift · contributions conflict-a,conflict-b",
    ]:
        if expected not in output:
            raise AssertionError(f"expected text output to include {expected!r}:\n{output}")

    no_database_result = run_cli(
        cli_path,
        [
            "provenance",
            "context",
            "current",
            "--database",
            str(root / "missing-context-text-work-provenance.sqlite"),
        ],
        cwd=repo,
    )
    if "No provenance context found" not in no_database_result.stdout:
        raise AssertionError(f"no-database text output changed:\n{no_database_result.stdout}")
    if "Reason: no provenance database exists yet" not in no_database_result.stdout:
        raise AssertionError(f"no-database text reason changed:\n{no_database_result.stdout}")


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

    limit_database = root / "limited-session-tree-work-provenance.sqlite"
    create_provenance_database(limit_database, scenario="limit")
    limit_result = run_cli(
        cli_path,
        [
            "--json",
            "provenance",
            "sessions",
            "tree",
            "limit-root",
            "--database",
            str(limit_database),
        ],
    )
    limited = json.loads(limit_result.stdout)
    if limited["summary"]["session_count"] != 100:
        raise AssertionError(f"session tree should preserve the legacy 100-session cap: {limited!r}")
    if limited["summary"]["relationship_count"] != 99:
        raise AssertionError(f"session tree should include relationships for returned sessions: {limited!r}")


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


def check_provenance_worktrees_json(cli_path: str, root: Path) -> None:
    database = root / "worktrees-work-provenance.sqlite"
    create_worktree_list_database(database)

    result = run_cli(
        cli_path,
        [
            "--json",
            "provenance",
            "worktrees",
            "list",
            "--database",
            str(database),
        ],
    )
    payload = json.loads(result.stdout)
    if payload["count"] != 2 or payload["reason"] is not None:
        raise AssertionError(f"expected worktree count with no reason: {payload!r}")
    rows = payload["worktrees"]
    if [row["worktree"]["id"] for row in rows] != ["worktree-new", "worktree-old"]:
        raise AssertionError(f"expected newest worktree ordering: {payload!r}")
    newest = rows[0]
    if newest["worktree"] != {
        "branch": "feature/provenance",
        "current_head": "newhead",
        "id": "worktree-new",
        "is_dirty": True,
        "last_reconciled_at": 190.0,
        "path": "/repo/new",
        "repository_id": "repo-2",
        "status": "active",
        "updated_at": 200.0,
    }:
        raise AssertionError(f"expected worktree JSON shape to be preserved: {payload!r}")
    if newest["repository"] != {
        "id": "repo-2",
        "path": "/repo/new",
        "remote_slug": "manaflow-ai/provenance",
    }:
        raise AssertionError(f"expected repository JSON shape to be preserved: {payload!r}")

    empty_database = root / "worktrees-empty.sqlite"
    create_worktree_list_database(empty_database, include_rows=False)
    empty_result = run_cli(
        cli_path,
        [
            "--json",
            "provenance",
            "worktrees",
            "list",
            "--database",
            str(empty_database),
        ],
    )
    empty = json.loads(empty_result.stdout)
    if empty != {"count": 0, "reason": None, "worktrees": []}:
        raise AssertionError(f"empty database should preserve empty list JSON: {empty!r}")

    no_database_result = run_cli(
        cli_path,
        [
            "--json",
            "provenance",
            "worktrees",
            "list",
            "--database",
            str(root / "missing-worktrees.sqlite"),
        ],
    )
    no_database = json.loads(no_database_result.stdout)
    if no_database != {
        "count": 0,
        "reason": "no provenance database exists yet",
        "worktrees": [],
    }:
        raise AssertionError(f"missing database should preserve no-database JSON: {no_database!r}")


def check_provenance_worktrees_text(cli_path: str, root: Path) -> None:
    database = root / "worktrees-text.sqlite"
    create_worktree_list_database(database)

    result = run_cli(
        cli_path,
        [
            "provenance",
            "worktrees",
            "list",
            "--database",
            str(database),
        ],
    )
    output = result.stdout
    for expected in [
        "Known provenance worktrees: 2",
        "  /repo/new · feature/provenance · active · dirty",
        "  /repo/old · main · active · clean",
    ]:
        if expected not in output:
            raise AssertionError(f"expected text output to include {expected!r}:\n{output}")

    empty_database = root / "worktrees-text-empty.sqlite"
    create_worktree_list_database(empty_database, include_rows=False)
    empty_result = run_cli(
        cli_path,
        [
            "provenance",
            "worktrees",
            "list",
            "--database",
            str(empty_database),
        ],
    )
    if empty_result.stdout.strip() != "No provenance worktrees recorded.":
        raise AssertionError(f"empty text output changed:\n{empty_result.stdout}")

    no_database_result = run_cli(
        cli_path,
        [
            "provenance",
            "worktrees",
            "list",
            "--database",
            str(root / "missing-worktrees-text.sqlite"),
        ],
    )
    if no_database_result.stdout.strip() != "no provenance database exists yet":
        raise AssertionError(f"no-database text output changed:\n{no_database_result.stdout}")


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
            check_provenance_context_json(cli_path, root)
            check_provenance_context_text(cli_path, root)
            check_provenance_session_tree_json(cli_path, root)
            check_provenance_session_tree_text(cli_path, root)
            check_provenance_worktrees_json(cli_path, root)
            check_provenance_worktrees_text(cli_path, root)
            check_provenance_lifecycle_trace_json(cli_path, root)
            check_provenance_lifecycle_trace_text(cli_path, root)
        except Exception as exc:
            print(f"FAIL: {exc}")
            return 1

    print("PASS: Provenance CLI")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
