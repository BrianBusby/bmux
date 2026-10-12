import BmuxCore
import Testing
@testable import bmux

@Suite
struct RemotePTYErrorPolicyTests {
    @Test(arguments: RemotePTYFailure.allCases)
    func appRetainsCanonicalProtocolDiagnostics(_ failure: RemotePTYFailure) {
        #expect(v2RemotePTYUserFacingErrorMessage(failure.rawValue) == failure.rawValue)
    }

    @Test(arguments: [
        "could not allocate a remote PTY: /dev/private denied",
        "pty.write.notification unsupported",
        "pty.resize.notification unsupported",
        "arbitrary private token",
    ])
    func appDoesNotAdoptCLIDetailDisclosure(_ message: String) {
        #expect(v2RemotePTYUserFacingErrorMessage(message) == "remote PTY operation failed")
    }
}
