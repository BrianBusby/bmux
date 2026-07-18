import Foundation

struct CodexRolloutFileIdentity: Sendable {
    func threadID(from url: URL) -> String {
        let basename = url.deletingPathExtension().lastPathComponent
        if basename.hasPrefix("rollout-") {
            return String(basename.dropFirst("rollout-".count))
        }
        return basename
    }
}
