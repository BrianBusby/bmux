import BMUXAgentLaunch
import BmuxAgentChat
import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
struct PromptSessionLinkCompletionTests {
    @Test func monitorTranscriptAndIdentityHookConvergeWithoutDisplayMetadataSeed() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-prompt-session-link-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            do {
                try FileManager.default.removeItem(at: root)
            } catch {
                Issue.record(error, "Could not remove owned session-link files")
            }
        }
        // The async scope releases the SQLite client graph before its files are removed.
        try await exerciseIdentityLink(root: root)
    }

    private func exerciseIdentityLink(root: URL) async throws {
        let client: any ProvenanceEngineContracts.ProvenanceEngineClient =
            try ProvenanceEngineClientFactory().sqliteClient(databaseURL: root.appendingPathComponent("provenance.sqlite"))
        let repositoryRoot = root.appendingPathComponent("repository").path
        let gitSnapshot = WorkProvenanceGitSnapshot(
            repositoryRoot: repositoryRoot,
            commonDirectory: "\(repositoryRoot)/.git",
            remoteSlug: "manaflow-ai/bmux",
            branch: "harden-pe-session-readiness",
            headCommit: "def456",
            isDirty: false
        )
        let sessionID = "codex-monitor-session"
        let surfaceID = UUID()
        let promptText = "Show the factual Session data for this workspace."
        let transcriptURL = root.appendingPathComponent("rollout-\(sessionID).jsonl")
        try Self.writeCodexTranscript(
            sessionID: sessionID,
            repositoryRoot: repositoryRoot,
            promptText: promptText,
            to: transcriptURL
        )

        let importer = CLIProvenanceCodexTranscriptImporter(client: client)
        var liveImportState = CLIProvenanceCodexTranscriptImporter.LiveImportState()
        let importResult = try await importer.importLiveTranscriptAppend(
            at: transcriptURL,
            state: &liveImportState
        )
        #expect(importResult.fileReport.threads == 1)
        #expect(importResult.fileReport.turns == 1)
        #expect(importResult.fileReport.prompts == 1)
        let directProjection = try await client.factualSessionProjection(
            ProvenanceFactualSessionProjectionRequest(sessionID: sessionID)
        )
        #expect(directProjection.snapshot?.session.id == sessionID)

        let manager = TabManager()
        defer { manager.tabs.forEach { $0.teardownAllPanels() } }
        let workspace = manager.tabs[0]
        workspace.currentDirectory = repositoryRoot
        let observationService = WorkProvenanceObservationService(
            client: client,
            gitInspector: FakeGitInspector(snapshotsByDirectory: [repositoryRoot: gitSnapshot])
        )
        let runtime = WorkProvenanceRuntime(
            observationService: observationService,
            agentSessionFactualProjectionStore: AgentSessionFactualProjectionStore(client: client),
            codingAgentEvidenceRecorder: WorkProvenanceCodingAgentEvidenceRecorder(
                client: client,
                gitInspector: FakeGitInspector(snapshotsByDirectory: [repositoryRoot: gitSnapshot])
            )
        )
        defer { runtime.stop() }
        runtime.start(tabManager: manager)

        let transcriptService = AgentChatTranscriptService(
            registry: AgentChatSessionRegistry(hookStore: AgentChatHookSessionStore(homeDirectory: root)),
            resolver: AgentChatTranscriptResolver(
                homeDirectory: root,
                environment: ["CODEX_HOME": root.appendingPathComponent("empty-codex").path]
            ),
            rawOutputStore: ChatRawTerminalOutputFileStore(rootDirectory: root.appendingPathComponent("raw-output")),
            hasEventSubscribers: { false },
            emitEventPayload: { _ in },
            recordTaskWorkspaceDirectory: { _, _ in }
        )
        transcriptService.recordSessionLifecycleChanges(with: runtime)
        transcriptService.noteHookEvent(WorkstreamEvent(
            sessionId: "codex-\(sessionID)",
            hookEventName: .userPromptSubmit,
            source: "codex",
            workspaceId: workspace.id.uuidString,
            surfaceId: surfaceID.uuidString,
            transcriptPath: nil,
            cwd: repositoryRoot,
            requestId: "identity-only-hook",
            receivedAt: Date(timeIntervalSince1970: 1_725_000_123)
        ))

        let result = try await factualProjectionAfterCompletion(
            runtime: runtime,
            stableWorkspaceID: workspace.stableId
        )
        guard case .available(let projection) = result else {
            Issue.record("Expected monitor transcript plus identity hook to converge to an available factual projection; got \(result)")
            return
        }
        #expect(projection.session.id == sessionID)
    }

    private func factualProjectionAfterCompletion(
        runtime: WorkProvenanceRuntime,
        stableWorkspaceID: UUID,
        timeout: Duration = .seconds(1)
    ) async throws -> AgentSessionFactualProjectionReadResult {
        let start = ContinuousClock.now
        let deadline = start.advanced(by: timeout)
        let progress = CompletionProgress()
        let (results, signal) = AsyncStream<Completion>.makeStream(bufferingPolicy: .bufferingOldest(1))
        defer { signal.finish() }
        var ownedProducer: Task<Void, Never>?
        await withCheckedContinuation { entered in
            ownedProducer = Task { @MainActor in
                // Same-actor entry captures task handles before timeout cleanup can clear them.
                entered.resume()
                await runtime.waitForBackgroundTasks()
                guard !Task.isCancelled else { return }
                progress.phase = "projection"
                let projection = await runtime.agentSessionFactualProjection(stableWorkspaceID: stableWorkspaceID)
                progress.phase = "completed"
                // Record the full result before async consumption can race the deadline.
                signal.yield(.projection(projection, .now))
                signal.finish()
            }
        }
        let producer = try #require(ownedProducer)
        let completion = await withTaskGroup(of: Void.self) { group in
            defer { group.cancelAll() }
            group.addTask {
                await expire(
                    runtime: runtime, producer: producer, progress: progress,
                    start: start, deadline: deadline, signal: signal
                )
            }
            var iterator = results.makeAsyncIterator()
            return await iterator.next()
        }
        producer.cancel()
        runtime.stop()
        await producer.value
        try Task.checkCancellation()
        guard let completion else { throw CancellationError() }
        switch completion {
        case let .projection(projection, arrival):
            guard arrival < deadline else {
                throw CompletionFailure.timedOut(phase: "projection", arrival: start.duration(to: arrival))
            }
            return projection
        case .failed(let error):
            throw error
        }
    }

    private func expire(
        runtime: WorkProvenanceRuntime,
        producer: Task<Void, Never>,
        progress: CompletionProgress,
        start: ContinuousClock.Instant,
        deadline: ContinuousClock.Instant,
        signal: AsyncStream<Completion>.Continuation
    ) async {
        // Stop cancels runtime work; the captured producer is still joined by the caller.
        defer { producer.cancel(); runtime.stop() }
        do {
            // The original absolute one-second failure bound includes the full projection read.
            try await ContinuousClock().sleep(until: deadline)
            signal.yield(.failed(CompletionFailure.timedOut(
                phase: progress.phase, arrival: start.duration(to: .now)
            )))
        } catch is CancellationError {
            return
        } catch {
            signal.yield(.failed(error))
        }
        signal.finish()
    }

    @MainActor
    private final class CompletionProgress {
        var phase = "background"
    }

    private enum Completion: Sendable {
        case projection(AgentSessionFactualProjectionReadResult, ContinuousClock.Instant)
        case failed(any Error)
    }

    private enum CompletionFailure: Error, CustomStringConvertible {
        case timedOut(phase: String, arrival: Duration)

        var description: String {
            switch self {
            case let .timedOut(phase, arrival):
                "event=prompt_session_link_timeout phase=\(phase) arrival=\(arrival)"
            }
        }
    }

    private static func codexPromptTranscriptLines(
        sessionID: String,
        repositoryRoot: String,
        promptText: String,
        timestampMinute: String = "2026-08-21T10:00",
        turnID: String = "turn-monitor-1",
        startedAt: Int = 1_787_325_602
    ) throws -> [String] {
        [
            try codexTranscriptLine(
                ordinal: 0,
                type: "session_meta",
                timestamp: "\(timestampMinute):00Z",
                payload: [
                    "session_id": sessionID,
                    "id": sessionID,
                    "timestamp": "\(timestampMinute):00Z",
                    "cwd": repositoryRoot,
                    "originator": "codex-tui",
                    "source": "cli",
                    "model_provider": "openai"
                ]
            ),
            try codexTranscriptLine(
                ordinal: 1,
                type: "response_item",
                timestamp: "\(timestampMinute):01Z",
                payload: [
                    "type": "message",
                    "role": "user",
                    "content": [
                        [
                            "type": "input_text",
                            "text": promptText
                        ]
                    ]
                ]
            ),
            try codexTranscriptLine(
                ordinal: 2,
                type: "event_msg",
                timestamp: "\(timestampMinute):02Z",
                payload: [
                    "type": "task_started",
                    "turn_id": turnID,
                    "started_at": startedAt
                ]
            )
        ]
    }

    private static func writeCodexTranscript(
        sessionID: String,
        repositoryRoot: String,
        promptText: String,
        to url: URL
    ) throws {
        let lines = try codexPromptTranscriptLines(
            sessionID: sessionID,
            repositoryRoot: repositoryRoot,
            promptText: promptText
        )
        try lines.joined(separator: "\n")
            .appending("\n")
            .write(to: url, atomically: true, encoding: .utf8)
    }

    private static func codexTranscriptLine(
        ordinal: Int,
        type: String,
        timestamp: String,
        payload: [String: Any]
    ) throws -> String {
        let object: [String: Any] = [
            "timestamp": timestamp,
            "ordinal": ordinal,
            "type": type,
            "payload": payload
        ]
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    private struct FakeGitInspector: WorkProvenanceGitInspecting {
        let snapshotsByDirectory: [String: WorkProvenanceGitSnapshot]

        func snapshot(for directory: String) async -> WorkProvenanceGitSnapshot? {
            snapshotsByDirectory[directory]
        }
    }
}
