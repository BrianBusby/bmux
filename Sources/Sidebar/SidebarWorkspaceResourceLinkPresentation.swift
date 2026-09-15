import Foundation

extension SidebarWorkspaceSnapshotBuilder {
    struct OwnerDisplay: Identifiable, Equatable {
        let id: String
        let name: String
        let url: URL?
    }

    struct ResourceLinkPresentation: Equatable {
        enum HeaderKind: String, Equatable {
            case ticket
            case pullRequest
            case project
            case owner
        }

        struct HeaderItem: Identifiable, Equatable {
            let id: String
            let kind: HeaderKind
            let text: String
            let detail: String?
            let url: URL
        }

        let ticketRows: [TicketDisplay]
        let pullRequestRows: [PullRequestDisplay]
        let projectRows: [ProjectDisplay]
        let ownerRows: [OwnerDisplay]

        static let empty = ResourceLinkPresentation(
            ticketRows: [],
            pullRequestRows: [],
            projectRows: [],
            ownerRows: []
        )

        var hasHeaderItems: Bool {
            !headerItems.isEmpty
        }

        var headerItems: [HeaderItem] {
            let ticketItems = ticketRows.compactMap { ticket -> HeaderItem? in
                guard let url = ticket.url else { return nil }
                return HeaderItem(
                    id: "ticket:\(ticket.id)|\(url.absoluteString)",
                    kind: .ticket,
                    text: ticket.linkText,
                    detail: nil,
                    url: url
                )
            }
            let pullRequestItems = pullRequestRows.compactMap { pullRequest -> HeaderItem? in
                guard let url = pullRequest.url else { return nil }
                return HeaderItem(
                    id: "pullRequest:\(pullRequest.id)",
                    kind: .pullRequest,
                    text: "#\(pullRequest.number)",
                    detail: pullRequest.titleLine,
                    url: url
                )
            }
            let projectItems = projectRows.compactMap { project -> HeaderItem? in
                guard let url = project.url else { return nil }
                return HeaderItem(
                    id: "project:\(project.id)|\(url.absoluteString)",
                    kind: .project,
                    text: project.linkText,
                    detail: nil,
                    url: url
                )
            }
            let ownerItems = ownerRows.compactMap { owner -> HeaderItem? in
                guard let url = owner.url else { return nil }
                return HeaderItem(
                    id: "owner:\(owner.id)",
                    kind: .owner,
                    text: owner.name,
                    detail: nil,
                    url: url
                )
            }
            return ticketItems + pullRequestItems + projectItems + ownerItems
        }

        var headerSuppression: HeaderSuppression {
            HeaderSuppression(
                ticketURLs: Set(ticketRows.compactMap(\.url)),
                pullRequestURLs: Set(pullRequestRows.compactMap(\.url)),
                projectURLs: Set(projectRows.compactMap(\.url)),
                ownerURLs: Set(ownerRows.compactMap(\.url))
            )
        }
    }

    struct HeaderSuppression: Equatable {
        let ticketURLs: Set<URL>
        let pullRequestURLs: Set<URL>
        let projectURLs: Set<URL>
        let ownerURLs: Set<URL>

        static let empty = HeaderSuppression(
            ticketURLs: [],
            pullRequestURLs: [],
            projectURLs: [],
            ownerURLs: []
        )
    }

    struct SidebarResourceRows: Equatable {
        let ticketRows: [TicketDisplay]
        let hiddenTicketURLs: Set<URL>
        let hiddenOwnerURLs: Set<URL>
        let pullRequestRows: [PullRequestDisplay]
        let projectRows: [ProjectDisplay]
        let pullRequestOwnerRows: [PullRequestDisplay]
    }
}
