import BMUXMobileCore
import BmuxAuthRuntime
import Foundation

/// Registers this Mac (and its running bmux app instance's attach routes) in the
/// team-scoped device registry (`POST /api/devices`), so a phone can look up the
/// Mac's current routes on reload and auto-pair instead of re-scanning a QR.
///
/// Event-driven: it observes ``MobileHostService/statusUpdates()`` and registers
/// whenever the advertised route set changes (e.g. the Mac moved networks or
/// rebound to a different port), which is exactly the freshness the phone needs.
/// Gating falls out of the routes: ``MobileHostService`` advertises no routes
/// until the user has enabled mobile pairing, so an empty route set is never
/// registered. There is no separate opt-in flag — the registry is core to the
/// pairing the user already turned on, not a distinct privacy surface.
///
/// Best-effort and non-blocking, mirroring ``PhonePushClient``: a registry
/// outage never disturbs the Mac, and pairing still works through the phone's
/// locally stored routes.
@MainActor
final class DeviceRegistryClient {
    static let shared = DeviceRegistryClient()

    private let session: URLSession = .shared
    private var auth: AuthCoordinator?
    private var observeTask: Task<Void, Never>?
    private var registrationTail: Task<Void, Never>?
    private var registrationQueueSequence: UInt64 = 0
    private var registrationGeneration: UInt64 = 0
    /// The scope (team + tag + routes) most recently registered, used to skip
    /// redundant POSTs. Keyed on the full scope rather than routes alone so an
    /// account/team switch with unchanged routes still re-registers in the newly
    /// selected team instead of being deduped away.
    private var lastRegistration: Registration?

    /// The identity of a registration POST, for deduplication.
    struct Registration: Equatable {
        var teamID: String?
        var tag: String
        var routes: [CmxAttachRoute]
    }

    private init() {}

    /// Compatibility wrapper for older composition-root callers.
    ///
    /// Removal condition: delete after all production startup goes through
    /// `MobileHostRuntimeService.start(...)` and no tests call this directly.
    func configure(auth: AuthCoordinator) {
        start(auth: auth)
    }

    /// Inject the auth dependency and begin observing host-route changes. Call
    /// from the mobile-host runtime owner.
    func start(auth: AuthCoordinator) {
        self.auth = auth
        if observeTask == nil {
            registrationGeneration &+= 1
        }
        startObserving()
    }

    /// Stop route observation and clear per-run dedupe state.
    func stop(publishingFinalRoutes finalRoutes: [CmxAttachRoute]? = nil) {
        let finalAuth = auth
        let previousRegistration = lastRegistration
        observeTask?.cancel()
        observeTask = nil
        auth = nil
        lastRegistration = nil
        registrationGeneration &+= 1
        guard let finalRoutes, let finalAuth else { return }
        enqueueFinalRegistration(
            routes: finalRoutes,
            auth: finalAuth,
            previousRegistration: previousRegistration
        )
    }

    /// Whether a registration with `current` scope differs from what was last
    /// registered, and therefore should be POSTed.
    ///
    /// Pure so it is unit-testable without any network or host service.
    ///
    /// Fires (returns `true`) when the team, tag, or routes differ from the last
    /// registration. The team is part of the key so an account/team switch with
    /// unchanged routes still registers in the new team. The routes-empty
    /// transition (the user turned mobile pairing off) also fires once, so the
    /// registry stops advertising stale routes; the phone already skips
    /// empty-route instances. An unchanged scope (a connection-only
    /// `statusUpdates()` tick) and the never-registered empty start (`nil`
    /// previous with empty routes) are both no-ops, so the off-state is published
    /// exactly once rather than on every empty tick.
    nonisolated static func shouldReRegister(
        previous: Registration?,
        current: Registration
    ) -> Bool {
        // Treat "never registered" as an empty-routes baseline in the same scope
        // so an initial empty set (pairing off at launch) is a no-op, but a later
        // clear, or any team/tag change, still fires.
        let baseline = previous ?? Registration(teamID: current.teamID, tag: current.tag, routes: [])
        return baseline != current
    }

    private func startObserving() {
        guard observeTask == nil else { return }
        // Registration is currently driven only by host-route changes. The dedup
        // key includes the team, so a team switch *does* re-register once the
        // next status tick arrives, but a mid-session team switch with otherwise
        // unchanged routes is not registered in the new team until then. Known
        // limitation; an explicit auth/team-change trigger is a follow-up.
        let generation = registrationGeneration
        observeTask = Task { @MainActor [weak self] in
            for await status in MobileHostService.shared.statusUpdates() {
                if Task.isCancelled { break }
                self?.enqueueCurrentRegistration(routes: status.routes, generation: generation)
            }
        }
    }

    private func enqueueCurrentRegistration(routes: [CmxAttachRoute], generation: UInt64) {
        enqueueRegistration { [weak self, routes, generation] in
            await self?.registerIfRoutesChanged(routes: routes, generation: generation)
        }
    }

    private func enqueueFinalRegistration(
        routes: [CmxAttachRoute],
        auth: AuthCoordinator,
        previousRegistration: Registration?
    ) {
        enqueueRegistration { [weak self, routes, auth, previousRegistration] in
            await self?.registerIfRoutesChanged(
                routes: routes,
                auth: auth,
                previousRegistration: previousRegistration,
                recordsSuccess: false,
                forcesRegistration: true,
                generation: nil
            )
        }
    }

    private func enqueueRegistration(_ operation: @escaping @MainActor @Sendable () async -> Void) {
        let previous = registrationTail
        registrationQueueSequence &+= 1
        let sequence = registrationQueueSequence
        registrationTail = Task { @MainActor [weak self] in
            await previous?.value
            if Task.isCancelled { return }
            await operation()
            if self?.registrationQueueSequence == sequence {
                self?.registrationTail = nil
            }
        }
    }

    private func registerIfRoutesChanged(routes: [CmxAttachRoute], generation: UInt64) async {
        guard let auth else { return }
        await registerIfRoutesChanged(
            routes: routes,
            auth: auth,
            previousRegistration: lastRegistration,
            recordsSuccess: true,
            forcesRegistration: false,
            generation: generation
        )
    }

    private func registerIfRoutesChanged(
        routes: [CmxAttachRoute],
        auth: AuthCoordinator,
        previousRegistration: Registration?,
        recordsSuccess: Bool,
        forcesRegistration: Bool,
        generation: UInt64?
    ) async {
        // Await tokens FIRST: this both gates on "signed in" and waits for launch
        // auth bootstrap. `resolvedTeamID` is derived from `availableTeams`, which
        // is empty until bootstrap completes, so reading the team before this
        // await could resolve nil even when the user has a persisted selected team
        // and publish the Mac into the wrong (Stack-default) team. After bootstrap
        // `currentTokens()` returns the cached token, so awaiting it per tick is
        // cheap.
        let tokens: (accessToken: String, refreshToken: String)
        do {
            tokens = try await auth.currentTokens()
        } catch {
            return // not signed in → nothing to do
        }
        // Resolve the team AFTER bootstrap, and use that same scope for both the
        // dedup decision and the request header, so a team switch with unchanged
        // routes is detected and the POST targets the intended team.
        let teamID = auth.resolvedTeamID
        let tag = Self.buildTag()
        let registration = Registration(teamID: teamID, tag: tag, routes: routes)
        guard forcesRegistration || Self.shouldReRegister(previous: previousRegistration, current: registration) else {
            return
        }

        guard var comps = URLComponents(url: AuthEnvironment.vmAPIBaseURL, resolvingAgainstBaseURL: false) else {
            return
        }
        comps.path = (comps.path.hasSuffix("/") ? String(comps.path.dropLast()) : comps.path) + "/api/devices"
        guard let url = comps.url else { return }

        var bodyDict: [String: Any] = [
            "deviceId": MobileHostIdentity.deviceID(),
            "platform": "mac",
            "tag": tag,
            "routes": routes.map(\.mobileHostJSONObject),
        ]
        if let displayName = MobileHostIdentity.displayName(), !displayName.isEmpty {
            bodyDict["displayName"] = displayName
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 10
        req.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue(tokens.refreshToken, forHTTPHeaderField: "X-Stack-Refresh-Token")
        if let teamID, !teamID.isEmpty {
            req.setValue(teamID, forHTTPHeaderField: "X-Bmux-Team-Id")
        }
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: bodyDict, options: [])

        do {
            let (_, response) = try await session.data(for: req)
            if let http = response as? HTTPURLResponse {
                if (200...299).contains(http.statusCode) {
                    // Only remember the scope once the server accepted it, so a
                    // transient failure retries on the next status tick.
                    if recordsSuccess, generation == registrationGeneration {
                        lastRegistration = registration
                    }
                } else {
                    NSLog("bmux.deviceRegistry register failed status=%d", http.statusCode)
                }
            }
        } catch {
            // best-effort; registry must never disrupt the Mac.
        }
    }

    /// The build tag for this bmux instance, distinguishing dev/tagged builds
    /// from stable. Defaults to "default" so untagged stable builds register
    /// under a stable instance key.
    private static func buildTag() -> String {
        let tag = ProcessInfo.processInfo.environment["BMUX_TAG"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (tag?.isEmpty == false) ? tag! : "default"
    }

    #if DEBUG
    func debugResetForTesting() {
        observeTask?.cancel()
        observeTask = nil
        auth = nil
        lastRegistration = nil
        registrationTail?.cancel()
        registrationTail = nil
        registrationQueueSequence &+= 1
        registrationGeneration = 0
    }

    func debugEnqueueRegistrationForTesting(_ operation: @escaping @MainActor @Sendable () async -> Void) {
        enqueueRegistration(operation)
    }

    func debugWaitForRegistrationQueueForTesting() async {
        await registrationTail?.value
    }
    #endif
}
