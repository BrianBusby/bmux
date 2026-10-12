import Foundation
import Testing

@Suite
final class BundledCLILinkageTests {
    @Test
    func bundledCLIRunsWithItsShippedDependencyClosure() throws {
        let cliURL = try BundledCLITestSupport.bundledCLIURL(for: Self.self)
        let appURL = cliURL.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let verifierURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("scripts/verify-bundled-cli.py")
        let process = Process()
        let outputPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", verifierURL.path, appURL.path]
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        try process.run()
        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0, "\(String(decoding: output, as: UTF8.self))")
    }
}
