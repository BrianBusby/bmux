import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK
import Testing
#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif
@Suite
struct WorkProvenanceWorkspaceResourceDiscoveryTests {
    @Test(arguments: [
        ResourceDiscoveryScenario(
            text: "Implement INP-2220 project context resource discovery",
            expectedIDs: ["INP-2220"],
            expectedURLs: []
        ),
        ResourceDiscoveryScenario(
            text: "https://linear.app/companycam/issue/INP-2220/expose-one-off-advanced-checklist-authoring",
            expectedIDs: ["INP-2220"],
            expectedURLs: [
                "https://linear.app/companycam/issue/INP-2220/expose-one-off-advanced-checklist-authoring"
            ]
        ),
        ResourceDiscoveryScenario(
            text: "INP-2220 https://linear.app/companycam/issue/INP-2220/expose-one-off-advanced-checklist-authoring",
            expectedIDs: ["INP-2220"],
            expectedURLs: [
                "https://linear.app/companycam/issue/INP-2220/expose-one-off-advanced-checklist-authoring"
            ]
        ),
        ResourceDiscoveryScenario(
            text: "Implement INP-2220 and STE-1964 without dropping either ticket",
            expectedIDs: ["INP-2220", "STE-1964"],
            expectedURLs: []
        ),
        ResourceDiscoveryScenario(
            text: "HTTP-404, INP-, INP-abc, A-1, and Company-Cam-API are incidental text",
            expectedIDs: [],
            expectedURLs: []
        )
    ])
    func extractsLinearTicketsFromBoundedText(_ scenario: ResourceDiscoveryScenario) {
        let result = WorkProvenanceWorkspaceResourceDiscovery().discover(in: [
            .init(source: .submittedPrompt, text: scenario.text)
        ])
        #expect(result.ticketIDs == scenario.expectedIDs)
        #expect(result.explicitTicketLinks.map(\.url) == scenario.expectedURLs)
    }

    @Test
    func dedupesPromptAndPullRequestTicketEvidence() {
        let result = WorkProvenanceWorkspaceResourceDiscovery().discover(in: [
            .init(source: .submittedPrompt, text: "Implement INP-2220"),
            .init(source: .pullRequestTitle, text: "INP-2220 prompt-derived workspace resources"),
            .init(source: .pullRequestBranch, text: "inp-2220-prompt-derived-workspace-resources")
        ])

        #expect(result.ticketIDs == ["INP-2220"])
        #expect(result.tickets.first?.sources == [
            .submittedPrompt,
            .pullRequestTitle,
            .pullRequestBranch
        ])
    }

    @Test
    func submittedPromptTicketIDOnlyPersistsUnresolvedTicketLinkWithoutLinearAuth() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let client = try Self.client(for: fixture)
        let repositoryRoot = "/tmp/bmux-prompt-ticket-id-only-repo"
        let service = WorkProvenanceObservationService(
            client: client,
            gitInspector: FakeGitInspector(snapshotsByDirectory: [
                repositoryRoot: Self.gitSnapshot(repositoryRoot: repositoryRoot)
            ]),
            ticketLinkResolver: WorkProvenanceLinearTicketLinkResolver(
                authorizationHeader: nil,
                usesEnvironmentAuthorization: false
            ),
            dateProvider: { Date(timeIntervalSince1970: 590) }
        )
        let stableWorkspaceID = UUID(uuidString: "10101010-2020-3030-4040-505050505050")!
        let workspace = WorkProvenanceWorkspaceSnapshot(
            workspaceID: UUID(uuidString: "10101010-2020-3030-4040-505050505051")!,
            stableWorkspaceID: stableWorkspaceID,
            title: "Prompt ticket",
            currentDirectory: repositoryRoot,
            branch: "prompt-derived-workspace-resources",
            lastSubmittedPrompt: "Implement INP-2220 project context resource discovery",
            lastSubmittedPromptSubmittedAt: Date(timeIntervalSince1970: 589)
        )

        await service.observeWorkspaceSnapshot(workspace)

        let display = try await client.workspaceDisplay(ProvenanceWorkspaceDisplayRequest(
            workspaceID: stableWorkspaceID.uuidString
        ))

        #expect(display.found)
        #expect(display.display?.ticketIDs == ["INP-2220"])
        #expect(display.display?.ticketLinks == [
            Self.linearUnresolvedTicketLink(id: "INP-2220")
        ])
        #expect(display.display?.projectLinks == [])
        #expect(display.display?.lastSubmittedPrompt == "Implement INP-2220 project context resource discovery")
    }

    @Test
    func submittedPromptLinearIssueURLPersistsExplicitURLWhenResolutionUnavailable() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let client = try Self.client(for: fixture)
        let repositoryRoot = "/tmp/bmux-prompt-linear-url-repo"
        let explicitURL = "https://linear.app/companycam/issue/INP-2220/expose-one-off-advanced-checklist-authoring"
        let service = WorkProvenanceObservationService(
            client: client,
            gitInspector: FakeGitInspector(snapshotsByDirectory: [
                repositoryRoot: Self.gitSnapshot(repositoryRoot: repositoryRoot)
            ]),
            ticketLinkResolver: WorkProvenanceLinearTicketLinkResolver(
                authorizationHeader: nil,
                usesEnvironmentAuthorization: false
            ),
            dateProvider: { Date(timeIntervalSince1970: 591) }
        )
        let stableWorkspaceID = UUID(uuidString: "11111111-2020-3030-4040-505050505050")!
        let workspace = WorkProvenanceWorkspaceSnapshot(
            workspaceID: UUID(uuidString: "11111111-2020-3030-4040-505050505051")!,
            stableWorkspaceID: stableWorkspaceID,
            title: "Prompt URL",
            currentDirectory: repositoryRoot,
            branch: "prompt-derived-linear-url",
            lastSubmittedPrompt: "Implement \(explicitURL)",
            lastSubmittedPromptSubmittedAt: Date(timeIntervalSince1970: 590)
        )

        await service.observeWorkspaceSnapshot(workspace)

        let display = try await client.workspaceDisplay(ProvenanceWorkspaceDisplayRequest(
            workspaceID: stableWorkspaceID.uuidString
        ))

        #expect(display.found)
        #expect(display.display?.ticketIDs == ["INP-2220"])
        #expect(display.display?.ticketLinks == [
            Self.linearUnresolvedTicketLink(id: "INP-2220", url: explicitURL)
        ])
        #expect(display.display?.projectLinks == [])
    }

    @Test
    func promptAndPullRequestEvidenceDedupesBeforeLinearResolutionAndEnrichesProjectLinks() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let client = try Self.client(for: fixture)
        let repositoryRoot = "/tmp/bmux-prompt-pr-dedupe-repo"
        let explicitURL = "https://linear.app/companycam/issue/INP-2220/expose-one-off-advanced-checklist-authoring"
        let linearServer = FakeLinearGraphQLServer()
        let service = WorkProvenanceObservationService(
            client: client,
            gitInspector: FakeGitInspector(snapshotsByDirectory: [
                repositoryRoot: Self.gitSnapshot(repositoryRoot: repositoryRoot)
            ]),
            ticketLinkResolver: WorkProvenanceLinearTicketLinkResolver(
                authorizationHeader: "linear-api-key",
                usesEnvironmentAuthorization: false,
                dataProvider: { request in try await linearServer.response(for: request) }
            ),
            dateProvider: { Date(timeIntervalSince1970: 592) }
        )
        let stableWorkspaceID = UUID(uuidString: "12121212-2020-3030-4040-505050505050")!
        let workspace = WorkProvenanceWorkspaceSnapshot(
            workspaceID: UUID(uuidString: "12121212-2020-3030-4040-505050505051")!,
            stableWorkspaceID: stableWorkspaceID,
            title: "Prompt and PR",
            currentDirectory: repositoryRoot,
            branch: "inp-2220-prompt-derived-workspace-resources",
            pullRequest: WorkProvenanceWorkspaceSnapshot.PullRequest(
                number: 2220,
                title: "INP-2220 prompt-derived workspace resources",
                url: "https://github.com/manaflow-ai/bmux/pull/2220",
                ownerLogin: "brianbusby",
                ownerURL: "https://github.com/brianbusby",
                status: "open",
                branch: "inp-2220-prompt-derived-workspace-resources",
                isStale: false
            ),
            lastSubmittedPrompt: "Implement \(explicitURL)",
            lastSubmittedPromptSubmittedAt: Date(timeIntervalSince1970: 591)
        )

        await service.observeWorkspaceSnapshot(workspace)

        let display = try await client.workspaceDisplay(ProvenanceWorkspaceDisplayRequest(
            workspaceID: stableWorkspaceID.uuidString
        ))

        #expect(display.found)
        #expect(display.display?.ticketIDs == ["INP-2220"])
        #expect(display.display?.ticketLinks == [
            Self.linearTicketLink(id: "INP-2220")
        ])
        #expect(display.display?.projectLinks == [
            Self.linearProjectLink()
        ])
        #expect(await linearServer.requests == [
            FakeLinearGraphQLServer.Request(authorization: "linear-api-key", ticketID: "INP-2220")
        ])
    }

    @Test
    func promptEvidencePreservesExistingWorkspaceResourceFacts() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let client = try Self.client(for: fixture)
        let repositoryRoot = "/tmp/bmux-prompt-existing-resource-merge-repo"
        let stableWorkspaceID = UUID(uuidString: "16161616-2020-3030-4040-505050505050")!
        let seedDisplay = ProvenanceWorkspaceDisplayRecord(
            id: "workspace-display-\(stableWorkspaceID.uuidString)",
            workspaceID: stableWorkspaceID.uuidString,
            currentDirectory: repositoryRoot,
            title: "Existing PR",
            branch: "ste-1964-canonical-domain-mutation-paths",
            ticketIDs: ["STE-1964"],
            ticketLinks: [
                Self.linearTicketLink(id: "STE-1964")
            ],
            projectLinks: [
                Self.previousProjectLink()
            ],
            observedAt: Date(timeIntervalSince1970: 598),
            updatedAt: Date(timeIntervalSince1970: 598)
        )
        let seedEvent = ProvenanceEngineContracts.ProvenanceEvent(
            eventType: .workspaceDisplayObserved,
            timestamp: Date(timeIntervalSince1970: 598),
            source: ProvenanceEngineContracts.ProvenanceSource.observed,
            evidenceOrigin: ProvenanceEngineContracts.ProvenanceEvidenceOrigin(
                rawValue: "bmux-work-provenance-observation"
            ),
            evidenceScope: ProvenanceEngineContracts.ProvenanceEvidenceScope(level: .personal, id: "bmux-local"),
            confidence: ProvenanceEngineContracts.ProvenanceConfidence.high,
            payload: ProvenanceEngineContracts.ProvenanceEventPayload(
                workspaceDisplay: seedDisplay
            )
        )
        _ = try await client.appendEvent(ProvenanceEngineContracts.ProvenanceAppendEventRequest(event: seedEvent))
        let linearServer = FakeLinearGraphQLServer()
        let service = WorkProvenanceObservationService(
            client: client,
            gitInspector: FakeGitInspector(snapshotsByDirectory: [
                repositoryRoot: Self.gitSnapshot(repositoryRoot: repositoryRoot)
            ]),
            ticketLinkResolver: WorkProvenanceLinearTicketLinkResolver(
                authorizationHeader: "linear-api-key",
                usesEnvironmentAuthorization: false,
                dataProvider: { request in try await linearServer.response(for: request) }
            ),
            dateProvider: { Date(timeIntervalSince1970: 599) }
        )
        let workspace = WorkProvenanceWorkspaceSnapshot(
            workspaceID: UUID(uuidString: "16161616-2020-3030-4040-505050505051")!,
            stableWorkspaceID: stableWorkspaceID,
            title: "Prompt adds ticket",
            currentDirectory: repositoryRoot,
            branch: "prompt-derived-workspace-resources",
            lastSubmittedPrompt: "Implement INP-2220 without dropping existing resource facts",
            lastSubmittedPromptSubmittedAt: Date(timeIntervalSince1970: 599)
        )

        await service.observeWorkspaceSnapshot(workspace)

        let display = try await client.workspaceDisplay(ProvenanceWorkspaceDisplayRequest(
            workspaceID: stableWorkspaceID.uuidString
        ))

        #expect(display.display?.ticketIDs == ["INP-2220", "STE-1964"])
        #expect(display.display?.ticketLinks == [
            Self.linearTicketLink(id: "INP-2220"),
            Self.linearTicketLink(id: "STE-1964")
        ])
        let projectLinkIDs = Set(display.display?.projectLinks.map(\.id) ?? [])
        #expect(projectLinkIDs == Set([
            "context-efficiency-c1b9a",
            "existing-pr-project"
        ]))
        #expect(await linearServer.requests == [
            FakeLinearGraphQLServer.Request(authorization: "linear-api-key", ticketID: "INP-2220")
        ])
    }

    @Test
    func submittedPromptMultipleTicketsPersistsAndEnrichesEachTicketOnce() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let client = try Self.client(for: fixture)
        let repositoryRoot = "/tmp/bmux-prompt-multiple-tickets-repo"
        let linearServer = FakeLinearGraphQLServer()
        let service = WorkProvenanceObservationService(
            client: client,
            gitInspector: FakeGitInspector(snapshotsByDirectory: [
                repositoryRoot: Self.gitSnapshot(repositoryRoot: repositoryRoot)
            ]),
            ticketLinkResolver: WorkProvenanceLinearTicketLinkResolver(
                authorizationHeader: "linear-api-key",
                usesEnvironmentAuthorization: false,
                dataProvider: { request in try await linearServer.response(for: request) }
            ),
            dateProvider: { Date(timeIntervalSince1970: 593) }
        )
        let stableWorkspaceID = UUID(uuidString: "13131313-2020-3030-4040-505050505050")!
        let workspace = WorkProvenanceWorkspaceSnapshot(
            workspaceID: UUID(uuidString: "13131313-2020-3030-4040-505050505051")!,
            stableWorkspaceID: stableWorkspaceID,
            title: "Multiple tickets",
            currentDirectory: repositoryRoot,
            branch: "multi-ticket-prompt",
            lastSubmittedPrompt: "Implement INP-2220 and STE-1964 in one coherent slice",
            lastSubmittedPromptSubmittedAt: Date(timeIntervalSince1970: 592)
        )

        await service.observeWorkspaceSnapshot(workspace)

        let display = try await client.workspaceDisplay(ProvenanceWorkspaceDisplayRequest(
            workspaceID: stableWorkspaceID.uuidString
        ))

        #expect(display.found)
        #expect(display.display?.ticketIDs == ["INP-2220", "STE-1964"])
        #expect(display.display?.ticketLinks == [
            Self.linearTicketLink(id: "INP-2220"),
            Self.linearTicketLink(id: "STE-1964")
        ])
        #expect(display.display?.projectLinks == [
            Self.linearProjectLink()
        ])
        #expect(await linearServer.requests == [
            FakeLinearGraphQLServer.Request(authorization: "linear-api-key", ticketID: "INP-2220"),
            FakeLinearGraphQLServer.Request(authorization: "linear-api-key", ticketID: "STE-1964")
        ])
    }

    @Test
    func linearResolutionFailurePreservesPromptMetadataAndRetriesLater() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let client = try Self.client(for: fixture)
        let repositoryRoot = "/tmp/bmux-prompt-resolution-retry-repo"
        let explicitURL = "https://linear.app/companycam/issue/INP-2220/expose-one-off-advanced-checklist-authoring"
        let snapshot = Self.gitSnapshot(repositoryRoot: repositoryRoot)
        let failingService = WorkProvenanceObservationService(
            client: client,
            gitInspector: FakeGitInspector(snapshotsByDirectory: [repositoryRoot: snapshot]),
            ticketLinkResolver: WorkProvenanceLinearTicketLinkResolver(
                authorizationHeader: "linear-api-key",
                usesEnvironmentAuthorization: false,
                dataProvider: { _ in (Data("{}".utf8), 500) }
            ),
            dateProvider: { Date(timeIntervalSince1970: 594) }
        )
        let linearServer = FakeLinearGraphQLServer()
        let retryService = WorkProvenanceObservationService(
            client: client,
            gitInspector: FakeGitInspector(snapshotsByDirectory: [repositoryRoot: snapshot]),
            ticketLinkResolver: WorkProvenanceLinearTicketLinkResolver(
                authorizationHeader: "linear-api-key",
                usesEnvironmentAuthorization: false,
                dataProvider: { request in try await linearServer.response(for: request) }
            ),
            dateProvider: { Date(timeIntervalSince1970: 595) }
        )
        let stableWorkspaceID = UUID(uuidString: "14141414-2020-3030-4040-505050505050")!
        let workspace = WorkProvenanceWorkspaceSnapshot(
            workspaceID: UUID(uuidString: "14141414-2020-3030-4040-505050505051")!,
            stableWorkspaceID: stableWorkspaceID,
            title: "Resolution retry",
            currentDirectory: repositoryRoot,
            branch: "prompt-resolution-retry",
            lastSubmittedPrompt: "Implement \(explicitURL)",
            lastSubmittedPromptSubmittedAt: Date(timeIntervalSince1970: 593)
        )

        await failingService.observeWorkspaceSnapshot(workspace)
        let unresolvedDisplay = try await client.workspaceDisplay(ProvenanceWorkspaceDisplayRequest(
            workspaceID: stableWorkspaceID.uuidString
        ))

        #expect(unresolvedDisplay.display?.ticketIDs == ["INP-2220"])
        #expect(unresolvedDisplay.display?.ticketLinks == [
            Self.linearUnresolvedTicketLink(id: "INP-2220", url: explicitURL)
        ])
        #expect(unresolvedDisplay.display?.projectLinks == [])

        await retryService.observeWorkspaceSnapshot(workspace)

        let resolvedDisplay = try await client.workspaceDisplay(ProvenanceWorkspaceDisplayRequest(
            workspaceID: stableWorkspaceID.uuidString
        ))

        #expect(resolvedDisplay.display?.ticketIDs == ["INP-2220"])
        #expect(resolvedDisplay.display?.ticketLinks == [
            Self.linearTicketLink(id: "INP-2220")
        ])
        #expect(resolvedDisplay.display?.projectLinks == [
            Self.linearProjectLink()
        ])
        #expect(await linearServer.requests == [
            FakeLinearGraphQLServer.Request(authorization: "linear-api-key", ticketID: "INP-2220")
        ])
    }

    @Test
    func storedSubmittedPromptBackfillIsIdempotent() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let client = try Self.client(for: fixture)
        let stableWorkspaceID = UUID(uuidString: "15151515-2020-3030-4040-505050505050")!
        let workspaceID = UUID(uuidString: "15151515-2020-3030-4040-505050505051")!
        let seedDisplay = ProvenanceWorkspaceDisplayRecord(
            id: "workspace-display-\(stableWorkspaceID.uuidString)",
            workspaceID: stableWorkspaceID.uuidString,
            currentDirectory: "/tmp/not-a-repo-for-prompt-backfill",
            title: "Stored prompt",
            lastSubmittedPrompt: "Implement INP-2220 from stored prompt",
            lastSubmittedPromptSubmittedAt: Date(timeIntervalSince1970: 596),
            observedAt: Date(timeIntervalSince1970: 596),
            updatedAt: Date(timeIntervalSince1970: 596)
        )
        let seedEvent = ProvenanceEngineContracts.ProvenanceEvent(
            eventType: .workspaceDisplayObserved,
            timestamp: Date(timeIntervalSince1970: 596),
            source: ProvenanceEngineContracts.ProvenanceSource.observed,
            evidenceOrigin: ProvenanceEngineContracts.ProvenanceEvidenceOrigin(
                rawValue: "bmux-work-provenance-observation"
            ),
            evidenceScope: ProvenanceEngineContracts.ProvenanceEvidenceScope(level: .personal, id: "bmux-local"),
            confidence: ProvenanceEngineContracts.ProvenanceConfidence.high,
            payload: ProvenanceEngineContracts.ProvenanceEventPayload(
                workspaceDisplay: seedDisplay
            )
        )
        _ = try await client.appendEvent(ProvenanceEngineContracts.ProvenanceAppendEventRequest(event: seedEvent))
        let service = WorkProvenanceObservationService(
            client: client,
            gitInspector: FakeGitInspector(snapshotsByDirectory: [:]),
            ticketLinkResolver: WorkProvenanceLinearTicketLinkResolver(
                authorizationHeader: nil,
                usesEnvironmentAuthorization: false
            ),
            dateProvider: { Date(timeIntervalSince1970: 597) }
        )
        let workspace = WorkProvenanceWorkspaceSnapshot(
            workspaceID: workspaceID,
            stableWorkspaceID: stableWorkspaceID,
            title: "Stored prompt",
            currentDirectory: "/tmp/not-a-repo-for-prompt-backfill"
        )

        await service.observeWorkspaceSnapshot(workspace)
        await service.observeWorkspaceSnapshot(workspace)

        let display = try await client.workspaceDisplay(ProvenanceWorkspaceDisplayRequest(
            workspaceID: stableWorkspaceID.uuidString
        ))

        #expect(display.found)
        #expect(display.display?.ticketIDs == ["INP-2220"])
        #expect(display.display?.ticketLinks == [
            Self.linearUnresolvedTicketLink(id: "INP-2220")
        ])
        #expect(display.display?.lastSubmittedPrompt == "Implement INP-2220 from stored prompt")
        #expect(display.display?.latestEventSequence == 2)
    }

}
