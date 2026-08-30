import Foundation

struct ProvenanceSemanticMessageLocalization {
    private enum Language {
        case english
        case japanese
    }

    private let language: Language

    init(localeIdentifier: String?) {
        if localeIdentifier?.lowercased().hasPrefix("ja") == true {
            self.language = .japanese
        } else {
            self.language = .english
        }
    }

    func blockersUnknown(reason: String) -> ProvenanceSemanticMessageRenderer.RenderedMessage {
        switch language {
        case .english:
            return message("Blockers unknown", reason)
        case .japanese:
            return message("ブロッカー不明", localizedUnknownReason(reason))
        }
    }

    func noSupportedBlockers() -> ProvenanceSemanticMessageRenderer.RenderedMessage {
        switch language {
        case .english:
            return message(
                "No supported blockers",
                "No supported explicit blocker statement is active in the bounded session evidence."
            )
        case .japanese:
            return message(
                "対応済みのブロッカーなし",
                "境界づけられたセッション証拠には、対応済みの明示的なブロッカー文はありません。"
            )
        }
    }

    func blockerOpen(_ blocker: ProvenanceCodingAgentBlocker) -> ProvenanceSemanticMessageRenderer.RenderedMessage {
        switch language {
        case .english:
            return message(
                "Blocked: \(blocker.affectedActivity)",
                "The provider reported \(lowercaseFirst(blocker.affectedActivity)) is blocked by \(blocker.condition)."
            )
        case .japanese:
            return message(
                "ブロック中: \(blocker.affectedActivity)",
                "プロバイダーは\(blocker.affectedActivity)が\(blocker.condition)によってブロックされていると報告しました。"
            )
        }
    }

    func blockerCleared(_ blocker: ProvenanceCodingAgentBlocker) -> ProvenanceSemanticMessageRenderer.RenderedMessage {
        switch language {
        case .english:
            return message(
                "Blocker cleared",
                "The provider reported the blocker for \(lowercaseFirst(blocker.affectedActivity)) was cleared."
            )
        case .japanese:
            return message(
                "ブロッカー解消済み",
                "プロバイダーは\(blocker.affectedActivity)のブロッカーが解消されたと報告しました。"
            )
        }
    }

    func blockerBypassed(_ blocker: ProvenanceCodingAgentBlocker) -> ProvenanceSemanticMessageRenderer.RenderedMessage {
        switch language {
        case .english:
            return message(
                "Blocker bypassed",
                "The provider reported work can proceed by bypassing \(blocker.condition)."
            )
        case .japanese:
            return message(
                "ブロッカー迂回済み",
                "プロバイダーは\(blocker.condition)を迂回して作業を進められると報告しました。"
            )
        }
    }

    func blockerNoLongerApplies(
        _ blocker: ProvenanceCodingAgentBlocker
    ) -> ProvenanceSemanticMessageRenderer.RenderedMessage {
        switch language {
        case .english:
            return message(
                "Blocker no longer applies",
                "The provider reported \(blocker.condition) no longer applies to \(lowercaseFirst(blocker.affectedActivity))."
            )
        case .japanese:
            return message(
                "ブロッカー適用外",
                "プロバイダーは\(blocker.condition)が\(blocker.affectedActivity)に適用されなくなったと報告しました。"
            )
        }
    }

    func blockerStateUnknown(
        _ blocker: ProvenanceCodingAgentBlocker
    ) -> ProvenanceSemanticMessageRenderer.RenderedMessage {
        switch language {
        case .english:
            return message("Blocker state unknown", blocker.description)
        case .japanese:
            return message("ブロッカー状態不明", blocker.description)
        }
    }

    func approachChangesUnknown(reason: String) -> ProvenanceSemanticMessageRenderer.RenderedMessage {
        switch language {
        case .english:
            return message("Approach changes unknown", reason)
        case .japanese:
            return message("アプローチ変更不明", localizedUnknownReason(reason))
        }
    }

    func noSupportedApproachChanges() -> ProvenanceSemanticMessageRenderer.RenderedMessage {
        switch language {
        case .english:
            return message(
                "No supported approach changes",
                "No supported explicit approach-change statement is active in the bounded session evidence."
            )
        case .japanese:
            return message(
                "対応済みのアプローチ変更なし",
                "境界づけられたセッション証拠には、対応済みの明示的なアプローチ変更文はありません。"
            )
        }
    }

    func approachReplaced(
        _ change: ProvenanceCodingAgentApproachChange
    ) -> ProvenanceSemanticMessageRenderer.RenderedMessage {
        switch language {
        case .english:
            return message(
                "Approach replaced",
                "The provider reported replacing \(lowercaseFirst(change.priorApproach)) with \(change.replacementApproach ?? "an unspecified replacement")."
            )
        case .japanese:
            return message(
                "アプローチ置換済み",
                "プロバイダーは\(change.priorApproach)を\(change.replacementApproach ?? "未指定の置換案")に置き換えると報告しました。"
            )
        }
    }

    func approachAbandoned(
        _ change: ProvenanceCodingAgentApproachChange
    ) -> ProvenanceSemanticMessageRenderer.RenderedMessage {
        switch language {
        case .english:
            return message(
                "Approach abandoned",
                "The provider reported abandoning \(lowercaseFirst(change.priorApproach))."
            )
        case .japanese:
            return message(
                "アプローチ破棄済み",
                "プロバイダーは\(change.priorApproach)を破棄すると報告しました。"
            )
        }
    }

    func approachDeferred(
        _ change: ProvenanceCodingAgentApproachChange
    ) -> ProvenanceSemanticMessageRenderer.RenderedMessage {
        switch language {
        case .english:
            return message(
                "Approach deferred",
                "The provider reported deferring \(lowercaseFirst(change.priorApproach))."
            )
        case .japanese:
            return message(
                "アプローチ延期済み",
                "プロバイダーは\(change.priorApproach)を延期すると報告しました。"
            )
        }
    }

    func approachFailed(
        _ change: ProvenanceCodingAgentApproachChange
    ) -> ProvenanceSemanticMessageRenderer.RenderedMessage {
        switch language {
        case .english:
            return message(
                "Approach failed",
                "The provider reported \(lowercaseFirst(change.priorApproach)) failed."
            )
        case .japanese:
            return message(
                "アプローチ失敗",
                "プロバイダーは\(change.priorApproach)が失敗したと報告しました。"
            )
        }
    }

    func approachStateUnknown(
        _ change: ProvenanceCodingAgentApproachChange
    ) -> ProvenanceSemanticMessageRenderer.RenderedMessage {
        switch language {
        case .english:
            return message("Approach-change state unknown", change.objective)
        case .japanese:
            return message("アプローチ変更状態不明", change.objective)
        }
    }

    private func message(
        _ concisePhrase: String,
        _ expandedMeaning: String
    ) -> ProvenanceSemanticMessageRenderer.RenderedMessage {
        ProvenanceSemanticMessageRenderer.RenderedMessage(
            concisePhrase: concisePhrase,
            expandedMeaning: expandedMeaning
        )
    }

    private func lowercaseFirst(_ value: String) -> String {
        ProvenanceSemanticMessageRenderer.lowercaseFirst(value)
    }

    private func localizedUnknownReason(_ reason: String) -> String {
        switch reason {
        case "No supported explicit blocker statement is available in the bounded factual session projection.":
            return "境界づけられた事実セッション投影には、対応済みの明示的なブロッカー文がありません。"
        case "No supported explicit approach-change statement is available in the bounded factual session projection.":
            return "境界づけられた事実セッション投影には、対応済みの明示的なアプローチ変更文がありません。"
        default:
            return reason
        }
    }
}
