import Foundation

// Auto-naming engine: pure, dependency-injected logic for naming workspaces
// and tabs from agent conversation content. This file is compiled into both
// the bundled CLI target (which drives it from agent hooks) and the cmux-unit
// test target (the CLI is a tool target that tests cannot import), so it must
// not reference CLI-private symbols.

/// Tunable constants for the auto-naming engine. Defaults follow the
/// debounce shape proven by community prior art (manaflow-ai/cmux#2043)
/// and are expected to be tuned from dogfood feedback.
struct AutoNamingConfig: Sendable {
    /// Minimum transcript line growth since the last naming before another
    /// summarization call is considered.
    var minLineGrowth: Int = 12
    /// Minimum seconds between summarization calls for one session.
    var minInterval: TimeInterval = 300
    /// Transcripts shorter than this are skipped entirely (subagent or
    /// trivial sessions).
    var minTranscriptLines: Int = 12
    /// Hard deadline for the summarizer subprocess.
    var llmTimeout: TimeInterval = 60
    /// Extra slack on top of `llmTimeout` before an in-flight marker is
    /// considered stale: covers the termination grace window and the socket
    /// apply, so a pass still finishing cannot be doubled by a concurrent
    /// Stop, while a crashed pass cannot block naming forever.
    var inFlightExpiryGrace: TimeInterval = 15

    /// Total lifetime of an in-flight marker before a new pass may start.
    var inFlightExpiry: TimeInterval { llmTimeout + inFlightExpiryGrace }
    /// Minimum title words after sanitization.
    var minTitleWordCount: Int = 6
    /// Maximum title words after sanitization.
    var maxTitleWordCount: Int = 20
    /// Maximum title length after sanitization, kept as a UI safety cap after
    /// the primary word-count cap.
    var maxTitleLength: Int = 180
    /// Per-message truncation applied to context excerpts.
    var contextMessageMaxChars: Int = 240
}

/// Projection of one session's persisted auto-naming state, read from the
/// agent hook session store under its lock.
struct AutoNamingSessionSnapshot: Sendable {
    var lastTitle: String?
    var lastLineCount: Int?
    var lastNamedAt: TimeInterval?
    var inFlightAt: TimeInterval?
    /// Last attempt time, success or failure (see the record field of the same
    /// purpose). Drives the failure cooldown in ``throttleDecision``.
    var lastAttemptAt: TimeInterval?

    init(
        lastTitle: String? = nil,
        lastLineCount: Int? = nil,
        lastNamedAt: TimeInterval? = nil,
        inFlightAt: TimeInterval? = nil,
        lastAttemptAt: TimeInterval? = nil
    ) {
        self.lastTitle = lastTitle
        self.lastLineCount = lastLineCount
        self.lastNamedAt = lastNamedAt
        self.inFlightAt = inFlightAt
        self.lastAttemptAt = lastAttemptAt
    }
}

/// Outcome of the throttle evaluation that gates a summarization call.
enum AutoNamingThrottleDecision: Equatable, Sendable {
    /// Run the summarizer; on success the baseline advances to this count.
    case proceed(baseline: Int)
    /// The transcript shrank (compaction or resume rewrite): record the new
    /// baseline without naming so future growth measures from it.
    case reseedBaseline(to: Int)
    case skipShortTranscript
    case skipInFlight
    case skipTooSoon
    case skipInsufficientGrowth
}

enum AutoNamingSanitizedTitle: Equatable, Sendable {
    case changed(String)
    case unchanged(String)
}

/// One user/assistant text message extracted from a transcript.
struct AutoNamingTranscriptMessage: Codable, Equatable, Sendable {
    var role: String
    var text: String
}

/// Environment policy for the summarizer subprocess: scrub the variables
/// that would recurse into cmux hooks or the parent agent session while
/// preserving backend selection (Vertex/Bedrock/Anthropic) so the call works
/// for users on any auth path.
struct AutoNamingEnvironmentPolicy: Sendable {
    /// Exact variables marking a live agent session or cmux terminal; never pass them to the summarizer.
    private static let scrubbedExactKeys: Set<String> = [
        "CLAUDECODE",
        "CLAUDE_CODE", "CLAUDE_CODE_CHILD_SESSION",
        "CLAUDE_CODE_ENTRYPOINT", "CLAUDE_CODE_PARENT_SESSION_ID",
        "CLAUDE_CODE_SESSION_ID",
        "CLAUDE_CODE_EXECPATH",
        "CLAUDE_CODE_SSE_PORT",
        "NODE_OPTIONS"
    ]

    func summarizerEnvironment(from env: [String: String]) -> [String: String] {
        env.filter { key, _ in
            if key.hasPrefix("CMUX_") { return false }
            if Self.scrubbedExactKeys.contains(key) { return false }
            return true
        }
    }

    /// Minimal environment for tool-disabled Codex summarization. Keep auth
    /// discovery and proxy settings, but do not forward other agent/provider
    /// credentials into a process that receives untrusted transcript text.
    func codexSummarizerEnvironment(from env: [String: String]) -> [String: String] {
        let selected = summarizerEnvironment(from: env)
        let allowedExactKeys: Set<String> = [
            "HOME",
            "PATH",
            "TMPDIR",
            "TMP",
            "TEMP",
            "USER",
            "LOGNAME",
            "SHELL",
            "CODEX_HOME",
            "OPENAI_API_KEY",
            "OPENAI_BASE_URL",
            "OPENAI_ORG_ID",
            "OPENAI_ORGANIZATION",
            "SSL_CERT_FILE",
            "SSL_CERT_DIR",
            "HTTP_PROXY",
            "HTTPS_PROXY",
            "ALL_PROXY",
            "NO_PROXY"
        ]
        return selected.filter { key, _ in
            allowedExactKeys.contains(key)
        }
    }

    /// The model passed to `claude -p`. Honors the user's small/fast model
    /// override so Vertex/Bedrock deployments are not broken by a hardcoded
    /// Anthropic alias.
    func claudeModel(from env: [String: String]) -> String {
        let override = env["ANTHROPIC_SMALL_FAST_MODEL"]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return override.isEmpty ? "haiku" : override
    }
}

/// Pure auto-naming logic: throttle decisions, transcript extraction,
/// prompt construction, and response sanitization.
struct AutoNamingEngine: Sendable {
    var config: AutoNamingConfig

    init(config: AutoNamingConfig = AutoNamingConfig()) {
        self.config = config
    }

    // MARK: - Throttle

    func throttleDecision(
        snapshot: AutoNamingSessionSnapshot,
        transcriptLineCount: Int,
        now: Date
    ) -> AutoNamingThrottleDecision {
        guard transcriptLineCount >= config.minTranscriptLines else {
            return .skipShortTranscript
        }
        let nowInterval = now.timeIntervalSince1970
        if let inFlightAt = snapshot.inFlightAt, nowInterval - inFlightAt < config.inFlightExpiry {
            return .skipInFlight
        }
        guard let lastLineCount = snapshot.lastLineCount, snapshot.lastNamedAt != nil else {
            // First naming for this session always qualifies; this also seeds
            // the baseline for resumed sessions arriving with a large
            // pre-existing transcript. A failed pass records only lastAttemptAt
            // (not lastNamedAt), so honor the cooldown here too — otherwise a
            // persistently failing summarizer respawns on every turn end.
            if let lastAttemptAt = snapshot.lastAttemptAt, nowInterval - lastAttemptAt < config.minInterval {
                return .skipTooSoon
            }
            return .proceed(baseline: transcriptLineCount)
        }
        if transcriptLineCount < lastLineCount {
            return .reseedBaseline(to: transcriptLineCount)
        }
        // Cooldown anchors on the last attempt (success or failure), so a
        // session that named once and now keeps failing also backs off.
        if let cooldownAnchor = snapshot.lastAttemptAt ?? snapshot.lastNamedAt,
           nowInterval - cooldownAnchor < config.minInterval {
            return .skipTooSoon
        }
        if transcriptLineCount - lastLineCount < config.minLineGrowth {
            return .skipInsufficientGrowth
        }
        return .proceed(baseline: transcriptLineCount)
    }

    // MARK: - Transcript extraction (Claude Code JSONL)

    /// Extracts user/assistant text messages from Claude Code transcript
    /// JSONL lines. Tool results, thinking blocks, and non-text content are
    /// skipped; unparseable lines are ignored.
    func extractMessages(fromTranscriptLines lines: [String]) -> [AutoNamingTranscriptMessage] {
        var messages: [AutoNamingTranscriptMessage] = []
        for line in lines {
            guard let data = line.data(using: .utf8),
                  let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                continue
            }
            guard let role = object["type"] as? String, role == "user" || role == "assistant" else {
                continue
            }
            guard let message = object["message"] as? [String: Any] else { continue }
            var text = ""
            if let content = message["content"] as? String {
                text = content
            } else if let content = message["content"] as? [[String: Any]] {
                text = content.compactMap { item -> String? in
                    guard item["type"] as? String == "text" else { return nil }
                    return item["text"] as? String
                }.joined(separator: "\n")
            }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            messages.append(AutoNamingTranscriptMessage(role: role, text: trimmed))
        }
        return messages
    }

    /// Builds the summarization context from the whole extracted conversation.
    func buildContext(from messages: [AutoNamingTranscriptMessage]) -> String? {
        guard !messages.isEmpty else { return nil }
        var seen = Set<String>()
        var parts: [String] = []
        for message in messages {
            let excerpt = String(message.text.prefix(config.contextMessageMaxChars))
            let key = "\(message.role):\(excerpt)"
            guard seen.insert(key).inserted else { continue }
            parts.append("\(message.role): \(excerpt)")
        }
        let context = parts.joined(separator: "\n")
        return context.isEmpty ? nil : context
    }

    // MARK: - Transcript extraction (Codex rollout JSONL)

    /// Extracts user/assistant text messages from Codex rollout JSONL lines
    /// (`response_item` payloads of type `message`). Injected context blocks
    /// (environment context, user instructions, subagent notifications) are
    /// skipped along with tool calls and event noise.
    func extractCodexMessages(fromRolloutLines lines: [String]) -> [AutoNamingTranscriptMessage] {
        var messages: [AutoNamingTranscriptMessage] = []
        for line in lines {
            guard let data = line.data(using: .utf8),
                  let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  object["type"] as? String == "response_item",
                  let payload = object["payload"] as? [String: Any],
                  payload["type"] as? String == "message",
                  let role = payload["role"] as? String, role == "user" || role == "assistant" else {
                continue
            }
            var text = ""
            if let content = payload["content"] as? String {
                text = content
            } else if let content = payload["content"] as? [[String: Any]] {
                text = content.compactMap { block -> String? in
                    (block["text"] as? String) ?? (block["input_text"] as? String)
                }.joined(separator: "\n")
            }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            // Codex injects framework context as user messages wrapped in
            // angle-bracket tags; they describe the harness, not the topic.
            if trimmed.hasPrefix("<"), trimmed.contains(">") { continue }
            messages.append(AutoNamingTranscriptMessage(role: role, text: trimmed))
        }
        return messages
    }

    // MARK: - Transcript extraction (Grok chat_history JSONL)

    /// Extracts user/assistant text messages from Grok's native
    /// `chat_history.jsonl` records. Injected metadata tags are removed from
    /// user messages, with `<user_query>` preferred when present.
    func extractGrokMessages(fromChatHistoryLines lines: [String]) -> [AutoNamingTranscriptMessage] {
        var messages: [AutoNamingTranscriptMessage] = []
        for line in lines {
            guard let data = line.data(using: .utf8),
                  let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                continue
            }
            guard let role = firstString(in: object, keys: ["role", "type"])?.lowercased(),
                  role == "user" || role == "assistant" else {
                continue
            }
            let rawText = firstText(in: object, keys: ["content", "text", "message"])
            let text = role == "user" ? grokUserText(rawText) : rawText
            guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !trimmed.isEmpty else {
                continue
            }
            messages.append(AutoNamingTranscriptMessage(role: role, text: trimmed))
        }
        return messages
    }

    // MARK: - Transcript extraction (generic hook payload cache)

    /// Extracts conversation messages from generic hook payloads that carry
    /// prompt/assistant context. Agents without these fields simply yield no
    /// messages and are skipped by the caller.
    func extractHookMessages(fromPayloadObjects objects: [[String: Any]]) -> [AutoNamingTranscriptMessage] {
        var messages: [AutoNamingTranscriptMessage] = []
        for object in objects {
            appendHookMessage(role: "user", text: hookUserText(in: object), to: &messages)
            appendHookMessage(role: "assistant", text: hookAssistantText(in: object), to: &messages)

            for key in ["context", "notification", "data", "extra"] {
                guard let nested = object[key] as? [String: Any] else { continue }
                appendHookMessage(role: "user", text: hookUserText(in: nested), to: &messages)
                appendHookMessage(role: "assistant", text: hookAssistantText(in: nested), to: &messages)
            }
        }
        return messages
    }

    /// Converts hook-message progress into the line-growth unit used by the
    /// shared throttle. `totalMessageCount` is monotonic even when the recent
    /// message cache is capped, so long-running hook adapters can keep naming
    /// after the cache reaches its retention limit.
    func hookMessageLineEquivalentCount(
        _ messages: [AutoNamingTranscriptMessage],
        totalMessageCount: Int? = nil
    ) -> Int {
        let count = max(messages.count, totalMessageCount ?? 0)
        return count * config.minLineGrowth
    }

    // MARK: - Prompt and response

    func buildPrompt(currentTitle: String?, context: String) -> String {
        var lines: [String] = [
            "You name terminal workspace tabs for a developer running coding agents.",
            "Given the whole conversation excerpt, output ONLY an informative subject statement, between 6 and 20 words, that summarizes the current task being worked on.",
            "Evaluate the entire conversation before choosing the title; do not summarize only the latest prompt when earlier messages establish the actual task.",
            "The title should read like a normal sentence fragment a person would write, not a bag of keywords.",
            "Write a natural, human-readable grammatical phrase in the same language as the conversation.",
            "Never output fewer than 6 words.",
            "Prefer concrete nouns from the work: feature, bug, ticket, repo, file, workflow, or decision.",
            "Do not emit title-case keyword fragments or generic category labels.",
            "Do not rename just because wording could be slightly improved; change only when the main subject has meaningfully changed.",
            "Avoid filler words such as \"now\", \"seeing\", \"trying\", or \"working on\".",
            "Bad: Now Seeing Trying",
            "Bad: Look Ticket Determine",
            "Bad: Look failing test pr summary all failing tests",
            "Bad: Three Dot Here",
            "Bad: Workspace Automation",
            "Good: Improving workspace tab summaries",
            "Good: Creating CompanyCam API branch and PR for ticket",
            "Good: Debugging Vite startup failures",
            ""
        ]
        let pullRequestReferences = githubPullRequestReferences(in: context)
        if !pullRequestReferences.isEmpty {
            lines.append("Important pull requests mentioned: \(pullRequestReferences.joined(separator: ", "))")
            lines.append("When a pull request is central to the task, include the repository and PR number in the title.")
            lines.append("Do not turn PR URLs into URL fragment titles such as \"PR Https Github\"; convert URLs into the pull request's repo and number.")
            lines.append("Good: Address PR #1234 CompanyCam API review")
            lines.append("")
        }
        if let currentTitle, !currentTitle.isEmpty {
            lines.append("The current title is: \(currentTitle)")
            if titleWordCount(currentTitle) >= config.minTitleWordCount {
                lines.append("If that still accurately describes the conversation's main topic and is at least 6 words, output it EXACTLY as given.")
            } else {
                lines.append("The current title is shorter than 6 words, so do not output it exactly; replace it with a 6- to 20-word title.")
            }
            lines.append("")
        }
        lines.append("Conversation excerpt:")
        lines.append(context)
        return lines.joined(separator: "\n")
    }

    private func githubPullRequestReferences(in text: String) -> [String] {
        let pattern = #"https?://github\.com/([^/\s]+)/([^/\s]+)/pull/([0-9]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let nsText = text as NSString
        var seen = Set<String>()
        var references: [String] = []

        for match in regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)) {
            guard match.numberOfRanges == 4 else { continue }
            let owner = nsText.substring(with: match.range(at: 1))
            let repo = nsText.substring(with: match.range(at: 2))
            let number = nsText.substring(with: match.range(at: 3))
            let reference = "\(owner)/\(repo) PR #\(number)"
            guard seen.insert(reference.lowercased()).inserted else { continue }
            references.append(reference)
        }

        return references
    }

    /// Normalizes a summarizer response into a usable title, or `nil` when
    /// the response is unusable or matches the current title (no rename
    /// needed). Takes the first non-empty line, strips wrapping quotes,
    /// collapses whitespace, and enforces the length cap at a word boundary.
    func sanitizeResponse(_ raw: String?, currentTitle: String?) -> String? {
        guard case .changed(let title) = sanitizeResponseOutcome(raw, currentTitle: currentTitle) else {
            return nil
        }
        return title
    }

    func sanitizeResponseOutcome(_ raw: String?, currentTitle: String?) -> AutoNamingSanitizedTitle? {
        guard let raw else { return nil }
        guard let firstLine = raw
            .components(separatedBy: .newlines)
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty }) else {
            return nil
        }
        var title = firstLine
        while title.count >= 2,
              let first = title.first, let last = title.last,
              (first == "\"" && last == "\"") || (first == "'" && last == "'") ||
              (first == "\u{201C}" && last == "\u{201D}") {
            title = String(title.dropFirst().dropLast())
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        title = title
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !title.isEmpty else { return nil }
        let words = titleWords(title)
        guard words.count >= config.minTitleWordCount else { return nil }
        if words.count > config.maxTitleWordCount {
            title = words.prefix(config.maxTitleWordCount).joined(separator: " ")
        }
        if title.count > config.maxTitleLength {
            let prefix = String(title.prefix(config.maxTitleLength))
            if let lastSpace = prefix.lastIndex(of: " "), prefix.distance(from: prefix.startIndex, to: lastSpace) > 0 {
                title = String(prefix[..<lastSpace])
            } else {
                title = prefix
            }
            title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !title.isEmpty else { return nil }
        guard titleWordCount(title) >= config.minTitleWordCount else { return nil }
        if let currentTitle,
           normalizedTitleIdentity(title) == normalizedTitleIdentity(currentTitle) {
            return .unchanged(currentTitle.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return .changed(title)
    }

    private func titleWords(_ title: String) -> [Substring] {
        title.split(separator: " ")
    }

    private func titleWordCount(_ title: String) -> Int {
        titleWords(
            title
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        ).count
    }

    private func normalizedTitleIdentity(_ title: String) -> String {
        title
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private func appendHookMessage(
        role: String,
        text: String?,
        to messages: inout [AutoNamingTranscriptMessage]
    ) {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return
        }
        if messages.last == AutoNamingTranscriptMessage(role: role, text: text) {
            return
        }
        messages.append(AutoNamingTranscriptMessage(role: role, text: text))
    }

    private func hookUserText(in object: [String: Any]) -> String? {
        firstText(in: object, keys: [
            "lastUserMessage",
            "last_user_message",
            "userPrompt",
            "user_prompt",
            "user_message",
            "userMessage",
            "prompt"
        ])
    }

    private func hookAssistantText(in object: [String: Any]) -> String? {
        firstText(in: object, keys: [
            "assistantPreamble",
            "assistant_preamble",
            "last_assistant_message",
            "lastAssistantMessage",
            "assistant_response",
            "assistantResponse"
        ])
    }

    private func grokUserText(_ value: String?) -> String? {
        guard let value else { return nil }
        if let userQuery = taggedContent(named: "user_query", in: value) {
            return userQuery
        }
        let withoutMetadata = ["user_info", "git_status", "system-reminder"].reduce(value) { partial, tag in
            removingTaggedContent(named: tag, from: partial)
        }
        return withoutMetadata.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func taggedContent(named tag: String, in text: String) -> String? {
        let openTag = "<\(tag)>"
        let closeTag = "</\(tag)>"
        guard let openRange = text.range(of: openTag) else { return nil }
        let bodyStart = openRange.upperBound
        guard let closeRange = text[bodyStart...].range(of: closeTag) else { return nil }
        let body = String(text[bodyStart..<closeRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return body.isEmpty ? nil : body
    }

    private func removingTaggedContent(named tag: String, from text: String) -> String {
        let openTag = "<\(tag)>"
        let closeTag = "</\(tag)>"
        var result = text
        while let openRange = result.range(of: openTag) {
            let bodyStart = openRange.upperBound
            guard let closeRange = result[bodyStart...].range(of: closeTag) else { break }
            result.removeSubrange(openRange.lowerBound..<closeRange.upperBound)
        }
        return result
    }

    private func firstString(in object: [String: Any], keys: [String]) -> String? {
        for key in keys {
            guard let value = object[key] as? String else { continue }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return nil
    }

    private func firstText(in object: [String: Any], keys: [String]) -> String? {
        for key in keys {
            guard let text = firstTextValue(object[key]) else { continue }
            return text
        }
        return nil
    }

    private func firstTextValue(_ value: Any?) -> String? {
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let values = value as? [Any] {
            let parts = values.compactMap(firstTextBlock)
            let joined = parts.joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return joined.isEmpty ? nil : joined
        }
        if let block = value as? [String: Any] {
            return firstTextBlock(block)
        }
        return nil
    }

    private func firstTextBlock(_ value: Any) -> String? {
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        guard let block = value as? [String: Any] else { return nil }
        if let type = firstString(in: block, keys: ["type"]),
           type.caseInsensitiveCompare("text") != .orderedSame,
           type.caseInsensitiveCompare("input_text") != .orderedSame,
           type.caseInsensitiveCompare("output_text") != .orderedSame {
            return nil
        }
        return firstString(in: block, keys: ["text", "input_text", "content"])
    }
}
