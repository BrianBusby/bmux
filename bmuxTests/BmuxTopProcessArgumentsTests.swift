import Darwin
import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

struct BmuxTopProcessArgumentsTests {
    @Test func testKernProcArgsPreservesEmptyArgumentElements() throws {
        let bytes = kernProcArgs(arguments: ["codex", "", "resume"])

        let process = try #require(BmuxTopProcessSnapshot.processArgumentsAndEnvironment(fromKernProcArgs: bytes))

        #expect(process.arguments == ["codex", "", "resume"])
    }

    private func kernProcArgs(arguments: [String]) -> [UInt8] {
        var argc = Int32(arguments.count).littleEndian
        var bytes = withUnsafeBytes(of: &argc) { Array($0) }
        appendCString("/bin/zsh", to: &bytes)
        bytes.append(0)
        for argument in arguments {
            appendCString(argument, to: &bytes)
        }
        bytes.append(0)
        return bytes
    }

    private func appendCString(_ string: String, to bytes: inout [UInt8]) {
        bytes.append(contentsOf: string.utf8)
        bytes.append(0)
    }
}
