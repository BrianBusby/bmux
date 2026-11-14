import Foundation

/// Frames newline-terminated bytes without interpreting or acknowledging them.
struct CodexTranscriptLineFramer {
    enum Line {
        case bytes(Data)
        case oversized
    }

    let maximumLineBytes: Int
    var fragment = Data()
    var discardingOversizedLine = false
    var nextLineNumber = 1
    var lastCompletedLineOffset: UInt64 = 0

    /// If `onLine` throws, discard this framer because its state may be partially advanced.
    mutating func append(
        _ data: Data,
        startOffset: UInt64,
        onLine: (Line, Int) throws -> Void
    ) rethrows {
        var buffer = [UInt8](fragment)
        for (index, byte) in data.enumerated() {
            if byte == 0x0a {
                if discardingOversizedLine {
                    try onLine(.oversized, nextLineNumber)
                    discardingOversizedLine = false
                } else if !buffer.isEmpty {
                    try onLine(.bytes(Data(buffer)), nextLineNumber)
                }
                buffer.removeAll(keepingCapacity: true)
                nextLineNumber += 1
                lastCompletedLineOffset = startOffset + UInt64(index + 1)
            } else if !discardingOversizedLine {
                if buffer.count < maximumLineBytes {
                    buffer.append(byte)
                } else {
                    buffer.removeAll(keepingCapacity: false)
                    discardingOversizedLine = true
                }
            }
        }
        fragment = Data(buffer)
    }
}
