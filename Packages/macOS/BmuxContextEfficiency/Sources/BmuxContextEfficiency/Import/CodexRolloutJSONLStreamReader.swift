import Foundation

struct CodexRolloutJSONLStreamReader: Sendable {
    private let chunkSize: Int
    private let parserVersion: Int

    init(chunkSize: Int = 64 * 1024, parserVersion: Int = CodexRolloutTelemetryParser.parserVersion) {
        self.chunkSize = max(1, chunkSize)
        self.parserVersion = parserVersion
    }

    func readLines(
        from url: URL,
        sourcePath: String,
        startingByteOffset: Int64,
        startingLineNumber: Int,
        processLine: (CodexRolloutImportedLine) throws -> Void
    ) throws -> CodexRolloutStreamReadResult {
        guard startingByteOffset >= 0 else {
            throw CodexRolloutStreamReaderError.negativeOffset(startingByteOffset)
        }

        let fileSize = try Self.fileSize(at: url)
        let handle = try FileHandle(forReadingFrom: url)
        defer {
            try? handle.close()
        }
        try handle.seek(toOffset: UInt64(startingByteOffset))

        var buffer = Data()
        var lineStartOffset = startingByteOffset
        var completedLineNumber = startingLineNumber
        var importedLineCount = 0

        while true {
            let chunk = try handle.read(upToCount: chunkSize) ?? Data()
            guard !chunk.isEmpty else {
                break
            }
            buffer.append(chunk)
            try processCompleteLines(
                in: &buffer,
                sourcePath: sourcePath,
                lineStartOffset: &lineStartOffset,
                completedLineNumber: &completedLineNumber,
                importedLineCount: &importedLineCount,
                processLine: processLine
            )
        }

        return CodexRolloutStreamReadResult(
            lineCount: importedLineCount,
            nextByteOffset: lineStartOffset,
            nextLineNumber: completedLineNumber,
            fileSize: fileSize,
            pendingByteCount: buffer.count
        )
    }

    private func processCompleteLines(
        in buffer: inout Data,
        sourcePath: String,
        lineStartOffset: inout Int64,
        completedLineNumber: inout Int,
        importedLineCount: inout Int,
        processLine: (CodexRolloutImportedLine) throws -> Void
    ) throws {
        while let newlineIndex = buffer.firstIndex(of: 10) {
            let consumedByteCount = buffer.distance(from: buffer.startIndex, to: newlineIndex) + 1
            var lineData = Data(buffer[..<newlineIndex])
            if lineData.last == 13 {
                lineData.removeLast()
            }
            guard let text = String(data: lineData, encoding: .utf8) else {
                throw CodexRolloutStreamReaderError.invalidUTF8(
                    sourcePath: sourcePath,
                    byteOffset: lineStartOffset,
                    lineNumber: completedLineNumber + 1
                )
            }

            let sourceReference = ContextEfficiencySourceReference(
                sourcePath: sourcePath,
                byteOffset: lineStartOffset,
                lineNumber: completedLineNumber + 1,
                parserVersion: parserVersion
            )
            try processLine(CodexRolloutImportedLine(text: text, sourceReference: sourceReference))
            importedLineCount += 1
            completedLineNumber += 1
            lineStartOffset += Int64(consumedByteCount)
            buffer.removeSubrange(buffer.startIndex...newlineIndex)
        }
    }

    private static func fileSize(at url: URL) throws -> Int64 {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values.fileSize ?? 0)
    }
}
