import Testing

import BmuxSettings

@Suite struct SocketControlModeTests {
    @Test func allowAllOpensPermissionsOthersRestrict() {
        #expect(SocketControlMode.allowAll.socketFilePermissions == 0o666)
        for mode in [SocketControlMode.off, .bmuxOnly, .automation, .password] {
            #expect(mode.socketFilePermissions == 0o600)
        }
    }

    @Test func onlyPasswordModeRequiresAuth() {
        #expect(SocketControlMode.password.requiresPasswordAuth)
        for mode in [SocketControlMode.off, .bmuxOnly, .automation, .allowAll] {
            #expect(!mode.requiresPasswordAuth)
        }
    }

    @Test func rawValueIsStable() {
        #expect(SocketControlMode.bmuxOnly.rawValue == "bmuxOnly")
    }
}
