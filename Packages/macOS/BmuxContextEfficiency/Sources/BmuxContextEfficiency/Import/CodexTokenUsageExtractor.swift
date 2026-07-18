import Foundation

struct CodexTokenUsageExtractor: Sendable {
    func extract(from object: Any) -> ContextEfficiencyTokenUsage? {
        if let dictionary = object as? [String: Any] {
            let directUsage = usage(from: dictionary)
            if directUsage.hasAnyTokenCount {
                return directUsage
            }
            for key in ["usage", "token_usage", "tokenUsage", "tokens", "total"] {
                if let nested = dictionary[key],
                   let usage = extract(from: nested) {
                    return usage
                }
            }
            for value in dictionary.values {
                if let usage = extract(from: value) {
                    return usage
                }
            }
        }
        if let array = object as? [Any] {
            for value in array {
                if let usage = extract(from: value) {
                    return usage
                }
            }
        }
        return nil
    }

    private func usage(from dictionary: [String: Any]) -> ContextEfficiencyTokenUsage {
        ContextEfficiencyTokenUsage(
            inputTokens: int64Value(
                for: [
                    "input_tokens",
                    "inputTokens",
                    "prompt_tokens",
                    "promptTokens",
                ],
                in: dictionary
            ),
            cachedInputTokens: int64Value(
                for: [
                    "cached_input_tokens",
                    "cachedInputTokens",
                    "input_cached_tokens",
                    "inputCachedTokens",
                    "cache_read_input_tokens",
                    "cacheReadInputTokens",
                ],
                in: dictionary
            ) ?? nestedInt64Value(
                for: ["cached_tokens", "cachedTokens"],
                in: [
                    "input_tokens_details",
                    "inputTokensDetails",
                    "prompt_tokens_details",
                    "promptTokensDetails",
                ],
                dictionary: dictionary
            ),
            nonCachedInputTokens: int64Value(
                for: [
                    "non_cached_input_tokens",
                    "nonCachedInputTokens",
                    "uncached_input_tokens",
                    "uncachedInputTokens",
                ],
                in: dictionary
            ),
            outputTokens: int64Value(
                for: [
                    "output_tokens",
                    "outputTokens",
                    "completion_tokens",
                    "completionTokens",
                ],
                in: dictionary
            ),
            reasoningOutputTokens: int64Value(
                for: [
                    "reasoning_output_tokens",
                    "reasoningOutputTokens",
                    "reasoning_tokens",
                    "reasoningTokens",
                ],
                in: dictionary
            ) ?? nestedInt64Value(
                for: ["reasoning_tokens", "reasoningTokens"],
                in: [
                    "output_tokens_details",
                    "outputTokensDetails",
                    "completion_tokens_details",
                    "completionTokensDetails",
                ],
                dictionary: dictionary
            ),
            totalTokens: int64Value(
                for: [
                    "total_tokens",
                    "totalTokens",
                    "tokens_used",
                    "tokensUsed",
                ],
                in: dictionary
            ),
            estimatedContextTokens: int64Value(
                for: [
                    "estimated_context_tokens",
                    "estimatedContextTokens",
                    "context_tokens",
                    "contextTokens",
                ],
                in: dictionary
            ),
            contextWindowTokens: int64Value(
                for: [
                    "context_window_tokens",
                    "contextWindowTokens",
                    "context_window",
                    "contextWindow",
                    "context_window_capacity",
                    "contextWindowCapacity",
                ],
                in: dictionary
            )
        )
    }

    private func nestedInt64Value(
        for keys: [String],
        in containerKeys: [String],
        dictionary: [String: Any]
    ) -> Int64? {
        for containerKey in containerKeys {
            if let nested = dictionary[containerKey] as? [String: Any],
               let value = int64Value(for: keys, in: nested) {
                return value
            }
        }
        return nil
    }

    private func int64Value(for keys: [String], in dictionary: [String: Any]) -> Int64? {
        for key in keys {
            if let value = dictionary[key],
               let parsed = int64Value(value) {
                return parsed
            }
        }
        return nil
    }

    private func int64Value(_ value: Any) -> Int64? {
        if let int = value as? Int {
            return Int64(int)
        }
        if let int64 = value as? Int64 {
            return int64
        }
        if let number = value as? NSNumber {
            return number.int64Value
        }
        if let string = value as? String {
            return Int64(string)
        }
        return nil
    }
}
