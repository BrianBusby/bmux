import Foundation
import ProvenanceEngineContracts
import XCTest

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

final class WorkProvenanceLinearTicketLinkResolverTests: XCTestCase {
    func `testAliasMapReturnsObservedTicketBeforeCanonicalAliasCandidates`() {
        let aliasMap = LinearTicketIdentifierAliasMap(prefixAliases: [
            "STE": ["INP", "inp", "STE"],
            "OLD": ["NEW"],
        ])

        XCTAssertEqual(aliasMap.lookupCandidates(for: " ste-1967 "), ["STE-1967", "INP-1967"])
        XCTAssertEqual(aliasMap.lookupCandidates(for: "OLD-12"), ["OLD-12", "NEW-12"])
        XCTAssertEqual(aliasMap.lookupCandidates(for: "INP-1967"), ["INP-1967"])
        XCTAssertEqual(aliasMap.lookupCandidates(for: "not-a-linear-ticket"), ["NOT-A-LINEAR-TICKET"])
    }

    func `testLegacyTeamKeyAliasUsesCanonicalIssueFactsUnderObservedTicketID`() async throws {
        let linearServer = AliasLinearGraphQLServer()
        let resolver = WorkProvenanceLinearTicketLinkResolver(
            authorizationHeader: "linear-api-key",
            usesEnvironmentAuthorization: false,
            ticketIdentifierAliasMap: LinearTicketIdentifierAliasMap(prefixAliases: [
                "STE": ["INP"],
            ]),
            dataProvider: { request in try await linearServer.response(for: request) }
        )

        let facts = await resolver.workspaceLinks(for: ["STE-1967"])
        let requestedTicketIDs = await linearServer.requestedTicketIDs

        XCTAssertEqual(requestedTicketIDs, ["STE-1967", "INP-1967"])
        XCTAssertEqual(facts.ticketLinks, [
            ProvenanceWorkspaceDisplayTicketLinkRecord(
                id: "STE-1967",
                system: "linear",
                title: "Send company industry key to Amplitude",
                url: "https://linear.app/companycam/issue/INP-1967/send-company-industry-key-to-amplitude",
                ownerName: "Brian Busby"
            ),
        ])
        XCTAssertEqual(facts.projectLinks, [
            ProvenanceWorkspaceDisplayProjectLinkRecord(
                id: "amplitude-targeting-c1b9a",
                system: "linear",
                title: "Amplitude targeting",
                url: "https://linear.app/companycam/project/amplitude-targeting-c1b9a"
            ),
        ])
    }

    func `testCanonicalTicketDoesNotTryAliasesAfterDirectLookupResolves`() async throws {
        let linearServer = AliasLinearGraphQLServer()
        let resolver = WorkProvenanceLinearTicketLinkResolver(
            authorizationHeader: "linear-api-key",
            usesEnvironmentAuthorization: false,
            ticketIdentifierAliasMap: LinearTicketIdentifierAliasMap(prefixAliases: [
                "INP": ["STE"],
            ]),
            dataProvider: { request in try await linearServer.response(for: request) }
        )

        let facts = await resolver.workspaceLinks(for: ["INP-1967"])
        let requestedTicketIDs = await linearServer.requestedTicketIDs

        XCTAssertEqual(requestedTicketIDs, ["INP-1967"])
        XCTAssertEqual(facts.ticketLinks.first?.id, "INP-1967")
        XCTAssertEqual(facts.ticketLinks.first?.title, "Send company industry key to Amplitude")
        XCTAssertEqual(facts.projectLinks.first?.title, "Amplitude targeting")
    }

    private actor AliasLinearGraphQLServer {
        private(set) var requestedTicketIDs: [String] = []

        func response(for request: URLRequest) throws -> (Data, Int) {
            let ticketID = try Self.ticketID(from: request.httpBody)
            requestedTicketIDs.append(ticketID)
            switch ticketID {
            case "INP-1967":
                return (Data(Self.canonicalIssuePayload.utf8), 200)
            default:
                return (Data("{\"data\":{\"issue\":null}}".utf8), 200)
            }
        }

        private static func ticketID(from data: Data?) throws -> String {
            guard let data else { return "" }
            let json = try JSONSerialization.jsonObject(with: data)
            guard let object = json as? [String: Any],
                  let variables = object["variables"] as? [String: Any],
                  let ticketID = variables["id"] as? String else {
                return ""
            }
            return ticketID
        }

        private static let canonicalIssuePayload = """
        {"data":{"issue":{"title":"Send company industry key to Amplitude","url":"https://linear.app/companycam/issue/INP-1967/send-company-industry-key-to-amplitude","assignee":{"name":"Brian Busby"},"project":{"id":"linear-project-1","name":"Amplitude targeting","url":"https://linear.app/companycam/project/amplitude-targeting-c1b9a","slugId":"amplitude-targeting-c1b9a"}}}}
        """
    }
}
