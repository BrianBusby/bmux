import Foundation

struct GitHubWorkBriefViewer: Decodable {
    let login: String
}

struct GitHubWorkBriefSearchResponse: Decodable {
    let total_count: Int
    let incomplete_results: Bool
    let items: [Item]

    struct Item: Decodable {
        let id: Int64
        let number: Int
        let title: String
        let html_url: String
        let repository_url: String
        let updated_at: String
        let user: User
    }

    struct User: Decodable {
        let login: String
    }
}
