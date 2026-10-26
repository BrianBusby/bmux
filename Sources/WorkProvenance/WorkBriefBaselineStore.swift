import BmuxWorkBrief
import Foundation

/// Persists only bounded Work Brief fingerprints in the app's own preferences.
@MainActor
struct WorkBriefBaselineStore {
    private let defaults: UserDefaults
    private let key = "workBrief.previousBrief.v2"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load(at now: Date) -> WorkBriefBaseline? {
        defaults.removeObject(forKey: "workBrief.previousBrief.v1")
        guard let data = defaults.data(forKey: key) else { return nil }
        guard data.count <= WorkBriefBaseline.maxEncodedBytes,
              let baseline = try? JSONDecoder().decode(WorkBriefBaseline.self, from: data),
              baseline.valid(at: now) else {
            defaults.removeObject(forKey: key)
            return nil
        }
        return baseline
    }

    func save(snapshot: WorkBriefSnapshot, previous: WorkBriefBaseline?, at now: Date) {
        guard snapshot.localHealth.state == .available ||
              snapshot.linearHealth.state == .available ||
              snapshot.githubHealth.state == .available ||
              snapshot.slackHealth.state == .available else { return }
        let baseline = WorkBriefBaseline(snapshot: snapshot, previous: previous, at: now)
        guard let data = try? JSONEncoder().encode(baseline),
              data.count <= WorkBriefBaseline.maxEncodedBytes else { return }
        defaults.set(data, forKey: key)
    }
}
