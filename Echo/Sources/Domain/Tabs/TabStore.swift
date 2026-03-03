import Foundation
import Observation

/// A modular store that manages workspace tabs.
/// Refactored from `AppModel` to adhere to modular MVVM and under-500-line limits.
@Observable @MainActor
final class TabStore {
    // MARK: - State
    var tabManager = TabManager()
    
    // MARK: - Initialization
    init() {}
    
    // MARK: - Public API
    
    var activeTab: WorkspaceTab? {
        tabManager.activeTab
    }
    
    func selectTab(_ tab: WorkspaceTab) {
        tabManager.activeTabId = tab.id
    }
    
    func closeTab(_ tab: WorkspaceTab) {
        tabManager.closeTab(id: tab.id)
    }
}
