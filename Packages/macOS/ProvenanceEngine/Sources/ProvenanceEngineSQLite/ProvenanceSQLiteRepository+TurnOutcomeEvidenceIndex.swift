import Foundation
import ProvenanceEngineContracts

struct TurnOutcomeEvidenceKey: Hashable {
    let kind: String
    let id: String
}

struct TurnOutcomeEvidenceIndex {
    private var referencesByKey: [TurnOutcomeEvidenceKey: [ProvenanceTurnOutcomeEvidenceReference]]

    init(referencesByKey: [TurnOutcomeEvidenceKey: [ProvenanceTurnOutcomeEvidenceReference]]) {
        var normalized: [TurnOutcomeEvidenceKey: [ProvenanceTurnOutcomeEvidenceReference]] = [:]
        for (key, references) in referencesByKey {
            let sourceState = references.count > 1 ? "duplicated" : "available"
            normalized[key] = references.map {
                ProvenanceTurnOutcomeEvidenceReference(
                    eventID: $0.eventID,
                    eventSequence: $0.eventSequence,
                    eventType: $0.eventType,
                    source: $0.source,
                    evidenceOrigin: $0.evidenceOrigin,
                    evidenceScope: $0.evidenceScope,
                    recordKind: $0.recordKind,
                    recordID: $0.recordID,
                    interpretedByRuleVersion: $0.interpretedByRuleVersion,
                    sourceState: sourceState
                )
            }
        }
        self.referencesByKey = normalized
    }

    func references(kind: String, id: String?) -> [ProvenanceTurnOutcomeEvidenceReference] {
        guard let id else { return [] }
        return referencesByKey[TurnOutcomeEvidenceKey(kind: kind, id: id)] ?? []
    }
}

