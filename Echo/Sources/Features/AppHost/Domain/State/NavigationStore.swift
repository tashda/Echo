import Foundation
import Observation

/// A modular store that manages the application's navigation and explorer focus state.
/// Refactored from `EnvironmentState` to adhere to modular MVVM and under-500-line limits.
@Observable @MainActor
final class NavigationStore {
    // MARK: - State
    var navigationState = NavigationState()
    var pendingExplorerFocus: ExplorerFocus?
    var pendingExplorerRevealConnectionID: UUID?
    var pendingExplorerRevealRequestID = 0
    /// Which tool page shows in the tree's place. Shared so the rail can switch it.
    var sidebarSection: SidebarMenu.NavSection = .folder
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

    func revealExplorerConnection(_ connectionID: UUID) {
        pendingExplorerRevealConnectionID = connectionID
        pendingExplorerRevealRequestID &+= 1
    }
}
