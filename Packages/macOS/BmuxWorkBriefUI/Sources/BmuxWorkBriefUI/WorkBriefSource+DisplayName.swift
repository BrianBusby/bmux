import BmuxWorkBrief
import Foundation

extension WorkBriefSource {
    var displayName: String {
        switch self {
        case .bmux: String(localized: "workBrief.sourceNameBmux", defaultValue: "bmux")
        case .provenanceEngine:
            String(localized: "workBrief.sourceNamePE", defaultValue: "Provenance Engine")
        case .linear: String(localized: "workBrief.sourceNameLinear", defaultValue: "Linear")
        case .github: String(localized: "workBrief.sourceNameGitHub", defaultValue: "GitHub")
        case .slack: String(localized: "workBrief.sourceNameSlack", defaultValue: "Slack")
        }
    }
}
