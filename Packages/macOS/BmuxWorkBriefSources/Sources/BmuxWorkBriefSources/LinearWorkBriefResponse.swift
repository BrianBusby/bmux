import Foundation

struct LinearWorkBriefResponse: Decodable {
    let data: Payload?
    let errors: [GraphQLError]?

    struct Payload: Decodable { let viewer: Viewer? }
    struct Viewer: Decodable { let assignedIssues: Connection }
    struct Connection: Decodable {
        let nodes: [Issue]
        let pageInfo: PageInfo
    }
    struct PageInfo: Decodable {
        let hasNextPage: Bool
        let endCursor: String?
    }
    struct Issue: Decodable {
        let id: String
        let identifier: String
        let title: String
        let url: String
        let updatedAt: String
        let state: State
    }
    struct State: Decodable {
        let name: String
        let type: String
    }
    struct GraphQLError: Decodable { let message: String? }
}
