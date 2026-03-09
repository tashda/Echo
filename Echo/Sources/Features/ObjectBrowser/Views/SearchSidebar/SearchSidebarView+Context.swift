import SwiftUI

extension SearchSidebarView {
    func syncContext(forceRestore: Bool = false) {
        let session = activeSession
        let newKey = session.map { SearchSidebarContextKey(connectionID: $0.connection.id, databaseName: $0.selectedDatabaseName) }

        if forceRestore || newKey != activeCacheKey {
            persistActiveCache()
            activeCacheKey = newKey
            restoreCache(for: newKey)
        }

        if let session {
            viewModel.updateContext(
                databaseSession: session.session,
                databaseName: session.selectedDatabaseName,
                databaseType: session.connection.databaseType
            )
        } else {
            viewModel.updateContext(databaseSession: nil, databaseName: nil, databaseType: nil)
        }
    }

    func restoreCache(for key: SearchSidebarContextKey?) {
        let cache = key.flatMap { environmentState.searchSidebarCaches[$0] } ?? SearchSidebarCache()
        viewModel.restore(from: cache)
    }

    func persistActiveCache() {
        guard didRestoreCache, !viewModel.isRestoringState else { return }
        guard let key = activeCacheKey else { return }
        let snapshot = viewModel.snapshot()
        if environmentState.searchSidebarCaches[key] != snapshot {
            environmentState.searchSidebarCaches[key] = snapshot
        }
    }

    func cacheState() {
        guard didRestoreCache, !viewModel.isRestoringState else { return }
        guard let key = activeCacheKey else { return }
        let snapshot = viewModel.snapshot()
        if environmentState.searchSidebarCaches[key] != snapshot {
            environmentState.searchSidebarCaches[key] = snapshot
        }
    }
}
