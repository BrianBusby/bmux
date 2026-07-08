import Testing
@testable import BmuxMobileCamera

@Suite struct QRCodeScanStreamTests {
    @Test func yieldsCodesInOrderThenFinishes() async {
        let stream = QRCodeScanStream()
        stream.yield("bmux-ios://one")
        stream.yield("bmux-ios://two")
        stream.finish()

        var seen: [String] = []
        for await code in stream.codes {
            seen.append(code)
        }
        #expect(seen == ["bmux-ios://one", "bmux-ios://two"])
    }

    @Test func finishWithoutYieldProducesEmptySequence() async {
        let stream = QRCodeScanStream()
        stream.finish()

        var seen: [String] = []
        for await code in stream.codes {
            seen.append(code)
        }
        #expect(seen.isEmpty)
    }
}
