import Foundation
import BmuxAgentChat
import Testing

actor LiveProjectionFixtureHTTPLoader: AgentChatHTTPLoading {
    private let response: AgentChatHTTPResponse
    private var requests: [URLRequest] = []

    init(response: AgentChatHTTPResponse) {
        self.response = response
    }

    func load(_ request: URLRequest) async throws -> AgentChatHTTPResponse {
        requests.append(request)
        return response
    }

    func onlyRequest() throws -> URLRequest {
        guard requests.count == 1, let request = requests.first else {
            throw LiveProjectionFixtureHTTPLoaderError.unexpectedRequestCount(requests.count)
        }
        return request
    }
}

private enum LiveProjectionFixtureHTTPLoaderError: Error {
    case unexpectedRequestCount(Int)
}

@Suite("Execution telemetry event client")
struct ExecutionTelemetryEventClientTests {
    @Test("reads bounded cursor endpoint")
    func readsBoundedCursorEndpoint() async throws {
        let data = Data("""
        {
          "sessionId": "session-sidecar",
          "latestSequence": 5,
          "events": [
            {
              "schema": "bmux.execution-event.v1",
              "eventId": "event-plan",
              "sessionId": "session-sidecar",
              "sequence": 2,
              "capturedAtMs": 1725000000100,
              "source": "provider",
              "provider": "codex",
              "providerSessionId": "thread-1",
              "providerTurnId": "turn-1",
              "providerEvent": {"method": "turn/plan/updated", "requestId": 7},
              "event": {
                "type": "plan.updated",
                "explanation": "ordered work",
                "steps": [
                  {"text": "Audit", "status": "completed"},
                  {"text": "Persist", "status": "in_progress"}
                ]
              }
            },
            {
              "schema": "bmux.execution-event.v1",
              "eventId": "event-tool",
              "sessionId": "session-sidecar",
              "sequence": 3,
              "capturedAtMs": 1725000000200,
              "source": "provider",
              "provider": "codex",
              "providerSessionId": "thread-1",
              "providerTurnId": "turn-1",
              "providerEvent": {"method": "item/completed", "itemId": "tool-1"},
              "event": {
                "type": "tool.completed",
                "operationId": "tool-1",
                "toolKind": "command",
                "name": "shell",
                "status": "succeeded",
                "outputSummary": "passed",
                "exitCode": 0,
                "completedAtMs": 1725000000200
              }
            },
            {
              "schema": "bmux.execution-event.v1",
              "eventId": "event-summary",
              "sessionId": "session-sidecar",
              "sequence": 4,
              "capturedAtMs": 1725000000300,
              "source": "provider",
              "provider": "codex",
              "providerSessionId": "thread-1",
              "providerTurnId": "turn-1",
              "event": {
                "type": "message.completed",
                "stream": "reasoning",
                "itemId": "reasoning-summary-1",
                "text": "Visible summary"
              }
            },
            {
              "schema": "bmux.execution-event.v1",
              "eventId": "event-files",
              "sessionId": "session-sidecar",
              "sequence": 5,
              "capturedAtMs": 1725000000400,
              "source": "git-observer",
              "provider": "codex",
              "providerSessionId": "thread-1",
              "providerTurnId": "turn-1",
              "event": {
                "type": "files.changed",
                "source": "git-observer",
                "files": [
                  {"path": "Sources/Evidence.swift", "status": "modified", "additions": 12, "deletions": 2}
                ]
              }
            }
          ]
        }
        """.utf8)
        let loader = LiveProjectionFixtureHTTPLoader(
            response: AgentChatHTTPResponse(data: data, statusCode: 200)
        )
        let client = ExecutionTelemetryEventClient(
            baseURL: URL(string: "http://127.0.0.1:7739/s/old?x=1")!,
            loader: loader
        )

        let payload = try await client.read(sessionID: "session-sidecar", afterSequence: 1, limit: 50)
        let request = try await loader.onlyRequest()

        #expect(payload.sessionID == "session-sidecar")
        #expect(payload.latestSequence == 5)
        #expect(payload.events.map(\.eventID) == ["event-plan", "event-tool", "event-summary", "event-files"])
        #expect(payload.events[0].providerEvent?.requestID == "7")
        if case let .planUpdated(plan) = payload.events[0].event {
            #expect(plan.explanation == "ordered work")
            #expect(plan.steps.map(\.text) == ["Audit", "Persist"])
            #expect(plan.steps.map(\.status) == ["completed", "in_progress"])
        } else {
            Issue.record("expected plan.updated event")
        }
        if case let .toolCompleted(tool) = payload.events[1].event {
            #expect(tool.operationID == "tool-1")
            #expect(tool.toolKind == "command")
            #expect(tool.status == "succeeded")
            #expect(tool.exitCode == 0)
        } else {
            Issue.record("expected tool.completed event")
        }
        if case let .messageCompleted(message) = payload.events[2].event {
            #expect(message.stream == "reasoning")
            #expect(message.itemID == "reasoning-summary-1")
            #expect(message.text == "Visible summary")
        } else {
            Issue.record("expected message.completed event")
        }
        if case let .filesChanged(filesChanged) = payload.events[3].event {
            #expect(filesChanged.source == "git-observer")
            #expect(filesChanged.files.first?.path == "Sources/Evidence.swift")
            #expect(filesChanged.files.first?.additions == 12)
        } else {
            Issue.record("expected files.changed event")
        }
        #expect(request.httpMethod == "GET")
        #expect(request.url?.absoluteString == "http://127.0.0.1:7739/api/sessions/session-sidecar/execution-telemetry/events?afterSequence=1&limit=50")
    }
}
