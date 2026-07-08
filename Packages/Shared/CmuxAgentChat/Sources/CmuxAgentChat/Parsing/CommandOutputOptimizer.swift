import Foundation

struct CommandOutputOptimizer: Sendable {
    private let pathLimit = 6
    private let searchLineLimit = 5
    private let typescriptErrorLimitPerFile = 4

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
        guard exitCode == nil || exitCode == 0 else { return nil }
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
