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

    func persistCache() {
        guard didRestoreCache, !viewModel.isRestoringState else { return }
        let snapshot = viewModel.snapshot()
        if environmentState.searchSidebarCache != snapshot {
            environmentState.searchSidebarCache = snapshot
        }
    }

    /// Cache only durable settings (filters, scope) — not transient state like query text
    /// or results, which change on every keystroke and would cause parent view re-renders
    /// that destroy @FocusState.
    func cacheState() {
        persistCache()
    }
}
