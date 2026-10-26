import Foundation

/// Bounded metadata from the last viewed brief; titles, URLs, and message text are excluded.
public struct WorkBriefBaseline: Codable, Equatable, Sendable {
    /// Schema for persisted fingerprints.
    public static let schemaVersion = 2
    /// Maximum encoded preference record size.
    public static let maxEncodedBytes = 64_000
    /// Time the user last closed a refreshed brief.
    public let capturedAt: Date
    /// Local fingerprints keyed by stable workspace ID.
    public let local: [String: Local]
    /// External fingerprints keyed by provider-qualified ID.
    public let external: [String: External]
    /// Whether every visible local item was captured for new-item comparisons.
    public let completeLocalCoverage: Bool
    /// Provider names whose visible items were all captured for new-item comparisons.
    public let completeExternalSources: [String]
    /// Persisted format version.
    public let version: Int

    /// Minimal local metadata used to detect meaningful changes.
    public struct Local: Codable, Equatable, Sendable {
        /// Verified workspace status at capture time.
        public let status: Int
        /// Exact source ticket identifiers associated with the workspace.
        public let ticketIDs: [String]
        /// Exact source pull-request identifier, when available.
        public let pullRequestID: String?
        /// Source-backed pull-request status, when available.
        public let pullRequestStatus: String?
        /// Time these local facts were last confirmed.
        public let confirmedAt: Date
    }

    /// Minimal external metadata used to detect provider changes.
    public struct External: Codable, Equatable, Sendable {
        /// Provider identifier used to apply source-specific freshness rules.
        public let source: String
        /// Provider-reported status at capture time.
        public let status: String
        /// Work Brief disposition derived from provider facts.
        public let disposition: String
        /// Provider-reported update time.
        public let updatedAt: Date
        /// Time these external facts were last confirmed.
        public let confirmedAt: Date
    }

    /// Captures available sources, retaining a previous fingerprint for an unavailable source.
    /// - Parameters:
    ///   - snapshot: The current bounded source facts.
    ///   - previous: The last saved baseline used when a source is unavailable.
    ///   - now: The capture time used for retention checks.
    public init(snapshot: WorkBriefSnapshot, previous: WorkBriefBaseline?, at now: Date) {
        var local: [String: Local]
        var completeLocalCoverage: Bool
        if snapshot.localHealth.state == .available {
            local = Dictionary(snapshot.localWorkspaces.prefix(100).map {
                ($0.id.uuidString, Self.localFingerprint($0))
            }, uniquingKeysWith: { _, latest in latest })
            completeLocalCoverage = true
        } else {
            local = (previous?.local ?? [:]).filter {
                Self.isRetained($0.value.confirmedAt, at: now)
            }
            completeLocalCoverage = previous?.completeLocalCoverage == true &&
                local.count == previous?.local.count
        }
        var retained = (previous?.external ?? [:]).filter {
            Self.isRetained($0.value.confirmedAt, at: now)
        }
        var completeSources = Set(previous?.completeExternalSources ?? [])
        for (key, value) in previous?.external ?? [:] where retained[key] == nil {
            completeSources.remove(value.source)
        }
        for source in [WorkBriefSource.linear, .github, .slack] {
            guard Self.health(for: source, snapshot: snapshot).state == .available else { continue }
            retained = retained.filter { $0.value.source != source.rawValue }
            for item in snapshot.externalItems.filter({ $0.source == source }).prefix(100) {
                retained[item.id] = Self.externalFingerprint(item)
            }
            completeSources.insert(source.rawValue)
        }
        var external = Dictionary(uniqueKeysWithValues: retained.sorted { $0.key < $1.key }
            .prefix(200).map { ($0.key, $0.value) })
        for (key, value) in retained where external[key] == nil {
            completeSources.remove(value.source)
        }
        let localRemovals: [Removal] = local.map { key, value in
            Removal(key: key, source: "local", bytes: Self.encodedSize(value) + key.utf8.count)
        }
        let externalRemovals: [Removal] = external.map { key, value in
            Removal(key: key, source: value.source, bytes: Self.encodedSize(value) + key.utf8.count)
        }
        let removals = (localRemovals + externalRemovals)
            .sorted { $0.bytes == $1.bytes ? $0.key < $1.key : $0.bytes > $1.bytes }
        var candidate = Self(local: local, external: external, capturedAt: now,
                             completeLocalCoverage: completeLocalCoverage,
                             completeExternalSources: completeSources.sorted())
        var nextRemoval = 0
        while Self.encodedSize(candidate) > Self.maxEncodedBytes && nextRemoval < removals.count {
            for removal in removals[nextRemoval..<min(nextRemoval + 8, removals.count)] {
                if removal.source == "local" {
                    local.removeValue(forKey: removal.key)
                    completeLocalCoverage = false
                } else {
                    external.removeValue(forKey: removal.key)
                    completeSources.remove(removal.source)
                }
            }
            nextRemoval += 8
            candidate = Self(local: local, external: external, capturedAt: now,
                             completeLocalCoverage: completeLocalCoverage,
                             completeExternalSources: completeSources.sorted())
        }
        self = candidate
    }

    /// Reports whether the saved metadata is recent and uses the current schema.
    /// - Parameter now: The time at which to check the baseline.
    /// - Returns: Whether the baseline is valid for comparisons.
    public func valid(at now: Date) -> Bool {
        version == Self.schemaVersion && (0...30 * 24 * 3600).contains(now.timeIntervalSince(capturedAt)) &&
            local.count <= 100 && external.count <= 200 &&
            Self.encodedSize(self) <= Self.maxEncodedBytes
    }

    /// Finds current items newly present or changed since this saved brief.
    /// - Parameter snapshot: The current source snapshot to compare.
    /// - Returns: Bounded IDs of items with verified changes.
    public func changes(in snapshot: WorkBriefSnapshot) -> WorkBriefChanges {
        let localIDs: [UUID] = snapshot.localHealth.state == .available
            ? snapshot.localWorkspaces.filter { item in
                guard let old = local[item.id.uuidString] else { return completeLocalCoverage }
                return !Self.sameMeaning(old, Self.localFingerprint(item))
            }.map(\.id)
            : []
        let externalIDs = snapshot.externalItems.filter { item in
            guard Self.health(for: item.source, snapshot: snapshot).state == .available else { return false }
            guard let old = external[item.id] else {
                return completeExternalSources.contains(item.source.rawValue)
            }
            return !Self.sameMeaning(old, Self.externalFingerprint(item))
        }.map(\.id)
        let coverageLimited = snapshot.localHealth.state == .available && !completeLocalCoverage ||
            [WorkBriefSource.linear, .github, .slack].contains { source in
                Self.health(for: source, snapshot: snapshot).state == .available &&
                    !completeExternalSources.contains(source.rawValue)
            }
        return WorkBriefChanges(since: capturedAt, localIDs: Array(localIDs.prefix(20)),
                                externalIDs: Array(externalIDs.prefix(20)),
                                coverageLimited: coverageLimited)
    }

    private static func localFingerprint(_ item: WorkBriefLocalWorkspace) -> Local {
        Local(status: item.status.rawValue, ticketIDs: item.tickets.map(\.id).sorted(),
              pullRequestID: item.pullRequest?.id, pullRequestStatus: item.pullRequestStatus,
              confirmedAt: item.checkedAt)
    }

    private static func externalFingerprint(_ item: WorkBriefExternalItem) -> External {
        let disposition = switch item.disposition {
        case .needsAttention: "needsAttention"
        case .inProgress: "inProgress"
        case .waitingOn: "waitingOn"
        }
        return External(source: item.source.rawValue, status: item.status,
                        disposition: disposition, updatedAt: item.updatedAt,
                        confirmedAt: item.checkedAt)
    }

    private static func sameMeaning(_ lhs: Local, _ rhs: Local) -> Bool {
        lhs.status == rhs.status && lhs.ticketIDs == rhs.ticketIDs &&
            lhs.pullRequestID == rhs.pullRequestID &&
            lhs.pullRequestStatus == rhs.pullRequestStatus
    }

    private static func sameMeaning(_ lhs: External, _ rhs: External) -> Bool {
        lhs.source == rhs.source && lhs.status == rhs.status &&
            lhs.disposition == rhs.disposition && lhs.updatedAt == rhs.updatedAt
    }

    private static func isRetained(_ confirmedAt: Date, at now: Date) -> Bool {
        (0...30 * 24 * 3600).contains(now.timeIntervalSince(confirmedAt))
    }

    private init(local: [String: Local], external: [String: External], capturedAt: Date,
                 completeLocalCoverage: Bool, completeExternalSources: [String]) {
        version = Self.schemaVersion
        self.capturedAt = capturedAt
        self.local = local
        self.external = external
        self.completeLocalCoverage = completeLocalCoverage
        self.completeExternalSources = completeExternalSources
    }

    private static func encodedSize<T: Encodable>(_ value: T) -> Int {
        (try? JSONEncoder().encode(value).count) ?? Int.max
    }

    private struct Removal {
        let key: String
        let source: String
        let bytes: Int
    }

    private static func health(for source: WorkBriefSource,
                               snapshot: WorkBriefSnapshot) -> WorkBriefSourceHealth {
        switch source {
        case .linear: snapshot.linearHealth
        case .github: snapshot.githubHealth
        case .slack: snapshot.slackHealth
        case .bmux, .provenanceEngine: snapshot.localHealth
        }
    }
}
