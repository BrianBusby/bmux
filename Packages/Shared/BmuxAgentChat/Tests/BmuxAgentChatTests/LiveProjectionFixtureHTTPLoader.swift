import Foundation
import BmuxAgentChat

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
