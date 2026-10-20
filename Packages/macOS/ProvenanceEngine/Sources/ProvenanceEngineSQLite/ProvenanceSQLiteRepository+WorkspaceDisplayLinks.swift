import Foundation
import ProvenanceEngineContracts

extension ProvenanceSQLiteRepository {
    func mergedProjectLinks(
        existingLinks: [ProvenanceWorkspaceDisplayProjectLinkRecord],
        incomingLinks: [ProvenanceWorkspaceDisplayProjectLinkRecord]
    ) -> [ProvenanceWorkspaceDisplayProjectLinkRecord] {
        let existingByID = workspaceDisplayProjectLinksByID(existingLinks)
        let incomingByID = workspaceDisplayProjectLinksByID(incomingLinks)
        let ids = uniqueWorkspaceDisplayIDs((existingLinks + incomingLinks).map(\.id))
        return ids.compactMap { id -> ProvenanceWorkspaceDisplayProjectLinkRecord? in
            guard let existing = existingByID[id] ?? incomingByID[id] else { return nil }
            let incoming = incomingByID[id]
            return ProvenanceWorkspaceDisplayProjectLinkRecord(
                id: id,
                system: incoming?.system ?? existing.system,
                title: incoming?.title ?? existing.title,
                url: incoming?.url ?? existing.url
            )
        }
    }

    func workspaceDisplayProjectLinksByID(
        _ links: [ProvenanceWorkspaceDisplayProjectLinkRecord]
    ) -> [String: ProvenanceWorkspaceDisplayProjectLinkRecord] {
        links.reduce(into: [:]) { result, link in
            let trimmedID = link.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedID.isEmpty else { return }
            result[trimmedID] = link
        }
    }

    func mergedTicketFacts(
        existingIDs: [String],
        incomingIDs: [String],
        existingLinks: [ProvenanceWorkspaceDisplayTicketLinkRecord],
        incomingLinks: [ProvenanceWorkspaceDisplayTicketLinkRecord]
    ) -> (ids: [String], links: [ProvenanceWorkspaceDisplayTicketLinkRecord]) {
        let normalizedIncomingIDs = uniqueWorkspaceDisplayIDs(incomingIDs)
        let normalizedExistingIDs = uniqueWorkspaceDisplayIDs(existingIDs)
        let incomingLinkIDs = uniqueWorkspaceDisplayIDs(incomingLinks.map(\.id))
        let ids: [String]
        if !normalizedIncomingIDs.isEmpty {
            ids = normalizedIncomingIDs
        } else if !normalizedExistingIDs.isEmpty {
            ids = normalizedExistingIDs
        } else {
            ids = incomingLinkIDs
        }

        var linkOrder = ids
        let targetIDs = Set(ids)
        for link in existingLinks + incomingLinks {
            let trimmedID = link.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedID.isEmpty else { continue }
            guard normalizedIncomingIDs.isEmpty || targetIDs.contains(trimmedID) else { continue }
            if !linkOrder.contains(trimmedID) {
                linkOrder.append(trimmedID)
            }
        }

        let existingByID = workspaceDisplayTicketLinksByID(existingLinks)
        let incomingByID = workspaceDisplayTicketLinksByID(incomingLinks)
        let links = linkOrder.compactMap { id -> ProvenanceWorkspaceDisplayTicketLinkRecord? in
            guard let existing = existingByID[id] ?? incomingByID[id] else { return nil }
            let incoming = incomingByID[id]
            return ProvenanceWorkspaceDisplayTicketLinkRecord(
                id: id,
                system: incoming?.system ?? existing.system,
                title: incoming?.title ?? existing.title,
                url: incoming?.url ?? existing.url,
                ownerName: incoming?.ownerName ?? existing.ownerName,
                ownerURL: incoming?.ownerURL ?? existing.ownerURL
            )
        }
        return (ids, links)
    }

    func workspaceDisplayTicketLinksByID(
        _ links: [ProvenanceWorkspaceDisplayTicketLinkRecord]
    ) -> [String: ProvenanceWorkspaceDisplayTicketLinkRecord] {
        links.reduce(into: [:]) { result, link in
            let trimmedID = link.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedID.isEmpty else { return }
            result[trimmedID] = link
        }
    }

    func uniqueWorkspaceDisplayIDs(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for id in ids {
            let trimmedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedID.isEmpty, seen.insert(trimmedID).inserted else { continue }
            result.append(trimmedID)
        }
        return result
    }

}
