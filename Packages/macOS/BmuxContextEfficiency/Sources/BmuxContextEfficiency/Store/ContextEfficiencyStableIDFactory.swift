import Foundation

struct ContextEfficiencyStableIDFactory: Sendable {
    func normalizedThreadID(_ externalID: String) -> String {
        if externalID.hasPrefix("codex:") {
            return externalID
        }
        return "codex:\(externalID)"
    }

    func recordID(kind: String, sourceReference: ContextEfficiencySourceReference) -> String {
        "\(kind):\(hash(sourceReference.sourcePath)):\(sourceReference.byteOffset):\(sourceReference.lineNumber)"
    }

    func artifactID(sourcePath: String) -> String {
        "artifact:codex-rollout:\(hash(sourcePath))"
    }

    private func hash(_ value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(format: "%016llx", hash)
    }
}
