import Foundation
import BmuxFoundation
import ProvenanceEngineContracts

/// Value snapshot of PE-owned workspace display Current State for UI projection.
struct WorkspaceDisplayCurrentStateSnapshot: Equatable, Sendable {
    let stableWorkspaceID: UUID
    let title: String?
    let currentDirectory: String?
    let branch: String?
    let pullRequest: WorkspaceDisplayCurrentStatePullRequestSnapshot?
    let isDirty: Bool?
    let ticketLinks: [WorkspaceDisplayCurrentStateTicketLinkSnapshot]
    let projectLinks: [WorkspaceDisplayCurrentStateProjectLinkSnapshot]
    let currentWorkSummary: String?
    let lastSubmittedPrompt: String?
    let lastSubmittedPromptSubmittedAt: Date?
    let lastSubmittedPromptSessionID: String?
    let clearedFields: [String]
    let fieldMetadata: [String: ProvenanceWorkspaceDisplayFieldMetadataRecord]
    let latestEventID: String?
    let latestEventSequence: Int?
    let updatedAt: Date

    init?(_ display: ProvenanceWorkspaceDisplayRecord) {
        guard let stableWorkspaceID = UUID(uuidString: display.workspaceID) else {
            return nil
        }
        self.stableWorkspaceID = stableWorkspaceID
        self.title = display.title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.currentDirectory = display.currentDirectory?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.branch = display.branch?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.pullRequest = WorkspaceDisplayCurrentStatePullRequestSnapshot(display)
        self.isDirty = display.isDirty
        self.ticketLinks = WorkspaceDisplayCurrentStateTicketLinkSnapshot.links(
            ticketIDs: display.ticketIDs,
            ticketLinks: display.ticketLinks
        )
        self.projectLinks = display.projectLinks.compactMap(WorkspaceDisplayCurrentStateProjectLinkSnapshot.init)
        self.currentWorkSummary = display.currentWorkSummary?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.lastSubmittedPrompt = display.lastSubmittedPrompt?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.lastSubmittedPromptSubmittedAt = display.lastSubmittedPromptSubmittedAt
        self.lastSubmittedPromptSessionID = display.lastSubmittedPromptSessionID?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.clearedFields = display.clearedFields
        self.fieldMetadata = display.fieldMetadata
        self.latestEventID = display.latestEventID?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.latestEventSequence = display.latestEventSequence
        self.updatedAt = display.updatedAt
    }

    func isNewerThan(_ existing: WorkspaceDisplayCurrentStateSnapshot?) -> Bool {
        guard let existing else { return true }
        switch (latestEventSequence, existing.latestEventSequence) {
        case let (new?, old?):
            if new != old { return new > old }
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            break
        }
        switch (latestEventID, existing.latestEventID) {
        case let (new?, old?) where new != old:
            return updatedAt >= existing.updatedAt
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            return updatedAt >= existing.updatedAt && self != existing
        }
    }
}
