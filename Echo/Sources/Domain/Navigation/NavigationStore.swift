import Foundation
import Observation

/// A modular store that manages the application's navigation and explorer focus state.
/// Refactored from `AppModel` to adhere to modular MVVM and under-500-line limits.
@Observable @MainActor
final class NavigationStore {
    // MARK: - State
    var navigationState = NavigationState()
    var pendingExplorerFocus: ExplorerFocus?
    var isWorkspaceWindowKey = false
    var isManageConnectionsPresented = false
    var showNewProjectSheet = false
    var showManageProjectsSheet = false
    
    // MARK: - Initialization
    init() {}
    
    // MARK: - Public API
    
    func selectProject(_ project: Project) {
        navigationState.selectProject(project)
    }
    
    func focusExplorer(_ focus: ExplorerFocus) {
        self.pendingExplorerFocus = focus
    }
    
    func clearExplorerFocus() {
        self.pendingExplorerFocus = nil
    }
}
