import SwiftUI

extension SearchSidebarView {
    func syncContext(forceRestore: Bool = false) {
        let sessions = environmentState.sessionGroup.activeSessions
        viewModel.updateSessions(sessions)
        viewModel.applySettings(projectStore.globalSettings)

        if forceRestore {
            restoreCache()
        }
    }

    func restoreCache() {
        let cache = environmentState.searchSidebarCache
        viewModel.restore(from: cache)
    }

    /// Persists the full search state to EnvironmentState on disappear only.
    /// Never called during active interaction — writing to the parent @Observable
    /// mid-interaction causes cascading re-renders that destroy @FocusState.
    func persistCache() {
        guard didRestoreCache, !viewModel.isRestoringState else { return }
        let snapshot = viewModel.snapshot()
        if environmentState.searchSidebarCache != snapshot {
            environmentState.searchSidebarCache = snapshot
        }
    }
}
