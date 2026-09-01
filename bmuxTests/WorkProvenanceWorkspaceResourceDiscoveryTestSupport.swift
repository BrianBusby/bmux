import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

extension WorkProvenanceWorkspaceResourceDiscoveryTests {
    static func client(for fixture: StoreFixture) throws -> any ProvenanceEngineContracts.ProvenanceEngineClient {
        try ProvenanceEngineClientFactory().sqliteClient(databaseURL: fixture.databaseURL)
    }

    static func gitSnapshot(repositoryRoot: String) -> WorkProvenanceGitSnapshot {
        WorkProvenanceGitSnapshot(
            repositoryRoot: repositoryRoot,
            commonDirectory: "\(repositoryRoot)/.git",
            remoteSlug: "CompanyCam/Company-Cam-API",
            branch: "prompt-derived-workspace-resources",
            headCommit: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            isDirty: false,
            statusEntries: []
        )
    }

    static func linearTicketLink(id: String = "STE-1964") -> ProvenanceWorkspaceDisplayTicketLinkRecord {
        ProvenanceWorkspaceDisplayTicketLinkRecord(
            id: id,
            system: "linear",
            title: "Canonical domain mutation paths",
            url: "https://linear.app/companycam/issue/\(id)",
            ownerName: "Brian Busby"
        )
    }

    static func linearUnresolvedTicketLink(
        id: String,
        url: String? = nil
    ) -> ProvenanceWorkspaceDisplayTicketLinkRecord {
        ProvenanceWorkspaceDisplayTicketLinkRecord(
            id: id,
            system: "linear",
            title: nil,
            url: url ?? "https://linear.app/companycam/issue/\(id)",
            ownerName: nil,
            ownerURL: nil
        )
    }

    static func linearProjectLink() -> ProvenanceWorkspaceDisplayProjectLinkRecord {
        ProvenanceWorkspaceDisplayProjectLinkRecord(
            id: "context-efficiency-c1b9a",
            system: "linear",
            title: "Context Efficiency",
            url: "https://linear.app/companycam/project/context-efficiency-c1b9a"
        )
    }

    static func previousProjectLink() -> ProvenanceWorkspaceDisplayProjectLinkRecord {
        ProvenanceWorkspaceDisplayProjectLinkRecord(
            id: "existing-pr-project",
            system: "linear",
            title: "Existing PR Project",
            url: "https://linear.app/companycam/project/existing-pr-project"
        )
    }

    struct FakeGitInspector: WorkProvenanceGitInspecting {
        let snapshotsByDirectory: [String: WorkProvenanceGitSnapshot]

        func snapshot(for directory: String) async -> WorkProvenanceGitSnapshot? {
            snapshotsByDirectory[directory]
        }
    }

    actor FakeLinearGraphQLServer {
        struct Request: Equatable, Sendable {
            let authorization: String?
            let ticketID: String?
        }

        private(set) var requests: [Request] = []

        func response(for request: URLRequest) throws -> (Data, Int) {
            let ticketID = try Self.ticketID(from: request.httpBody) ?? "STE-1964"
            requests.append(Request(
                authorization: request.value(forHTTPHeaderField: "Authorization"),
                ticketID: ticketID
            ))
            let payload = """
            {
              "data": {
                "issue": {
                  "title": "Canonical domain mutation paths",
                  "url": "https://linear.app/companycam/issue/\(ticketID)",
                  "assignee": {
                    "name": "Brian Busby"
                  },
                  "project": {
                    "id": "linear-project-1",
                    "name": "Context Efficiency",
                    "url": "https://linear.app/companycam/project/context-efficiency-c1b9a",
                    "slugId": "context-efficiency-c1b9a"
                  }
                }
              }
            }
            """
            return (Data(payload.utf8), 200)
        }

        private static func ticketID(from data: Data?) throws -> String? {
            guard let data else { return nil }
            let json = try JSONSerialization.jsonObject(with: data)
            guard let object = json as? [String: Any],
                  let variables = object["variables"] as? [String: Any] else {
                return nil
            }
            return variables["id"] as? String
        }
    }

    struct StoreFixture {
        let directoryURL: URL
        let databaseURL: URL

        init() throws {
            directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(
                "bmux-work-provenance-resource-discovery-\(UUID().uuidString)",
                isDirectory: true
            )
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            databaseURL = directoryURL.appendingPathComponent("provenance.sqlite")
        }

        func remove() {
            try? FileManager.default.removeItem(at: directoryURL)
        }
    }

    struct ResourceDiscoveryScenario: Sendable {
        let text: String
        let expectedIDs: [String]
        let expectedURLs: [String]
    }
}
