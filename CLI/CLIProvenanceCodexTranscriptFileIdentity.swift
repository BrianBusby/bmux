import CryptoKit
import Darwin
import Foundation

/// Metadata used to detect transcript replacement without retaining its contents.
struct CLIProvenanceCodexTranscriptFileIdentity: Codable, Equatable, Sendable {
    let device: UInt64
    let inode: UInt64
    let prefixDigest: String?

    static func inspect(_ url: URL) throws -> (identity: Self, size: UInt64) {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        return try inspect(handle)
    }

    static func inspect(_ handle: FileHandle) throws -> (identity: Self, size: UInt64) {
        var metadata = stat()
        guard fstat(handle.fileDescriptor, &metadata) == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        let size = UInt64(max(metadata.st_size, 0))
        let digest: String?
        if size >= 256 {
            let prefix = try handle.read(upToCount: 256) ?? Data()
            digest = Data(SHA256.hash(data: prefix)).base64EncodedString()
        } else {
            digest = nil
        }
        return (Self(device: UInt64(metadata.st_dev), inode: UInt64(metadata.st_ino),
                     prefixDigest: digest), size)
    }

    func matches(_ other: Self) -> Bool {
        guard device == other.device, inode == other.inode else { return false }
        if let prefixDigest, let otherDigest = other.prefixDigest {
            return prefixDigest == otherDigest
        }
        return true
    }
}
