import Foundation
import Testing

@testable import BmuxAgentChat

@Suite("ChatMessage wire coding")
struct ChatMessageCodableTests {
    private func roundTrip(_ message: ChatMessage) throws -> ChatMessage {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ChatMessage.self, from: encoder.encode(message))
    }

    private func message(kind: ChatMessageKind, role: ChatRole = .agent) -> ChatMessage {
        ChatMessage(
            id: "m1",
            seq: 7,
            role: role,
            timestamp: Date(timeIntervalSince1970: 1_750_000_000),
            kind: kind
        )
    }

    @Test("every kind round-trips")
    func everyKindRoundTrips() throws {
        let kinds: [ChatMessageKind] = [
            .prose(ChatProse(text: "Hello **world**")),
            .thought(ChatThought(text: "considering options")),
            .toolUse(
                ChatToolUse(
                    toolName: "Read",
                    summary: "Read main.swift",
                    inputDetail: "{\"file_path\": \"main.swift\"}",
                    output: "let x = 1",
                    status: .succeeded
                )
            ),
            .terminal(
                ChatTerminalCapture(
                    command: "swift test",
                    output: "All tests passed",
                    exitCode: 0,
                    durationSeconds: 4.2,
                    isRunning: false,
                    outputMetadata: ChatTerminalOutputMetadata(
                        kind: .tests,
                        rawOutputRef: "terminal-output:m1:abc123",
                        rawByteCount: 1800,
                        rawLineCount: 42,
                        optimizedByteCount: 38,
                        omittedLineCount: 39,
                        wasOptimized: true
                    )
                )
            ),
            .fileEdit(
                ChatFileEdit(
                    filePath: "Sources/App.swift",
                    operation: .edit,
                    additions: 12,
                    deletions: 4,
                    unifiedDiff: "-old\n+new"
                )
            ),
            .permissionRequest(
                ChatPermissionRequest(
                    title: "Claude wants to run:",
                    subject: "rm -rf build",
                    resolution: .approved
                )
            ),
            .question(
                ChatQuestion(
                    prompt: "Which approach?",
                    options: [
                        ChatQuestion.Option(label: "Fast", detail: "less safe"),
                        ChatQuestion.Option(label: "Safe"),
                    ],
                    selectedOptionLabel: "Safe"
                )
            ),
            .status(ChatStatusTransition(event: .sessionStarted, detail: "claude")),
            .attachment(ChatAttachment(media: .image, displayName: "design.png", hostPath: "/tmp/design.png")),
        ]
        for kind in kinds {
            let original = message(kind: kind)
            let decoded = try roundTrip(original)
            #expect(decoded == original)
        }
    }

    @Test("kind encodes with a readable type discriminator")
    func typeDiscriminator() throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(message(kind: .terminal(ChatTerminalCapture(command: "ls"))))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let kind = try #require(object["kind"] as? [String: Any])
        #expect(kind["type"] as? String == "terminal")
        #expect(kind["command"] as? String == "ls")
    }

    @Test("terminal output metadata encodes a local raw-output reference without embedding raw output")
    func terminalOutputMetadataEncoding() throws {
        let rawOutput = String(repeating: "downloaded package\n", count: 20)
        let terminal = ChatTerminalCapture(
            command: "npm install",
            output: "package install summary\n- completed",
            outputMetadata: ChatTerminalOutputMetadata(
                kind: .packageInstall,
                rawOutputRef: "terminal-output:m1:feedface",
                rawByteCount: rawOutput.utf8.count,
                rawLineCount: 20,
                optimizedByteCount: 35,
                omittedLineCount: 18,
                wasOptimized: true
            )
        )
        let data = try JSONEncoder().encode(message(kind: .terminal(terminal)))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let kind = try #require(object["kind"] as? [String: Any])
        let metadata = try #require(kind["output_metadata"] as? [String: Any])

        #expect(metadata["kind"] as? String == "package_install")
        #expect(metadata["raw_output_ref"] as? String == "terminal-output:m1:feedface")
        #expect(metadata["raw_byte_count"] as? Int == rawOutput.utf8.count)
        #expect(metadata["raw_line_count"] as? Int == 20)
        #expect(metadata["omitted_line_count"] as? Int == 18)
        #expect(metadata["was_optimized"] as? Bool == true)
        #expect(String(decoding: data, as: UTF8.self).contains(rawOutput) == false)
    }

    @Test("unknown kind decodes as unsupported, preserving the raw type")
    func unknownKindFailsOpen() throws {
        let json = """
        {"id": "m9", "seq": 9, "role": "agent",
         "timestamp": "2026-06-11T00:00:00Z",
         "kind": {"type": "hologram", "payload": 1}}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ChatMessage.self, from: Data(json.utf8))
        #expect(decoded.kind == .unsupported(ChatUnsupportedPayload(rawType: "hologram")))
    }

    @Test("an unknown nested enum value degrades that message to unsupported, not the page")
    func unknownNestedEnumFailsOpen() throws {
        let json = """
        {"id": "m10", "seq": 10, "role": "agent",
         "timestamp": "2026-06-11T00:00:00Z",
         "kind": {"type": "tool_use", "tool_name": "Bash", "summary": "x",
                  "status": "cancelled_by_orbit"}}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ChatMessage.self, from: Data(json.utf8))
        #expect(decoded.kind == .unsupported(ChatUnsupportedPayload(rawType: "tool_use")))
    }

    @Test("an unknown role and missing timestamp fail open, keeping id and seq")
    func unknownEnvelopeFieldsFailOpen() throws {
        let json = """
        {"id": "m11", "seq": 11, "role": "overseer",
         "kind": {"type": "prose", "text": "hi"}}
        """
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: Data(json.utf8))
        #expect(decoded.id == "m11")
        #expect(decoded.seq == 11)
        #expect(decoded.role == .agent)
        #expect(decoded.kind == .prose(ChatProse(text: "hi")))
    }

    @Test("an unknown session event name decodes as ignorable, not a throw")
    func unknownSessionEventFailsOpen() throws {
        let json = """
        {"event": "hologram_projected", "intensity": 11}
        """
        let decoded = try JSONDecoder().decode(ChatSessionEvent.self, from: Data(json.utf8))
        #expect(decoded == .unknown("hologram_projected"))
    }

    @Test("agent state round-trips with associated dates")
    func agentStateRoundTrips() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let states: [ChatAgentState] = [
            .idle,
            .working(since: Date(timeIntervalSince1970: 1_750_000_000)),
            .needsInput(since: Date(timeIntervalSince1970: 1_750_000_100)),
            .ended,
        ]
        for state in states {
            let decoded = try decoder.decode(ChatAgentState.self, from: encoder.encode(state))
            #expect(decoded == state)
        }
    }

    @Test("execution telemetry live projection fixture decodes")
    func executionTelemetryLiveProjectionFixtureDecodes() throws {
        let payload = try ChatWireCoding().decode(
            ExecutionTelemetryLiveProjectionReadPayload.self,
            from: executionTelemetryLiveProjectionFixtureData()
        )
        let snapshot = try #require(payload.snapshot)

        #expect(payload.sessionID == "session-sidecar")
        #expect(snapshot.sessionID == "session-sidecar")
        #expect(snapshot.provider == "codex")
        #expect(snapshot.providerSessionID == "thread-sidecar")
        #expect(snapshot.currentProviderTurnID == "turn-sidecar")
        #expect(snapshot.lifecycleState == .running)
        #expect(snapshot.activeOperationCount == 0)
        #expect(snapshot.latestActivityAtMs == 50_000)
        #expect(snapshot.latestUsageSummary?.turnID == "turn-sidecar")
        #expect(snapshot.latestUsageSummary?.inputTokens == 20)
        #expect(snapshot.latestUsageSummary?.outputTokens == 30)
        #expect(snapshot.latestUsageSummary?.totalTokens == 50)
        #expect(snapshot.latestUsageSummary?.observedAtMs == 50_000)
        #expect(snapshot.approvalBlocked.blocked == false)
        #expect(snapshot.approvalBlocked.pendingCount == 0)
        #expect(snapshot.filesChanged == nil)
    }

    @Test("execution telemetry live projection client reads endpoint")
    func executionTelemetryLiveProjectionClientReadsEndpoint() async throws {
        let loader = LiveProjectionFixtureHTTPLoader(
            response: AgentChatHTTPResponse(
                data: try executionTelemetryLiveProjectionFixtureData(),
                statusCode: 200
            )
        )
        let client = ExecutionTelemetryLiveProjectionClient(
            baseURL: URL(string: "http://127.0.0.1:7739/s/old?x=1")!,
            loader: loader
        )

        let payload = try await client.read(sessionID: "session-sidecar")
        let request = try await loader.onlyRequest()

        #expect(payload.snapshot?.provider == "codex")
        #expect(request.httpMethod == "GET")
        #expect(request.url?.absoluteString == "http://127.0.0.1:7739/api/sessions/session-sidecar/execution-telemetry/live")
        #expect(request.cachePolicy == .reloadIgnoringLocalAndRemoteCacheData)
    }

    @Test("execution telemetry live projection client rejects failures")
    func executionTelemetryLiveProjectionClientRejectsFailures() async throws {
        let loader = LiveProjectionFixtureHTTPLoader(
            response: AgentChatHTTPResponse(data: Data(), statusCode: 404)
        )
        let client = ExecutionTelemetryLiveProjectionClient(
            baseURL: URL(string: "http://127.0.0.1:7739")!,
            loader: loader
        )

        await #expect(throws: ExecutionTelemetryLiveProjectionClientError.httpStatus(404)) {
            try await client.read(sessionID: "missing")
        }
        #expect(throws: ExecutionTelemetryLiveProjectionClientError.invalidSessionID) {
            _ = try client.liveProjectionURL(sessionID: "")
        }
        #expect(throws: ExecutionTelemetryLiveProjectionClientError.invalidSessionID) {
            _ = try client.liveProjectionURL(sessionID: "a/b")
        }
    }

    @Test("agent chat session list client reads bounded summaries")
    func agentChatSessionListClientReadsBoundedSummaries() async throws {
        let data = Data("""
        [
          {
            "id": "session-sidecar",
            "provider": "codex",
            "cwd": "/repo",
            "title": "ignored",
            "status": "idle",
            "createdAt": 1725000000000,
            "capabilities": {"ignored": true}
          }
        ]
        """.utf8)
        let loader = LiveProjectionFixtureHTTPLoader(
            response: AgentChatHTTPResponse(data: data, statusCode: 200)
        )
        let client = AgentChatSessionListClient(
            baseURL: URL(string: "http://127.0.0.1:7739/s/old?x=1")!,
            loader: loader
        )

        let sessions = try await client.list()
        let request = try await loader.onlyRequest()

        #expect(sessions == [
            AgentChatSessionSummary(
                id: "session-sidecar",
                provider: "codex",
                cwd: "/repo",
                status: "idle",
                createdAt: 1_725_000_000_000
            )
        ])
        #expect(request.httpMethod == "GET")
        #expect(request.url?.absoluteString == "http://127.0.0.1:7739/api/sessions")
        #expect(request.cachePolicy == .reloadIgnoringLocalAndRemoteCacheData)
    }

    @Test("execution telemetry observation diagnostic matches bounded current state facts")
    func executionTelemetryObservationDiagnosticMatchesBoundedCurrentStateFacts() {
        let diagnostic = ExecutionTelemetryObservationDiagnostic.compare(
            sessionID: "session-1",
            livePayload: executionTelemetryObservationLivePayload(
                sessionID: "session-1",
                provider: "codex",
                providerSessionID: "thread-1",
                lifecycleState: .running
            ),
            currentStateFound: true,
            currentStateSessions: [
                ExecutionTelemetryObservationCurrentStateSession(
                    sessionID: "session-1",
                    provider: "codex",
                    lifecycleStatus: "active"
                )
            ]
        )

        #expect(diagnostic.status == "matched")
        #expect(diagnostic.mismatches.isEmpty)
    }

    @Test("execution telemetry observation diagnostic reports broad mismatches only")
    func executionTelemetryObservationDiagnosticReportsBroadMismatchesOnly() {
        let diagnostic = ExecutionTelemetryObservationDiagnostic.compare(
            sessionID: "session-1",
            livePayload: executionTelemetryObservationLivePayload(
                sessionID: "session-1",
                provider: "codex",
                providerSessionID: nil,
                lifecycleState: .running
            ),
            currentStateFound: true,
            currentStateSessions: [
                ExecutionTelemetryObservationCurrentStateSession(
                    sessionID: "session-1",
                    provider: "claude",
                    lifecycleStatus: "completed"
                )
            ]
        )

        #expect(diagnostic.status == "mismatched")
        #expect(diagnostic.mismatches.map(\.code) == [
            "provider_identity_mismatch",
            "lifecycle_presence_mismatch",
        ])
        #expect(diagnostic.mismatches.first?.live == "codex")
        #expect(diagnostic.mismatches.first?.currentState == "claude")
    }

    private func executionTelemetryLiveProjectionFixtureData() throws -> Data {
        try Data(contentsOf: executionTelemetryLiveProjectionFixtureURL())
    }

    private func executionTelemetryObservationLivePayload(
        sessionID: String,
        provider: String,
        providerSessionID: String?,
        lifecycleState: ExecutionTelemetryLiveLifecycleState
    ) -> ExecutionTelemetryLiveProjectionReadPayload {
        ExecutionTelemetryLiveProjectionReadPayload(
            sessionID: sessionID,
            snapshot: ExecutionTelemetryLiveProjectionSnapshot(
                sessionID: sessionID,
                provider: provider,
                providerSessionID: providerSessionID,
                currentProviderTurnID: lifecycleState == .running ? "turn-1" : nil,
                lifecycleState: lifecycleState,
                activeOperationCount: lifecycleState == .running ? 1 : 0,
                latestActivityAtMs: 1_000,
                approvalBlocked: ExecutionTelemetryLiveApprovalBlockedState(blocked: false, pendingCount: 0)
            )
        )
    }

    private func executionTelemetryLiveProjectionFixtureURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("docs/execution-telemetry/fixtures/live-projection-read-payload.json")
    }
}
