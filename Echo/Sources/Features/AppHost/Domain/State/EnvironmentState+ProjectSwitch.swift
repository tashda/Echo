import Foundation

extension EnvironmentState {

    // MARK: - Project Switching

    /// Initiates a project switch. If there are active connections, sets `pendingProjectSwitch`
    /// to trigger a confirmation alert. Otherwise switches immediately.
    func requestProjectSwitch(to project: Project) {
        guard project.id != projectStore.selectedProject?.id else { return }

        if hasActiveConnections {
            pendingProjectSwitch = project
        } else {
            executeProjectSwitch(to: project)
        }
    }

    /// Called when the user confirms the project switch alert.
    func confirmProjectSwitch() {
        guard let project = pendingProjectSwitch else { return }
        pendingProjectSwitch = nil
        executeProjectSwitch(to: project)
    }

    /// Called when the user cancels the project switch alert.
    func cancelProjectSwitch() {
        pendingProjectSwitch = nil
    }

    /// Orchestrates the full project switch: disconnect, close tabs, reset state, switch stores.
    private func executeProjectSwitch(to project: Project) {
        // 1. Disconnect all active sessions
        disconnectAllSessions()

        // 2. Close all tabs
        tabStore.closeAllTabs()

        // 3. Clear transient state
        searchSidebarCache = GlobalSearchSidebarCache()
        dataInspectorContent = nil
        lastError = nil
        observedSessionIDs.removeAll()

        // 4. Switch project in stores
        projectStore.selectProject(project)
        navigationStore.selectProject(project)

        // 5. Reload project-scoped data
        loadExpandedConnectionFolders(for: project.id)
        loadRecentConnections()
    }
}
