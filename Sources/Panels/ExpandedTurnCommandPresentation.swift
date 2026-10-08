import Foundation

/// Immutable presentation cached per original command, without executing shell syntax.
struct ExpandedTurnCommandPresentation: Equatable {
    let raw: String
    let category: ExpandedTurnCommandCategory
    let preview: String
    let target: String?
    let isProxy: Bool

    init(raw: String) {
        self.raw = raw
        guard let operation = ExpandedTurnShellTokenizer().firstOperation(raw), let first = operation.words.first else {
            category = .other
            preview = Self.short(raw)
            target = nil
            isProxy = false
            return
        }
        let executable = (first as NSString).lastPathComponent
        let args = Array(operation.words.dropFirst())
        isProxy = executable == "bmux" && args.first == "agent-token-proxy"
        category = Self.classify(executable, args: args)
        if isProxy {
            // This is explicitly a preview even when the recorded payload is short.
            preview = "bmux agent-token-proxy --command-hex …"
        } else if executable == "git", let verb = args.first, !verb.hasPrefix("-") {
            preview = Self.short("git \(verb)")
        } else {
            preview = Self.short(operation.source)
        }
        if ["cat", "head", "tail"].contains(executable), args.count == 1,
           let path = args.first, !path.hasPrefix("-"), !path.contains(where: { "*?[]~".contains($0) }) {
            target = path
        } else {
            target = nil
        }
    }

    private static func classify(_ name: String, args: [String]) -> ExpandedTurnCommandCategory {
        switch name {
        case "git": return .git
        case "rg", "grep", "cat", "head", "tail", "ls", "pwd", "wc", "less": return .read
        case "sed":
            if args.contains(where: { $0 == "--in-place" || $0.hasPrefix("--in-place=") || ($0.hasPrefix("-") && !$0.hasPrefix("--") && $0.contains("i")) }) { return .edit }
            // Only recognize the common print-only form; sed can also write files.
            if args.count == 3, args[0] == "-n", !args[2].hasPrefix("-"), args[1].range(of: #"^\d+(,\d+)?p$"#, options: .regularExpression) != nil { return .read }
            return .other
        case "apply_patch", "patch", "touch", "mkdir", "rm", "mv", "cp": return .edit
        case "xcodebuild", "make", "cmake", "ctest", "pytest": return .build
        case "swift": return ["test", "build"].contains(args.first ?? "") ? .build : .other
        case "bun", "npm", "yarn":
            let verb = args.first == "run" ? args.dropFirst().first : args.first
            return ["test", "build", "typecheck", "lint"].contains(verb ?? "") ? .build : .other
        case "reload.sh", "reloadp.sh", "reloads.sh", "reload2.sh", "test-unit.sh", "run-tests-v1.sh", "run-tests-v2.sh", "check-pbxproj.sh", "project-docs": return .build
        case "bmux", "bmux-debug-cli.sh": return .bmux
        default: return .other
        }
    }

    private static func short(_ raw: String) -> String {
        let line = raw.prefix(160).split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init) ?? raw
        return line.count > 80 ? String(line.prefix(79)) + "…" : line
    }
}
