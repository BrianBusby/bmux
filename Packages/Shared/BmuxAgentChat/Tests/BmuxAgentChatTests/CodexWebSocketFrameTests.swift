import Foundation
import Testing
@testable import BmuxAgentChat

struct CodexWebSocketFrameTests {
    @Test(arguments: [UInt8(0), 1, 2])
    func fragmentsPreservePayloadOpcodeAndFinalBoundary(opcode: UInt8) throws {
        let payload = Data((0..<1031).map { UInt8($0 % 251) })
        let mask: [UInt8] = [17, 31, 47, 63]
        let header = Data([0x80 | opcode, 0x80 | 126, 4, 7] + mask)
        let frame = try CodexWebSocketFrame(header: header)
        var restored = Data()
        var offset = 0
        while offset < payload.count {
            let count = min(257, payload.count - offset)
            let chunk = Data((0..<count).map { payload[offset + $0] ^ mask[(offset + $0) % 4] })
            let newMask: [UInt8] = [7, 13, 23, 41]
            let encoded = frame.fragment(payload: chunk, offset: offset, newMask: newMask)
            let headerSize = count < 126 ? 6 : 8
            let fragment = try CodexWebSocketFrame(header: Data(encoded.prefix(headerSize)))
            #expect(fragment.opcode == (offset == 0 ? opcode : 0))
            #expect(fragment.final == (offset + count == payload.count))
            #expect(fragment.length == count)
            restored.append(contentsOf: encoded.dropFirst(headerSize).enumerated().map { $0.element ^ newMask[$0.offset % 4] })
            offset += count
        }
        #expect(restored == payload)
    }

    @Test func alreadyFragmentedInputDoesNotEndMessageEarly() throws {
        let frame = try CodexWebSocketFrame(header: Data([1, 0x80 | 126, 4, 0, 1, 2, 3, 4]))
        let bytes = frame.fragment(payload: Data(repeating: 0, count: 512), offset: 512, newMask: [4, 3, 2, 1])
        #expect(bytes[0] == 0)
    }

    @Test(arguments: [
        [UInt8(0x81), 0, 0, 0, 0, 0], // unmasked
        [0xc1, 0x80, 0, 0, 0, 0], // compression/unknown extension
        [0x89, 0xfe, 0, 126, 0, 0, 0, 0], // oversized control frame
        [0x09, 0x80, 0, 0, 0, 0], // fragmented control frame
        [0x83, 0x80, 0, 0, 0, 0], // reserved opcode
        [0x81, 0xff, 0x80, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], // overflow
        [0x81, 0xff, 0, 0, 0, 0, 4, 0, 0, 1, 0, 0, 0, 0] // above message budget
    ])
    func rejectsInvalidOrUnboundedFrames(bytes: [UInt8]) {
        #expect(throws: (any Error).self) { try CodexWebSocketFrame(header: Data(bytes)) }
    }

    @Test func acceptsControlFramesWithoutChangingBytes() throws {
        let bytes = Data([0x89, 0x83, 1, 2, 3, 4])
        let frame = try CodexWebSocketFrame(header: bytes)
        #expect(frame.length == 3)
        #expect(frame.opcode == 9)
    }

    @Test func relayCannotRestartAfterStop() async throws {
        let relay = try CodexWebSocketRelay(endpoint: URL(string: "ws://127.0.0.1:1")!)
        let endpoint = try await relay.start()
        #expect(endpoint.host == "127.0.0.1")
        #expect(endpoint.port != 1)
        await relay.stop()
        await relay.stop()
        await #expect(throws: (any Error).self) { try await relay.start() }
    }

    @Test(arguments: ["ws://localhost:1234", "ws://192.0.2.1:1234", "wss://127.0.0.1:1234", "ws://127.0.0.1:0", "ws://127.0.0.1:1234/path"])
    func relayRejectsNonLoopbackOrUnsupportedEndpoints(endpoint: String) {
        #expect(throws: (any Error).self) { try CodexWebSocketRelay(endpoint: URL(string: endpoint)!) }
    }
}
