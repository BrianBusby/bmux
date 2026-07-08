import Foundation

struct CommandOutputReferenceFactory: Sendable {
    func reference(messageID: String, command: String, rawOutput: String) -> String {
        let hash = Self.hash("\(command)\u{0}\(rawOutput)")
        return "terminal-output:\(messageID):\(String(format: "%016llx", hash))"
    }

    private static func hash(_ value: String) -> UInt64 {
        var result: UInt64 = 0xcbf29ce484222325
        for byte in value.utf8 {
            result ^= UInt64(byte)
            result = result &* 0x100000001b3
        }
        return result
    }
}
