import Foundation

struct CommandOutputOptimizer: Sendable {
    private let pathLimit = 6
    private let searchLineLimit = 5
    private let typescriptErrorLimitPerFile = 4
    private let testFailureLineLimit = 80
    private let testFailureHeadLineLimit = 3
    private let testFailureTailLineLimit = 12
    private let buildOutputLineLimit = 80
    private let buildOutputHeadLineLimit = 3
    private let buildOutputTailLineLimit = 12

    func optimize(
        command: String,
        output: String,
        exitCode: Int?
    ) -> CommandOutputOptimization {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCommand.isEmpty, !trimmedOutput.isEmpty else {
            return CommandOutputOptimization(
                kind: .generic,
                text: output,
                wasOptimized: false
            )
        }

        if isGitStatus(trimmedCommand),
           let optimized = optimizeGitStatus(trimmedOutput) {
            return optimized
        }
        if isTestCommand(trimmedCommand),
           let optimized = optimizeTestOutput(trimmedOutput, exitCode: exitCode) {
            return optimized
        }
        if isTypeScriptCommand(trimmedCommand),
           let optimized = optimizeTypeScriptOutput(trimmedOutput) {
            return optimized
        }
        if isPackageInstallCommand(trimmedCommand),
           let optimized = optimizePackageInstallOutput(trimmedOutput) {
            return optimized
        }
        if isBuildCommand(trimmedCommand),
           let optimized = optimizeBuildOutput(trimmedOutput, exitCode: exitCode) {
            return optimized
        }
        if isSearchCommand(trimmedCommand),
           let optimized = optimizeSearchOutput(trimmedOutput) {
            return optimized
        }
        return CommandOutputOptimization(
            kind: .generic,
            text: output,
            wasOptimized: false
        )
    }

    private func isGitStatus(_ command: String) -> Bool {
        command.hasPrefix("git status")
    }

    private func isTestCommand(_ command: String) -> Bool {
        let lowercased = command.lowercased()
        return lowercased.contains(" test")
            || lowercased.hasSuffix(" test")
            || lowercased.contains("swift test")
            || lowercased.contains("xcodebuild test")
            || lowercased.contains("rspec")
            || lowercased.contains("vitest")
            || lowercased.contains("jest")
    }

    private func isTypeScriptCommand(_ command: String) -> Bool {
        let lowercased = command.lowercased()
        return lowercased.contains("tsc")
            || lowercased.contains("typescript")
            || lowercased.contains("typecheck")
            || lowercased.contains("types:check")
    }

    private func isSearchCommand(_ command: String) -> Bool {
        let name = command.split(separator: " ").first.map(String.init) ?? ""
        return ["rg", "grep", "find", "tree"].contains(name)
            || command.hasPrefix("ls -R")
    }

    private func isPackageInstallCommand(_ command: String) -> Bool {
        let lowercased = command.lowercased()
        return lowercased == "npm install"
            || lowercased.hasPrefix("npm install ")
            || lowercased == "yarn install"
            || lowercased.hasPrefix("yarn install ")
            || lowercased == "bun install"
            || lowercased.hasPrefix("bun install ")
            || lowercased == "pnpm install"
            || lowercased.hasPrefix("pnpm install ")
            || lowercased == "bundle install"
            || lowercased.hasPrefix("bundle install ")
            || lowercased == "pod install"
            || lowercased.hasPrefix("pod install ")
    }

    private func isBuildCommand(_ command: String) -> Bool {
        let lowercased = command.lowercased()
        if lowercased.contains("swift build")
            || lowercased.contains("swift package build")
            || lowercased.contains("xcodebuild build")
            || (lowercased.contains("xcodebuild") && lowercased.contains(" build"))
            || lowercased.contains("cargo build")
            || lowercased.contains("go build")
            || lowercased.contains("npm run build")
            || lowercased.contains("yarn build")
            || lowercased.contains("bun run build")
            || lowercased.contains("pnpm build") {
            return true
        }
        return false
    }

    private func optimizeGitStatus(_ output: String) -> CommandOutputOptimization? {
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var branch: String?
        var section: GitStatusSection?
        var staged = 0
        var unstaged = 0
        var untracked = 0
        var paths: [String] = []

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("On branch ") {
                branch = String(line.dropFirst("On branch ".count))
                continue
            }
            switch line {
            case "Changes to be committed:":
                section = .staged
                continue
            case "Changes not staged for commit:":
                section = .unstaged
                continue
            case "Untracked files:":
                section = .untracked
                continue
            default:
                break
            }
            guard let section,
                  let path = gitStatusPath(from: line) else {
                continue
            }
            switch section {
            case .staged: staged += 1
            case .unstaged: unstaged += 1
            case .untracked: untracked += 1
            }
            paths.append(path)
        }

        let changedCount = staged + unstaged + untracked
        guard branch != nil || changedCount > 0 else { return nil }
        var summary: [String] = ["git status summary"]
        if let branch {
            summary.append("branch: \(branch)")
        }
        summary.append("staged: \(staged)")
        summary.append("unstaged: \(unstaged)")
        summary.append("untracked: \(untracked)")
        if !paths.isEmpty {
            summary.append("changed files:")
            summary.append(contentsOf: paths.prefix(pathLimit).map { "- \($0)" })
            let omitted = max(0, paths.count - pathLimit)
            if omitted > 0 {
                summary.append("\(omitted) additional \(omitted == 1 ? "file" : "files") omitted")
            }
            return CommandOutputOptimization(
                kind: .git,
                text: summary.joined(separator: "\n"),
                wasOptimized: true,
                omittedLineCount: omitted
            )
        }
        return CommandOutputOptimization(
            kind: .git,
            text: summary.joined(separator: "\n"),
            wasOptimized: true
        )
    }

    private func gitStatusPath(from line: String) -> String? {
        guard !line.isEmpty,
              !line.hasPrefix("("),
              !line.hasPrefix("use "),
              !line.hasPrefix("no changes") else {
            return nil
        }
        if let colon = line.firstIndex(of: ":") {
            let suffix = line[line.index(after: colon)...]
                .trimmingCharacters(in: .whitespaces)
            return suffix.isEmpty ? nil : suffix
        }
        return line.contains("/") || line.contains(".") ? line : nil
    }

    private func optimizeTestOutput(_ output: String, exitCode: Int?) -> CommandOutputOptimization? {
        if let exitCode, exitCode != 0 {
            return optimizeFailedTestOutput(output, exitCode: exitCode)
        }
        let patterns: [Regex<(Substring, Substring, Substring, Substring)>] = [
            /Executed\s+(\d+)\s+tests?,\s+with\s+(\d+)\s+failures?.*?in\s+([0-9.]+)\s+seconds/,
            /(\d+)\s+tests?\s+passed.*?(\d+)\s+failed.*?Elapsed:\s+([0-9.]+)s/,
        ]
        for pattern in patterns {
            guard let match = output.firstMatch(of: pattern) else { continue }
            let passed = String(match.1)
            let failed = String(match.2)
            let elapsed = String(match.3)
            guard failed == "0" else { return nil }
            return CommandOutputOptimization(
                kind: .tests,
                text: "OK: \(passed) tests passed, \(failed) failed. Elapsed: \(elapsed)s",
                wasOptimized: true
            )
        }
        return nil
    }

    private func optimizeFailedTestOutput(_ output: String, exitCode: Int) -> CommandOutputOptimization? {
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.count > testFailureLineLimit || output.utf8.count > 8_000 else {
            return nil
        }

        var selected = Set<Int>()
        func include(_ index: Int) {
            guard lines.indices.contains(index) else { return }
            selected.insert(index)
        }

        var includedHead = 0
        for index in lines.indices {
            guard includedHead < testFailureHeadLineLimit else { break }
            guard !lines[index].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            include(index)
            includedHead += 1
        }

        for index in lines.indices where testFailureLineShouldBeKept(lines[index]) {
            include(index - 1)
            include(index)
            include(index + 1)
        }

        var includedTail = 0
        for index in lines.indices.reversed() {
            guard includedTail < testFailureTailLineLimit else { break }
            guard !lines[index].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            include(index)
            includedTail += 1
        }

        let ordered = selected.sorted()
        guard ordered.count < lines.count else { return nil }
        let kept = Array(ordered.prefix(testFailureLineLimit))
        let selectedOmitted = max(0, ordered.count - kept.count)
        let rawOmitted = max(0, lines.count - kept.count)

        var summary = [
            "test failure summary",
            "exit code: \(exitCode)",
            "raw lines: \(lines.count)",
            "selected diagnostics:"
        ]
        summary.append(contentsOf: kept.map { index in
            "[line \(index + 1)] \(lines[index])"
        })
        if selectedOmitted > 0 {
            summary.append("\(selectedOmitted) additional selected diagnostic \(selectedOmitted == 1 ? "line" : "lines") omitted")
        }
        summary.append("\(rawOmitted) raw output \(rawOmitted == 1 ? "line" : "lines") omitted")

        return CommandOutputOptimization(
            kind: .tests,
            text: summary.joined(separator: "\n"),
            wasOptimized: true,
            omittedLineCount: rawOmitted
        )
    }

    private func testFailureLineShouldBeKept(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let lowercased = trimmed.lowercased()
        if lowercased.contains("error:")
            || lowercased.contains(" failure")
            || lowercased.contains(" failed")
            || lowercased.hasPrefix("fail ")
            || lowercased.hasPrefix("fail:")
            || lowercased.hasPrefix("failures:")
            || lowercased.contains("xctassert")
            || lowercased.contains("assertion failed")
            || lowercased.contains("expectation failed")
            || lowercased.contains("expected")
            || lowercased.contains("received")
            || lowercased.contains("actual")
            || lowercased.hasPrefix("diff")
            || lowercased.hasPrefix("\u{25cf}") {
            return true
        }
        return trimmed.firstMatch(of: /(?:^|\s)[A-Za-z0-9_\/\.\-]+\.(?:swift|tsx?|jsx?|rb):\d+(?::\d+)?/) != nil
    }

    private func optimizeTypeScriptOutput(_ output: String) -> CommandOutputOptimization? {
        var grouped: [String: [String]] = [:]
        var orderedFiles: [String] = []
        var seen = Set<String>()
        for line in output.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            guard let diagnostic = TypeScriptDiagnostic(line: line) else { continue }
            let key = "\(diagnostic.file)\u{1f}\(diagnostic.code)\u{1f}\(diagnostic.message)"
            guard seen.insert(key).inserted else { continue }
            if grouped[diagnostic.file] == nil {
                orderedFiles.append(diagnostic.file)
                grouped[diagnostic.file] = []
            }
            grouped[diagnostic.file]?.append("\(diagnostic.location): \(diagnostic.code): \(diagnostic.message)")
        }
        guard !orderedFiles.isEmpty else { return nil }
        var lines = ["TypeScript errors by file"]
        for file in orderedFiles {
            lines.append(file)
            let diagnostics = grouped[file] ?? []
            lines.append(contentsOf: diagnostics.prefix(typescriptErrorLimitPerFile).map { "  - \($0)" })
            let omitted = max(0, diagnostics.count - typescriptErrorLimitPerFile)
            if omitted > 0 {
                lines.append("  - \(omitted) additional errors omitted")
            }
        }
        return CommandOutputOptimization(
            kind: .typescript,
            text: lines.joined(separator: "\n"),
            wasOptimized: true,
            omittedLineCount: max(0, output.split(separator: "\n").count - lines.count)
        )
    }

    private func optimizePackageInstallOutput(_ output: String) -> CommandOutputOptimization? {
        let lines = output
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return nil }

        var kept: [String] = []
        var omitted = 0
        for line in lines {
            if packageInstallLineIsProgress(line) {
                omitted += 1
                continue
            }
            if packageInstallLineShouldBeKept(line) {
                kept.append(line)
            } else {
                omitted += 1
            }
        }
        guard !kept.isEmpty, omitted > 0 else { return nil }
        var summary = ["package install summary"]
        summary.append(contentsOf: kept)
        summary.append("\(omitted) progress/detail \(omitted == 1 ? "line" : "lines") omitted")
        return CommandOutputOptimization(
            kind: .packageInstall,
            text: summary.joined(separator: "\n"),
            wasOptimized: true,
            omittedLineCount: omitted
        )
    }

    private func packageInstallLineIsProgress(_ line: String) -> Bool {
        if line.firstMatch(of: /\d+(?:\.\d+)?\s*(?:KB|MB|GB)\/\d+(?:\.\d+)?\s*(?:KB|MB|GB)/) != nil {
            return true
        }
        let lowercased = line.lowercased()
        return lowercased.hasPrefix("downloading ")
            || lowercased.hasPrefix("resolving ")
            || lowercased.hasPrefix("fetching ")
            || lowercased.hasPrefix("linking ")
            || lowercased.hasPrefix("building fresh packages")
    }

    private func packageInstallLineShouldBeKept(_ line: String) -> Bool {
        let lowercased = line.lowercased()
        return lowercased.contains("warning")
            || lowercased.contains("error")
            || lowercased.contains("deprecated")
            || lowercased.contains("vulnerabil")
            || lowercased.contains("added ")
            || lowercased.contains("removed ")
            || lowercased.contains("changed ")
            || lowercased.contains("audited ")
            || lowercased.contains("installed")
            || lowercased.contains("done")
    }

    private func optimizeBuildOutput(_ output: String, exitCode: Int?) -> CommandOutputOptimization? {
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.count > buildOutputLineLimit || output.utf8.count > 8_000 else {
            return nil
        }

        var selected = Set<Int>()
        func include(_ index: Int) {
            guard lines.indices.contains(index) else { return }
            selected.insert(index)
        }

        var includedHead = 0
        for index in lines.indices {
            guard includedHead < buildOutputHeadLineLimit else { break }
            guard !lines[index].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            include(index)
            includedHead += 1
        }

        var seenDiagnosticIdentities = Set<String>()
        var duplicateDiagnosticLineIndexes = Set<Int>()
        for index in lines.indices where buildOutputLineShouldBeKept(lines[index]) {
            if let identity = buildOutputDiagnosticIdentity(lines[index]),
               !seenDiagnosticIdentities.insert(identity).inserted {
                duplicateDiagnosticLineIndexes.insert(index)
                continue
            }
            include(index - 1)
            include(index)
            include(index + 1)
        }

        var includedTail = 0
        for index in lines.indices.reversed() {
            guard includedTail < buildOutputTailLineLimit else { break }
            guard !lines[index].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            include(index)
            includedTail += 1
        }

        let ordered = selected.sorted()
        guard ordered.count < lines.count || !duplicateDiagnosticLineIndexes.isEmpty else { return nil }
        let kept = Array(ordered.prefix(buildOutputLineLimit))
        let selectedOmitted = max(0, ordered.count - kept.count)
        var selectedSummaryLines: [String] = []
        selectedSummaryLines.reserveCapacity(kept.count)
        for index in kept {
            guard !duplicateDiagnosticLineIndexes.contains(index) else { continue }
            selectedSummaryLines.append("[line \(index + 1)] \(lines[index])")
        }
        let rawOmitted = max(0, lines.count - selectedSummaryLines.count)

        var summary = ["build output summary"]
        if let exitCode {
            summary.append("exit code: \(exitCode)")
        }
        summary.append("raw lines: \(lines.count)")
        summary.append("selected diagnostics:")
        summary.append(contentsOf: selectedSummaryLines)
        if selectedOmitted > 0 {
            summary.append("\(selectedOmitted) additional selected diagnostic \(selectedOmitted == 1 ? "line" : "lines") omitted")
        }
        let duplicateOmitted = duplicateDiagnosticLineIndexes.count
        if duplicateOmitted > 0 {
            summary.append("\(duplicateOmitted) duplicate diagnostic \(duplicateOmitted == 1 ? "line" : "lines") omitted")
        }
        summary.append("\(rawOmitted) raw output \(rawOmitted == 1 ? "line" : "lines") omitted")

        return CommandOutputOptimization(
            kind: .build,
            text: summary.joined(separator: "\n"),
            wasOptimized: true,
            omittedLineCount: rawOmitted
        )
    }

    private func buildOutputDiagnosticIdentity(_ line: String) -> String? {
        let normalized = line
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacing(/\s+/, with: " ")
        guard !normalized.isEmpty else { return nil }
        let lowercased = normalized.lowercased()
        if lowercased.contains("error:")
            || lowercased.contains("warning:")
            || lowercased.contains("fatal error")
            || lowercased.contains("undefined symbol")
            || lowercased.contains("build failed")
            || lowercased.contains("build succeeded")
            || lowercased.contains("build complete")
            || lowercased.hasPrefix("ld: ")
            || lowercased.hasPrefix("note: referenced by") {
            return lowercased
        }
        if normalized.firstMatch(of: /(?:^|\s)[A-Za-z0-9_\/\.\-]+\.(?:swift|m|mm|c|cc|cpp|cxx|h|hpp|tsx?|jsx?|rb|go|rs):\d+(?::\d+)?/) != nil {
            return lowercased
        }
        return nil
    }

    private func buildOutputLineShouldBeKept(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let lowercased = trimmed.lowercased()
        if lowercased.contains("error:")
            || lowercased.contains("warning:")
            || lowercased.contains("fatal error")
            || lowercased.contains("undefined symbol")
            || lowercased.contains("build failed")
            || lowercased.contains("build succeeded")
            || lowercased.contains("build complete")
            || lowercased.contains("** build failed **")
            || lowercased.contains("** build succeeded **")
            || lowercased.hasPrefix("ld: ")
            || lowercased.hasPrefix("note: referenced by") {
            return true
        }
        return trimmed.firstMatch(of: /(?:^|\s)[A-Za-z0-9_\/\.\-]+\.(?:swift|m|mm|c|cc|cpp|cxx|h|hpp|tsx?|jsx?|rb|go|rs):\d+(?::\d+)?/) != nil
    }

    private func optimizeSearchOutput(_ output: String) -> CommandOutputOptimization? {
        let lines = output
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard lines.count > searchLineLimit else { return nil }
        let omitted = lines.count - searchLineLimit
        var summary = ["search output summary", "\(lines.count) matches"]
        summary.append(contentsOf: lines.prefix(searchLineLimit))
        summary.append("\(omitted) additional \(omitted == 1 ? "match" : "matches") omitted")
        return CommandOutputOptimization(
            kind: .search,
            text: summary.joined(separator: "\n"),
            wasOptimized: true,
            omittedLineCount: omitted
        )
    }

}
