import Foundation

struct GitHubReviewRequestsResponse: Decodable {
    let users: [User]
    let teams: [Team]

    struct User: Decodable { let login: String }
    struct Team: Decodable { let slug: String }
}
