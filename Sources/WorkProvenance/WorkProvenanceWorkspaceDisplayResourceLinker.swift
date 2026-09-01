import Foundation
import ProvenanceEngineContracts

/// Builds workspace display ticket and project link facts from discovered resource evidence.
struct WorkProvenanceWorkspaceDisplayResourceLinker: Sendable {
    private let ticketLinkResolver: any WorkProvenanceTicketLinkResolving
    private let resourceDiscovery: WorkProvenanceWorkspaceResourceDiscovery

    init(
        ticketLinkResolver: any WorkProvenanceTicketLinkResolving,
        resourceDiscovery: WorkProvenanceWorkspaceResourceDiscovery = WorkProvenanceWorkspaceResourceDiscovery()
    ) {
        self.ticketLinkResolver = ticketLinkResolver
        self.resourceDiscovery = resourceDiscovery
    }

    func linkFacts(
        pullRequest: WorkProvenanceWorkspaceSnapshot.PullRequest?,
        lastSubmittedPrompt: String?,
        existingDisplay: ProvenanceWorkspaceDisplayRecord?
    ) async -> (
        ticketIDs: [String],
        ticketLinks: [ProvenanceWorkspaceDisplayTicketLinkRecord],
        projectLinks: [ProvenanceWorkspaceDisplayProjectLinkRecord]
    ) {
        let resourceEvidence = resourceEvidence(
            pullRequest: pullRequest,
            lastSubmittedPrompt: lastSubmittedPrompt,
            existingDisplay: existingDisplay
        )
        let explicitTicketIDs = resourceEvidence.ticketIDs
        guard explicitTicketIDs.isEmpty else {
            let existingTicketFacts = Self.normalizedTicketFacts(
                ticketIDs: existingDisplay?.ticketIDs ?? [],
                ticketLinks: existingDisplay?.ticketLinks ?? []
            )
            let ticketIDs = Self.mergedTicketIDs(
                discoveredIDs: explicitTicketIDs,
                existingIDs: existingTicketFacts.ids
            )
            let resolvedLinks = await ticketLinkResolver.workspaceLinks(for: explicitTicketIDs)
            let incomingTicketLinks = Self.enrichedTicketLinks(
                ticketIDs: explicitTicketIDs,
                explicitLinks: resourceEvidence.explicitTicketLinks,
                resolvedLinks: resolvedLinks.ticketLinks
            )
            return (
                ticketIDs: ticketIDs,
                ticketLinks: Self.mergedTicketLinks(
                    ticketIDs: ticketIDs,
                    incomingLinks: incomingTicketLinks,
                    existingLinks: existingTicketFacts.links
                ),
                projectLinks: Self.mergedProjectLinks(
                    incomingLinks: resolvedLinks.projectLinks,
                    existingLinks: existingDisplay?.projectLinks ?? []
                )
            )
        }

        guard let existingDisplay else {
            return (ticketIDs: [], ticketLinks: [], projectLinks: [])
        }
        let ticketFacts = Self.normalizedTicketFacts(
            ticketIDs: existingDisplay.ticketIDs,
            ticketLinks: existingDisplay.ticketLinks
        )
        return (
            ticketIDs: ticketFacts.ids,
            ticketLinks: ticketFacts.links,
            projectLinks: Self.normalizedProjectLinks(existingDisplay.projectLinks)
        )
    }

    private func resourceEvidence(
        pullRequest: WorkProvenanceWorkspaceSnapshot.PullRequest?,
        lastSubmittedPrompt: String?,
        existingDisplay: ProvenanceWorkspaceDisplayRecord?
    ) -> WorkProvenanceWorkspaceResourceDiscovery.Result {
        var evidence: [WorkProvenanceWorkspaceResourceDiscovery.TextEvidence] = []
        if let title = Self.normalizedNonEmpty(pullRequest?.title) {
            evidence.append(.init(source: .pullRequestTitle, text: title))
        }
        if let branch = Self.normalizedNonEmpty(pullRequest?.branch) {
            evidence.append(.init(source: .pullRequestBranch, text: branch))
        }
        if let prompt = Self.normalizedNonEmpty(lastSubmittedPrompt) {
            evidence.append(.init(source: .submittedPrompt, text: prompt))
        } else if let storedPrompt = Self.normalizedNonEmpty(existingDisplay?.lastSubmittedPrompt) {
            evidence.append(.init(source: .storedSubmittedPrompt, text: storedPrompt))
        }
        return resourceDiscovery.discover(in: evidence)
    }

    private static func normalizedTicketFacts(
        ticketIDs: [String],
        ticketLinks: [ProvenanceWorkspaceDisplayTicketLinkRecord]
    ) -> (
        ids: [String],
        links: [ProvenanceWorkspaceDisplayTicketLinkRecord]
    ) {
        var seenLinkIDs = Set<String>()
        let links = ticketLinks.compactMap { link -> ProvenanceWorkspaceDisplayTicketLinkRecord? in
            guard let id = normalizedTicketID(link.id),
                  seenLinkIDs.insert(id).inserted else {
                return nil
            }
            return ProvenanceWorkspaceDisplayTicketLinkRecord(
                id: id,
                system: normalizedNonEmpty(link.system),
                title: normalizedNonEmpty(link.title),
                url: normalizedNonEmpty(link.url),
                ownerName: normalizedNonEmpty(link.ownerName),
                ownerURL: normalizedNonEmpty(link.ownerURL)
            )
        }
        var seenTicketIDs = Set<String>()
        let ids = ticketIDs.compactMap { ticketID -> String? in
            guard let id = normalizedTicketID(ticketID),
                  seenTicketIDs.insert(id).inserted else {
                return nil
            }
            return id
        }
        return (
            ids: ids.isEmpty ? links.map(\.id) : ids,
            links: links
        )
    }

    private static func mergedTicketIDs(
        discoveredIDs: [String],
        existingIDs: [String]
    ) -> [String] {
        var seen = Set<String>()
        return (discoveredIDs + existingIDs).compactMap { ticketID in
            guard let id = normalizedTicketID(ticketID),
                  seen.insert(id).inserted else {
                return nil
            }
            return id
        }
    }

    private static func normalizedProjectLinks(
        _ projectLinks: [ProvenanceWorkspaceDisplayProjectLinkRecord]
    ) -> [ProvenanceWorkspaceDisplayProjectLinkRecord] {
        var seen = Set<String>()
        return projectLinks.compactMap { link -> ProvenanceWorkspaceDisplayProjectLinkRecord? in
            guard let id = normalizedNonEmpty(link.id),
                  seen.insert(id).inserted else {
                return nil
            }
            return ProvenanceWorkspaceDisplayProjectLinkRecord(
                id: id,
                system: normalizedNonEmpty(link.system),
                title: normalizedNonEmpty(link.title),
                url: normalizedNonEmpty(link.url)
            )
        }
    }

    private static func mergedProjectLinks(
        incomingLinks: [ProvenanceWorkspaceDisplayProjectLinkRecord],
        existingLinks: [ProvenanceWorkspaceDisplayProjectLinkRecord]
    ) -> [ProvenanceWorkspaceDisplayProjectLinkRecord] {
        let incomingLinks = normalizedProjectLinks(incomingLinks)
        let existingLinks = normalizedProjectLinks(existingLinks)
        guard !incomingLinks.isEmpty else { return existingLinks }
        let existingByID = projectLinksByID(existingLinks)
        let incomingByID = projectLinksByID(incomingLinks)
        let projectIDs = orderedProjectIDs(incomingLinks + existingLinks)
        return projectIDs.compactMap { id in
            let incoming = incomingByID[id]
            let existing = existingByID[id]
            guard incoming != nil || existing != nil else { return nil }
            return ProvenanceWorkspaceDisplayProjectLinkRecord(
                id: id,
                system: normalizedNonEmpty(incoming?.system) ?? normalizedNonEmpty(existing?.system),
                title: normalizedNonEmpty(incoming?.title) ?? normalizedNonEmpty(existing?.title),
                url: normalizedNonEmpty(incoming?.url) ?? normalizedNonEmpty(existing?.url)
            )
        }
    }

    private static func orderedProjectIDs(
        _ links: [ProvenanceWorkspaceDisplayProjectLinkRecord]
    ) -> [String] {
        var seen = Set<String>()
        return links.compactMap { link in
            guard let id = normalizedNonEmpty(link.id),
                  seen.insert(id).inserted else {
                return nil
            }
            return id
        }
    }

    private static func projectLinksByID(
        _ links: [ProvenanceWorkspaceDisplayProjectLinkRecord]
    ) -> [String: ProvenanceWorkspaceDisplayProjectLinkRecord] {
        links.reduce(into: [:]) { result, link in
            guard let id = normalizedNonEmpty(link.id) else { return }
            result[id] = link
        }
    }

    private static func enrichedTicketLinks(
        ticketIDs: [String],
        explicitLinks: [ProvenanceWorkspaceDisplayTicketLinkRecord],
        resolvedLinks: [ProvenanceWorkspaceDisplayTicketLinkRecord]
    ) -> [ProvenanceWorkspaceDisplayTicketLinkRecord] {
        let normalizedTicketIDs = normalizedTicketFacts(ticketIDs: ticketIDs, ticketLinks: []).ids
        let explicitByID = ticketLinksByID(explicitLinks)
        let resolvedByID = ticketLinksByID(resolvedLinks)
        return normalizedTicketIDs.compactMap { id in
            let explicit = explicitByID[id]
            let resolved = resolvedByID[id]
            guard explicit != nil || resolved != nil else { return nil }
            let hasResolvedTicketMetadata = normalizedNonEmpty(resolved?.title) != nil
                || normalizedNonEmpty(resolved?.ownerName) != nil
                || normalizedNonEmpty(resolved?.ownerURL) != nil
            let url = hasResolvedTicketMetadata
                ? normalizedNonEmpty(resolved?.url) ?? normalizedNonEmpty(explicit?.url)
                : normalizedNonEmpty(explicit?.url) ?? normalizedNonEmpty(resolved?.url)
            return ProvenanceWorkspaceDisplayTicketLinkRecord(
                id: id,
                system: normalizedNonEmpty(resolved?.system) ?? normalizedNonEmpty(explicit?.system),
                title: normalizedNonEmpty(resolved?.title) ?? normalizedNonEmpty(explicit?.title),
                url: url,
                ownerName: normalizedNonEmpty(resolved?.ownerName) ?? normalizedNonEmpty(explicit?.ownerName),
                ownerURL: normalizedNonEmpty(resolved?.ownerURL) ?? normalizedNonEmpty(explicit?.ownerURL)
            )
        }
    }

    private static func mergedTicketLinks(
        ticketIDs: [String],
        incomingLinks: [ProvenanceWorkspaceDisplayTicketLinkRecord],
        existingLinks: [ProvenanceWorkspaceDisplayTicketLinkRecord]
    ) -> [ProvenanceWorkspaceDisplayTicketLinkRecord] {
        let normalizedTicketIDs = normalizedTicketFacts(ticketIDs: ticketIDs, ticketLinks: []).ids
        let incomingByID = ticketLinksByID(incomingLinks)
        let existingByID = ticketLinksByID(existingLinks)
        return normalizedTicketIDs.compactMap { id in
            let incoming = incomingByID[id]
            let existing = existingByID[id]
            guard incoming != nil || existing != nil else { return nil }
            return ProvenanceWorkspaceDisplayTicketLinkRecord(
                id: id,
                system: normalizedNonEmpty(incoming?.system) ?? normalizedNonEmpty(existing?.system),
                title: normalizedNonEmpty(incoming?.title) ?? normalizedNonEmpty(existing?.title),
                url: normalizedNonEmpty(incoming?.url) ?? normalizedNonEmpty(existing?.url),
                ownerName: normalizedNonEmpty(incoming?.ownerName) ?? normalizedNonEmpty(existing?.ownerName),
                ownerURL: normalizedNonEmpty(incoming?.ownerURL) ?? normalizedNonEmpty(existing?.ownerURL)
            )
        }
    }

    private static func ticketLinksByID(
        _ links: [ProvenanceWorkspaceDisplayTicketLinkRecord]
    ) -> [String: ProvenanceWorkspaceDisplayTicketLinkRecord] {
        links.reduce(into: [:]) { result, link in
            guard let id = normalizedTicketID(link.id) else { return }
            result[id] = link
        }
    }

    private static func normalizedTicketID(_ value: String?) -> String? {
        normalizedNonEmpty(value)?.uppercased()
    }

    private static func normalizedNonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
