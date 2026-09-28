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
    /// Which sidebar tool is showing. Shared so the floating server rail can switch it
    /// while the sidebar is hidden.
    var sidebarSection: SidebarMenu.NavSection = .folder
    /// Whether the open-queries glance panel next to the server rail is showing.
    var isQueryGlanceOpen = false
    var isWorkspaceWindowKey = false
    var isManageConnectionsPresented = false
    var showNewProjectSheet = false
    var showManageProjectsSheet = false
    var inspectorWidth: CGFloat = 300

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
    
    func updateInspectorWidth(_ width: CGFloat, min minWidth: CGFloat, max maxWidth: CGFloat) {
        let clamped = max(minWidth, min(maxWidth, width))
        guard abs(inspectorWidth - clamped) > 0.5 else { return }
        inspectorWidth = clamped
    }
}
