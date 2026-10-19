import Testing
@testable import BmuxCore

@Suite
struct RemotePTYFailureTests {
    @Test(arguments: RemotePTYFailure.allCases)
    func canonicalProtocolValuesSurviveRepeatedClassification(_ failure: RemotePTYFailure) {
        #expect(RemotePTYFailure(sanitizing: failure.rawValue) == failure)
        #expect(RemotePTYFailure(sanitizing: "remote_pty_error: " + failure.rawValue) == failure)
        #expect(RemotePTYFailure(sanitizing: " \n" + failure.rawValue.uppercased() + "\t") == failure)
    }

    @Test(arguments: [
        ("missing required capability: pty.list", RemotePTYFailure.unsupportedDaemon),
        ("pty.session.create failed", .unsupportedDaemon),
        ("method_not_found", .unsupportedDaemon),
        ("pty_session_not_found", .sessionNotRunning),
        ("persistent SSH PTY session is not running", .sessionNotRunning),
        ("persistent PTY session is not running", .sessionNotRunning),
        ("pty_input_queue_full", .inputBackedUp),
        ("PTY input queue is full", .inputBackedUp),
        ("remote connection is not active (detail)", .connectionInactive),
        ("remote daemon tunnel is not ready", .daemonNotReady),
        ("missing workspace_id in SSH PTY session list response (detail)", .missingWorkspaceID),
        ("missing session_id in SSH PTY session list response (detail)", .missingSessionID),
        ("request timed out", .timedOut),
        ("timeout", .timedOut),
        ("", .operationFailed),
        ("  \n", .operationFailed),
        ("secret token at /Users/person/private", .operationFailed),
        ("could not allocate a remote PTY: private device info", .operationFailed),
        ("pty.write.notification unsupported", .operationFailed),
        ("pty.resize.notification unsupported", .operationFailed),
    ])
    func rawDetailsAreClassifiedWithoutExpandingAppDisclosure(input: String, expected: RemotePTYFailure) {
        let failure = RemotePTYFailure(sanitizing: input)
        #expect(failure == expected)
        #expect(RemotePTYFailure(sanitizing: failure.rawValue) == expected)
    }
}
