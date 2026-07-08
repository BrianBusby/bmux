import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

struct MobileHostStatusVerificationLimiterTests {
    /// The unauthenticated status verb may trigger Stack network verification
    /// for token-bearing requests, so the lookups it can have in flight are
    /// hard-capped: saturated acquires fail fast (the reply degrades to
    /// identity-free) instead of queueing attacker-minted token lookups, and
    /// a released slot is immediately reusable.
    @Test func capsInFlightLookups() async {
        let limiter = MobileHostStatusVerificationLimiter(limit: 2)

        #expect(await limiter.acquire())
        #expect(await limiter.acquire())
        #expect(!(await limiter.acquire()))

        await limiter.release()
        #expect(await limiter.acquire())
    }
}
