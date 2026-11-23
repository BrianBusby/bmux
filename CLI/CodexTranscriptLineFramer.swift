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
        try data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            var position = 0
            while position < raw.count {
                let newline = memchr(base.advanced(by: position), 0x0a, raw.count - position)
                let end = newline.map { base.distance(to: $0) } ?? raw.count
                let length = end - position
                if !discardingOversizedLine && length > 0 {
                    if maximumLineBytes >= buffer.count && length <= maximumLineBytes - buffer.count {
                        buffer.append(contentsOf: raw[position..<end])
                    } else {
                        buffer.removeAll(keepingCapacity: false)
                        discardingOversizedLine = true
                    }
                }
                guard newline != nil else { break }
                if discardingOversizedLine {
                    try onLine(.oversized, nextLineNumber)
                    discardingOversizedLine = false
                } else if !buffer.isEmpty {
                    try onLine(.bytes(Data(buffer)), nextLineNumber)
                }
                buffer.removeAll(keepingCapacity: true)
                position = end + 1
                // Empty lines have no callback but still advance both cursor fields.
                while position < raw.count && raw[position] == 0x0a { position += 1 }
                nextLineNumber += position - end
                lastCompletedLineOffset = startOffset + UInt64(position)
            }
        }
        fragment = Data(buffer)
    }
}
