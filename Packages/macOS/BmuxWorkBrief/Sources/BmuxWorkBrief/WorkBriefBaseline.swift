import Foundation

/// Bounded metadata from the last viewed brief; titles, URLs, and message text are excluded.
public struct WorkBriefBaseline: Codable, Equatable, Sendable {
    /// Schema for persisted fingerprints.
    public static let schemaVersion = 1
    /// Time the user last closed a refreshed brief.
    public let capturedAt: Date
    /// Local fingerprints keyed by stable workspace ID.
    public let local: [String: Local]
    /// External fingerprints keyed by provider-qualified ID.
    public let external: [String: External]
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
        version = Self.schemaVersion
        capturedAt = now
        if snapshot.localHealth.state == .available {
            local = Dictionary(uniqueKeysWithValues: snapshot.localWorkspaces.prefix(100).map {
                ($0.id.uuidString, Self.localFingerprint($0))
            })
        } else {
            local = (previous?.local ?? [:]).filter {
                Self.isRetained($0.value.confirmedAt, at: now)
            }
        }
        var retained = (previous?.external ?? [:]).filter {
            Self.isRetained($0.value.confirmedAt, at: now)
        }
        for source in [WorkBriefSource.linear, .github, .slack] {
            guard Self.health(for: source, snapshot: snapshot).state == .available else { continue }
            retained = retained.filter { $0.value.source != source.rawValue }
            for item in snapshot.externalItems.filter({ $0.source == source }).prefix(100) {
                retained[item.id] = Self.externalFingerprint(item)
            }
        }
        external = Dictionary(uniqueKeysWithValues: retained.sorted { $0.key < $1.key }
            .prefix(200).map { ($0.key, $0.value) })
    }

    /// Reports whether the saved metadata is recent and uses the current schema.
    /// - Parameter now: The time at which to check the baseline.
    /// - Returns: Whether the baseline is valid for comparisons.
    public func valid(at now: Date) -> Bool {
        version == Self.schemaVersion && (0...30 * 24 * 3600).contains(now.timeIntervalSince(capturedAt)) &&
            local.count <= 100 && external.count <= 200
    }

    /// Finds current items newly present or changed since this saved brief.
    /// - Parameter snapshot: The current source snapshot to compare.
    /// - Returns: Bounded IDs of items with verified changes.
    public func changes(in snapshot: WorkBriefSnapshot) -> WorkBriefChanges {
        let localIDs: [UUID] = snapshot.localHealth.state == .available
            ? snapshot.localWorkspaces.filter { item in
                guard let old = local[item.id.uuidString] else { return true }
                return !Self.sameMeaning(old, Self.localFingerprint(item))
            }.map(\.id)
            : []
        let externalIDs = snapshot.externalItems.filter { item in
            guard Self.health(for: item.source, snapshot: snapshot).state == .available else { return false }
            guard let old = external[item.id] else { return true }
            return !Self.sameMeaning(old, Self.externalFingerprint(item))
        }.map(\.id)
        return WorkBriefChanges(since: capturedAt, localIDs: Array(localIDs.prefix(20)),
                                externalIDs: Array(externalIDs.prefix(20)))
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

