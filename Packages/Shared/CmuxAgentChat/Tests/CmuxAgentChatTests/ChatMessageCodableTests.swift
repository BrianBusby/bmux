import Foundation
import Testing

@testable import CmuxAgentChat

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
}
