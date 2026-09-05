import BmuxAgentChat
import Foundation

struct AgentChatTranscriptPromptEvidenceSeeder {
    struct Seed: Sendable {
        let record: AgentChatSessionRecord
        let messages: [ChatMessage]
    }

    @discardableResult
    static func seed(
        records: [AgentChatSessionRecord],
        resolver: AgentChatTranscriptResolver,
        tokenOptimizationMode: TokenOptimizationMode,
        recordPrompts: @escaping @MainActor (AgentChatSessionRecord, [ChatMessage]) -> Void
    ) -> Task<Void, Never> {
        Task {
            let seeds = await Task.detached(priority: .utility) {
                let backfill = CodexTranscriptPromptBackfill(tokenOptimizationMode: tokenOptimizationMode)
                return records.compactMap { record -> Seed? in
                    guard record.agentKind == .codex,
                          record.state != .ended,
                          let path = resolver.transcriptPath(for: record) else {
                        return nil
                    }
                    let messages = backfill.userPromptMessages(path: path)
                    return messages.isEmpty ? nil : Seed(record: record, messages: messages)
                }
            }.value
            await MainActor.run {
                for seed in seeds {
                    recordPrompts(seed.record, seed.messages)
                }
            }
        }
    }

    @discardableResult
    static func seed(
        record: AgentChatSessionRecord,
        resolver: AgentChatTranscriptResolver,
        tokenOptimizationMode: TokenOptimizationMode,
        recordPrompts: @escaping @MainActor (AgentChatSessionRecord, [ChatMessage]) -> Void
    ) -> Task<Void, Never> {
        seed(
            records: [record],
            resolver: resolver,
            tokenOptimizationMode: tokenOptimizationMode,
            recordPrompts: recordPrompts
        )
    }
}
