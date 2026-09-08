import Foundation

extension AppDelegate {
    func ensureMobileWorkspaceListObserver(for tabManager: TabManager) {
        appRuntimeServices?.attachMobileHostWorkspaceListObserver(
            tabManager: tabManager,
            notificationStore: notificationStore
        )
    }

    func ensureSidebarGitPullRequestObservation(for tabManager: TabManager) {
        guard let appRuntimeServices else { return }
        let services = appRuntimeServices.tabManagerSidebarGitPullRequestObservationServices()
        guard tabManager.installSidebarGitPullRequestObservationServicesIfCompatibility(services) else { return }
        appRuntimeServices.attachSidebarGitPullRequestObservation(tabManager: tabManager)
    }

    func removeMobileWorkspaceListObserverIfUnused(for tabManager: TabManager) {
        appRuntimeServices?.removeMobileHostWorkspaceListObserverIfUnused(
            tabManager: tabManager,
            isStillUsed: mainWindowContexts.values.contains(where: { $0.tabManager === tabManager })
        )
    }

    func removeSidebarGitPullRequestObservationIfUnused(for tabManager: TabManager) {
        appRuntimeServices?.removeSidebarGitPullRequestObservationIfUnused(
            tabManager: tabManager,
            isStillUsed: mainWindowContexts.values.contains(where: { $0.tabManager === tabManager })
        )
    }
}
