# Implementation Map

This map links architectural components to representative implementation
entrypoints. It is not a file inventory.

## bmux Runtime and UI

| Component | Package/module | Entry locations |
| --- | --- | --- |
| Native app shell and workspace model | root macOS app | `Sources/ContentView.swift`, `Sources/TabManager.swift`, `Sources/Workspace.swift` |
| Surface and panel hosting | root macOS app | `Sources/Panels/AgentSessionPanel.swift`, `Sources/Panels/AgentSessionPanelView.swift`, `Sources/Panels/AgentSessionWebRenderer.swift` |
| Provider runtime/session identity | root macOS app | `Sources/AgentSessionProvider.swift`, `Sources/AgentSessionLaunchPlan.swift`, `Sources/RestorableAgentSession.swift`, `Sources/Mobile/AgentChat/AgentChatSessionRegistry.swift` |
| React Terminal surface | `agent-chat` | `agent-chat/src/App.tsx`, `agent-chat/src/components/Chat.tsx`, `agent-chat/server.ts`, `agent-chat/adapters/codex.ts`, `agent-chat/adapters/claude.ts`, `agent-chat/adapters/acp.ts`, `agent-chat/adapters/pi.ts` |
| Provider-normalized telemetry | `agent-chat` and shared package | `agent-chat/executionTelemetryTypes.ts`, `agent-chat/executionTelemetryFanout.ts`, `agent-chat/executionTelemetryLiveProjection.ts`, `Packages/Shared/BmuxAgentChat/Sources/BmuxAgentChat/Wire` |
| PE runtime bridge and app runtime composition | root macOS app | `Sources/App/BmuxAppRuntimeComposition.swift`, `Sources/App/BmuxAppRuntimeConfiguration.swift`, `Sources/App/BmuxAppRuntimeServices.swift`, `Sources/WorkProvenance/WorkProvenanceRuntime.swift`, `Sources/AppDelegate+AgentChat.swift` |
| Coding-agent evidence production | root macOS app | `Sources/WorkProvenance/WorkProvenanceCodingAgentEvidenceRecorder.swift`, `Sources/WorkProvenance/WorkProvenanceCodingAgentEvidenceRecorder+Recording.swift`, `Sources/WorkProvenance/ExecutionTelemetryProvenanceProjectionService.swift`, `Sources/Mobile/AgentChat/AgentChatTranscriptPromptEvidenceSeeder.swift` |
| Workspace Current State consumer | root macOS app | `Sources/WorkProvenance/WorkspaceDisplayCurrentStateStore.swift`, `Sources/WorkProvenance/WorkspaceDisplayCurrentStateSubscription.swift`, `Sources/WorkProvenance/WorkspaceDisplayCurrentStateSnapshot.swift`, `Sources/Sidebar/SidebarWorkspaceSnapshotBuilder.swift` |
| Provenance CLI/debug paths | CLI | `CLI/BMUXCLI+Provenance.swift`, `CLI/CLIProvenanceSessionTree.swift` |

## Provenance Engine Package

| Component | Package/module | Entry locations |
| --- | --- | --- |
| Public client and capability contract | `ProvenanceEngineContracts` | `Packages/macOS/ProvenanceEngine/Sources/ProvenanceEngineContracts/ProvenanceEngineClient.swift`, `ProvenanceEngineCapability.swift`, `ProvenanceEngineHealth.swift` |
| Evidence contracts | `ProvenanceEngineContracts` | `ProvenanceEvent.swift`, `ProvenanceEventPayload.swift`, `ProvenanceAppendEventRequest.swift`, `ProvenanceEvidenceOrigin.swift`, `ProvenanceEvidenceScope.swift` |
| Coding-agent factual contracts | `ProvenanceEngineContracts` | `ProvenanceCodingAgentThreadRecord.swift`, `ProvenanceCodingAgentTurnRecord.swift`, `ProvenanceFactualSessionProjectionSnapshot.swift`, `ProvenanceFactualSessionTurnDetailResponse.swift` |
| Semantic inference contracts | `ProvenanceEngineContracts` | `ProvenanceSemanticInferenceContracts.swift`, `ProvenanceCodingAgentSemanticInferenceContracts.swift` |
| Semantic message contracts | `ProvenanceEngineContracts` | `ProvenanceSemanticMessageContracts.swift` |
| Public SDK construction | `ProvenanceEngineSDK` | `Packages/macOS/ProvenanceEngine/Sources/ProvenanceEngineSDK/ProvenanceEngineClientFactory.swift` |
| SQLite storage and projections | `ProvenanceEngineSQLite` | `ProvenanceSQLiteRepository.swift`, `ProvenanceSQLiteRepository+ProvenanceEngineClient.swift`, `ProvenanceSQLiteDatabase.swift`, `ProvenanceSQLiteMigrator.swift` |
| PE tests | PE package tests | `Packages/macOS/ProvenanceEngine/Tests/ProvenanceEngineSQLiteTests`, `ProvenanceEngineSDKTests`, `ProvenanceEngineContractsTests` |

## Project Truth and Documentation

| Component | Location | Entry locations |
| --- | --- | --- |
| Canonical project graph | root project manifests | `project/project-state.yaml`, `project/repo-status.yaml`, `project/schema` |
| Project docs tooling | root tool | `tools/project-docs/project_docs.py`, `scripts/project-docs` |
| Generated status | generated docs | `docs/generated/project-status.md`, `docs/generated/nested-roadmap.md`, `docs/generated/ownership-boundary.md`, `docs/generated/repository-status.md` |
| Authored architecture | docs | `docs/architecture/`, `docs/product/`, `docs/decisions/`, `docs/planning/` |

## Boundary Guard Candidates

Current structural guardrails are package layout, local SwiftPM products, Xcode
local package references, Project Truth validation, runtime-composition startup
linting, and documentation rules. `scripts/check-app-runtime-composition-boundary.sh`
keeps migrated WorkProvenance construction and startup behind
`BmuxAppRuntimeComposition` and `BmuxAppRuntimeServices`.

Useful future CI guards would check that `Packages/macOS/ProvenanceEngine/Sources`
never imports bmux app modules, SwiftUI, AppKit, `agent-chat`, or `Sources/`
implementation files, and that bmux production code imports only PE public
products rather than `ProvenanceEngineSQLite`.
