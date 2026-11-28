import Foundation

/// Client frame metadata. Payloads are streamed separately, never accumulated here.
struct CodexWebSocketFrame: Sendable {
    let length: Int
    let mask: [UInt8]
    let opcode: UInt8
    let final: Bool

    init(header: Data) throws {
        let bytes = Array(header)
        guard bytes.count >= 2, bytes[0] & 0x70 == 0, bytes[1] & 0x80 != 0 else {
            throw URLError(.cannotParseResponse)
        }
        let size = bytes[1] & 0x7f
        let extended = size == 127 ? 8 : size == 126 ? 2 : 0
        guard bytes.count == 2 + extended + 4 else { throw URLError(.cannotParseResponse) }
        let length = extended == 0 ? UInt64(size) : bytes[2..<(2 + extended)].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        let opcode = bytes[0] & 0x0f
        let final = bytes[0] & 0x80 != 0
        guard length <= 64 * 1024 * 1024, [0, 1, 2, 8, 9, 10].contains(opcode),
              opcode < 8 || (length <= 125 && final) else { throw URLError(.dataLengthExceedsMaximum) }
        self.length = Int(length)
        self.mask = Array(bytes.suffix(4))
        self.opcode = opcode
        self.final = final
    }

    /// Splits only data frames, preserving message boundaries and masking each
    /// new continuation independently. No JSON or image bytes are interpreted.
    func fragment(payload: Data, offset: Int, newMask: [UInt8]) -> Data {
        let last = offset + payload.count == length
        let flags = (last && final ? UInt8(0x80) : 0) | (offset == 0 ? opcode : 0)
        var result = Data([flags])
        if payload.count < 126 {
            result.append(0x80 | UInt8(payload.count))
        } else if payload.count <= Int(UInt16.max) {
            result.append(0x80 | 126)
            var size = UInt16(payload.count).bigEndian
            withUnsafeBytes(of: &size) { result.append(contentsOf: $0) }
        } else {
            result.append(0x80 | 127)
            var size = UInt64(payload.count).bigEndian
            withUnsafeBytes(of: &size) { result.append(contentsOf: $0) }
        }
        result.append(contentsOf: newMask)
        var remasked = payload
        let key = (0..<4).map { mask[(offset + $0) % 4] ^ newMask[$0] }
        remasked.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) in
            for index in buffer.indices { buffer[index] ^= key[index % 4] }
        }
        result.append(remasked)
        return result
    }
}
