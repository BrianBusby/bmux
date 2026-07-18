import Foundation

struct ContextEfficiencyWorkItemReferenceExtractor: Sendable {
    private let maxStringCharacters: Int
    private let maxScannedStrings: Int

    init(maxStringCharacters: Int = 20_000, maxScannedStrings: Int = 80) {
        self.maxStringCharacters = max(128, maxStringCharacters)
        self.maxScannedStrings = max(8, maxScannedStrings)
    }

    func references(
        in object: [String: Any],
        sourceKind: ContextEfficiencyWorkItemReferenceSource,
        sourcePath: String,
        sourceReference: ContextEfficiencySourceReference?,
        observedAt: Date?
    ) -> [CodexRolloutParsedWorkItemReference] {
        var strings: [ScannedString] = []
        collectStrings(in: object, inheritedKey: nil, into: &strings)

        var references: [CodexRolloutParsedWorkItemReference] = []
        var seen = Set<String>()
        for scanned in strings.prefix(maxScannedStrings) {
            appendURLReferences(
                in: scanned.value,
                sourceKind: sourceKind,
                sourcePath: sourcePath,
                sourceReference: sourceReference,
                observedAt: observedAt,
                references: &references,
                seen: &seen
            )
            appendTicketReferences(
                in: scanned.value,
                sourceKind: sourceKind,
                sourcePath: sourcePath,
                sourceReference: sourceReference,
                observedAt: observedAt,
                confidence: isBranchKey(scanned.key) ? .branchCandidate : .explicitReference,
                references: &references,
                seen: &seen
            )
            if isBranchKey(scanned.key) {
                appendBranchReference(
                    scanned.value,
                    sourceKind: sourceKind,
                    sourcePath: sourcePath,
                    sourceReference: sourceReference,
                    observedAt: observedAt,
                    references: &references,
                    seen: &seen
                )
            }
            if isRepositoryKey(scanned.key) {
                appendRepositoryReference(
                    in: scanned.value,
                    sourceKind: sourceKind,
                    sourcePath: sourcePath,
                    sourceReference: sourceReference,
                    observedAt: observedAt,
                    references: &references,
                    seen: &seen
                )
            }
        }
        return references
    }

    func references(
        from metadata: CodexStateThreadMetadata,
        sourcePath: String
    ) -> [CodexRolloutParsedWorkItemReference] {
        var object: [String: Any] = [:]
        object["git_branch"] = metadata.gitBranch
        object["git_origin_url"] = metadata.gitOriginURL
        object["title"] = metadata.title
        object["preview"] = metadata.preview
        object["first_user_message"] = metadata.firstUserMessage
        return references(
            in: object.compactMapValues { $0 },
            sourceKind: .codexStateMetadata,
            sourcePath: sourcePath,
            sourceReference: nil,
            observedAt: metadata.updatedAt ?? metadata.createdAt
        )
    }

    private func collectStrings(in value: Any, inheritedKey: String?, into strings: inout [ScannedString]) {
        guard strings.count < maxScannedStrings else { return }
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            strings.append(ScannedString(key: inheritedKey, value: bounded(trimmed)))
            return
        }
        if let dictionary = value as? [String: Any] {
            for key in dictionary.keys.sorted() {
                collectStrings(in: dictionary[key] as Any, inheritedKey: key, into: &strings)
                guard strings.count < maxScannedStrings else { return }
            }
            return
        }
        if let array = value as? [Any] {
            for element in array {
                collectStrings(in: element, inheritedKey: inheritedKey, into: &strings)
                guard strings.count < maxScannedStrings else { return }
            }
        }
    }

    private func appendURLReferences(
        in text: String,
        sourceKind: ContextEfficiencyWorkItemReferenceSource,
        sourcePath: String,
        sourceReference: ContextEfficiencySourceReference?,
        observedAt: Date?,
        references: inout [CodexRolloutParsedWorkItemReference],
        seen: inout Set<String>
    ) {
        for match in githubURLMatches(in: text, resource: "pull") {
            append(
                CodexRolloutParsedWorkItemReference(
                    kind: .pullRequest,
                    reference: "github:\(match.slug)#\(match.number)",
                    repositorySlug: match.slug,
                    number: match.number,
                    urlString: match.url,
                    branchName: nil,
                    ticketKey: nil,
                    sourceKind: sourceKind,
                    confidence: .explicitReference,
                    sourcePath: sourcePath,
                    sourceReference: sourceReference,
                    observedAt: observedAt
                ),
                references: &references,
                seen: &seen
            )
        }
        for match in githubURLMatches(in: text, resource: "issues") {
            append(
                CodexRolloutParsedWorkItemReference(
                    kind: .issue,
                    reference: "github-issue:\(match.slug)#\(match.number)",
                    repositorySlug: match.slug,
                    number: match.number,
                    urlString: match.url,
                    branchName: nil,
                    ticketKey: nil,
                    sourceKind: sourceKind,
                    confidence: .explicitReference,
                    sourcePath: sourcePath,
                    sourceReference: sourceReference,
                    observedAt: observedAt
                ),
                references: &references,
                seen: &seen
            )
        }
    }

    private func appendTicketReferences(
        in text: String,
        sourceKind: ContextEfficiencyWorkItemReferenceSource,
        sourcePath: String,
        sourceReference: ContextEfficiencySourceReference?,
        observedAt: Date?,
        confidence: ContextEfficiencyWorkItemReferenceConfidence,
        references: inout [CodexRolloutParsedWorkItemReference],
        seen: inout Set<String>
    ) {
        for ticket in ticketKeys(in: text) {
            append(
                CodexRolloutParsedWorkItemReference(
                    kind: .ticket,
                    reference: "ticket:\(ticket)",
                    repositorySlug: nil,
                    number: nil,
                    urlString: nil,
                    branchName: nil,
                    ticketKey: ticket,
                    sourceKind: sourceKind,
                    confidence: confidence,
                    sourcePath: sourcePath,
                    sourceReference: sourceReference,
                    observedAt: observedAt
                ),
                references: &references,
                seen: &seen
            )
        }
    }

    private func appendBranchReference(
        _ rawBranch: String,
        sourceKind: ContextEfficiencyWorkItemReferenceSource,
        sourcePath: String,
        sourceReference: ContextEfficiencySourceReference?,
        observedAt: Date?,
        references: inout [CodexRolloutParsedWorkItemReference],
        seen: inout Set<String>
    ) {
        let branch = rawBranch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isPlausibleBranchName(branch) else { return }
        append(
            CodexRolloutParsedWorkItemReference(
                kind: .branch,
                reference: "branch:\(branch)",
                repositorySlug: nil,
                number: nil,
                urlString: nil,
                branchName: branch,
                ticketKey: nil,
                sourceKind: sourceKind,
                confidence: .branchCandidate,
                sourcePath: sourcePath,
                sourceReference: sourceReference,
                observedAt: observedAt
            ),
            references: &references,
            seen: &seen
        )
    }

    private func appendRepositoryReference(
        in text: String,
        sourceKind: ContextEfficiencyWorkItemReferenceSource,
        sourcePath: String,
        sourceReference: ContextEfficiencySourceReference?,
        observedAt: Date?,
        references: inout [CodexRolloutParsedWorkItemReference],
        seen: inout Set<String>
    ) {
        guard let slug = githubRepositorySlug(in: text) else { return }
        append(
            CodexRolloutParsedWorkItemReference(
                kind: .repository,
                reference: "github-repo:\(slug)",
                repositorySlug: slug,
                number: nil,
                urlString: nil,
                branchName: nil,
                ticketKey: nil,
                sourceKind: sourceKind,
                confidence: sourceKind == .codexStateMetadata || sourceKind == .threadMetadata ? .metadata : .explicitReference,
                sourcePath: sourcePath,
                sourceReference: sourceReference,
                observedAt: observedAt
            ),
            references: &references,
            seen: &seen
        )
    }

    private func append(
        _ reference: CodexRolloutParsedWorkItemReference,
        references: inout [CodexRolloutParsedWorkItemReference],
        seen: inout Set<String>
    ) {
        let key = [
            reference.kind.rawValue,
            reference.reference,
            reference.sourceKind.rawValue,
            reference.sourceReference.map { "\($0.sourcePath):\($0.lineNumber):\($0.byteOffset)" } ?? reference.sourcePath,
        ].joined(separator: "|")
        guard seen.insert(key).inserted else { return }
        references.append(reference)
    }

    private func githubURLMatches(in text: String, resource: String) -> [(slug: String, number: Int, url: String)] {
        let pattern = #"https?://github\.com/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)/\#(resource)/([0-9]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let ownerRange = Range(match.range(at: 1), in: text),
                  let repoRange = Range(match.range(at: 2), in: text),
                  let numberRange = Range(match.range(at: 3), in: text),
                  let urlRange = Range(match.range(at: 0), in: text),
                  let number = Int(text[numberRange]) else {
                return nil
            }
            return (
                slug: "\(text[ownerRange])/\(text[repoRange])",
                number: number,
                url: String(text[urlRange])
            )
        }
    }

    private func ticketKeys(in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"\b[A-Z][A-Z0-9]{1,9}-[0-9]+\b"#) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            Range(match.range(at: 0), in: text).map { String(text[$0]) }
        }
    }

    private func githubRepositorySlug(in text: String) -> String? {
        let patterns = [
            #"github\.com[:/]([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+?)(?:\.git)?(?:[\s"']|$)"#,
            #"^([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)$"#,
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let match = regex.firstMatch(in: text, range: range),
                  let ownerRange = Range(match.range(at: 1), in: text),
                  let repoRange = Range(match.range(at: 2), in: text) else {
                continue
            }
            var repo = String(text[repoRange])
            if repo.hasSuffix(".git") {
                repo.removeLast(4)
            }
            return "\(text[ownerRange])/\(repo)"
        }
        return nil
    }

    private func isBranchKey(_ key: String?) -> Bool {
        guard let key = key?.lowercased() else { return false }
        return key == "git_branch"
            || key == "branch"
            || key == "headrefname"
            || key == "head_ref_name"
            || key == "headbranch"
            || key == "head_branch"
    }

    private func isRepositoryKey(_ key: String?) -> Bool {
        guard let key = key?.lowercased() else { return false }
        return key == "git_origin_url"
            || key == "origin"
            || key == "remote"
            || key == "remote_url"
            || key == "repository"
            || key == "repo"
            || key == "slug"
    }

    private func isPlausibleBranchName(_ branch: String) -> Bool {
        guard !branch.isEmpty, branch.count <= 180 else {
            return false
        }
        if branch == "main" || branch == "master" {
            return false
        }
        return branch.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
    }

    private func bounded(_ value: String) -> String {
        guard value.count > maxStringCharacters else {
            return value
        }
        let endIndex = value.index(value.startIndex, offsetBy: maxStringCharacters)
        return String(value[..<endIndex])
    }

    private struct ScannedString {
        var key: String?
        var value: String
    }
}
