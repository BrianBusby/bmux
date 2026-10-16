import Testing
@testable import BmuxRemoteSession

// Both cases scope the same two bootstrap environment flags. CI already runs this package one suite per process.
@Suite("Persistent PTY daemon capability reinstall", .serialized)
struct RemoteDaemonBootstrapContractTests {
    @Test("An existing daemon missing PTY capabilities is reacquired and uploaded")
    func missingPersistentPTYCapabilitiesReinstallsDaemon() async throws {
        let fixture = try RemoteDaemonBootstrapFixture(timeout: .seconds(2))
        // Throwing completion retains the original successful two-second semaphore outcome.
        let result = try await fixture.run(advertisesRequiredCapabilities: false)
        let upload = try #require(result.events.compactMap { event -> (destination: String, source: String)? in
            guard case let .upload(destination, source) = event else { return nil }
            return (destination, source)
        }.first)
        #expect(upload.destination.hasPrefix("test@hpc.example:/home/test/.bmux/bin/bmuxd-remote/"))
        #expect(upload.source == fixture.cachedBinary.path)
        #expect(result.events == [.probe, .hello, .createDirectory, .upload(destination: upload.destination, source: upload.source)])
        #expect(result.errorCode == 31, "The original intentional SCP failure ends the owned bootstrap attempt")
    }

    @Test("An existing daemon advertising every required capability is not uploaded again")
    func completePersistentPTYCapabilitiesAvoidReinstall() async throws {
        let fixture = try RemoteDaemonBootstrapFixture(timeout: .seconds(2))
        let result = try await fixture.run(advertisesRequiredCapabilities: true)
        #expect(result.events == [.probe, .hello])
        #expect(result.errorCode == nil)
    }
}
