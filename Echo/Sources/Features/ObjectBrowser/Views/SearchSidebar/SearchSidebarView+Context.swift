import SwiftUI

extension SearchSidebarView {
    func syncContext(forceRestore: Bool = false) {
        let sessions = environmentState.sessionGroup.activeSessions
        viewModel.updateSessions(sessions)

        if forceRestore {
            restoreCache()
        }
    }

    func restoreCache() {
        let cache = environmentState.searchSidebarCache
        viewModel.restore(from: cache)
    }

    func persistCache() {
        guard didRestoreCache, !viewModel.isRestoringState else { return }
        let snapshot = viewModel.snapshot()
        if environmentState.searchSidebarCache != snapshot {
            environmentState.searchSidebarCache = snapshot
        }
    }

    func cacheState() {
        guard didRestoreCache, !viewModel.isRestoringState else { return }
        let snapshot = viewModel.snapshot()
        if environmentState.searchSidebarCache != snapshot {
            environmentState.searchSidebarCache = snapshot
        }
    }
}
