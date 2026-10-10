import Foundation

/// One deliberately promoted provider release, independent of the user's CLI updater.
struct ManagedCodexRelease: Sendable {
    let version: String
    let target: String
    let archiveSHA256: String
    let archiveURL: URL

    var directoryName: String { "\(version)-\(target)" }

    static var validated: ManagedCodexRelease {
#if arch(arm64)
        let target = "aarch64-apple-darwin"
        let digest = "5809ee90a9c3b59d438bb2663aefa0b43d86f825438b65d4504b31f82343628b"
#else
        let target = "x86_64-apple-darwin"
        let digest = "928b421103f339683d0d9f8a648f7b591ae4be907cbd8a5418dda319ff2bbd3c"
#endif
        let version = "0.162.0"
        return ManagedCodexRelease(version: version, target: target, archiveSHA256: digest,
            archiveURL: URL(string: "https://github.com/openai/codex/releases/download/rust-v\(version)/codex-package-\(target).tar.gz")!)
    }
}
