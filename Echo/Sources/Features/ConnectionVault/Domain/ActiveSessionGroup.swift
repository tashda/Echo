import Foundation

// MARK: - Multi-Connection Manager

@Observable @MainActor
final class ActiveSessionGroup {
    var activeSessions: [ConnectionSession] = []
    var activeSessionID: UUID?
    var isServerSwitcherVisible = false

    // MARK: - Computed Properties

    var activeConnectionID: UUID? {
        activeSession?.connection.id
    }

    var activeDatabaseName: String? {
        activeSession?.activeDatabaseName
    }

    var activeSession: ConnectionSession? {
        guard let activeID = activeSessionID else { return nil }
        return activeSessions.first { $0.id == activeID }
    }

    var sessions: [ConnectionSession] {
        return activeSessions
    }

    var sortedSessions: [ConnectionSession] {
        return activeSessions.sorted { $0.lastActivity > $1.lastActivity }
    }

    // MARK: - Session Management

    func addSession(_ session: ConnectionSession) {
        // Remove any existing session for the same connection
        if let existing = activeSessions.first(where: { $0.connection.id == session.connection.id }) {
            let sessionID = existing.id
            Task {
                for tab in existing.queryTabs where tab.ownsSession {
                    await tab.session.close()
                }
                await existing.session.close()
            }
            activeSessions.removeAll { $0.id == sessionID }
        }

        // Add the new session
        activeSessions.append(session)
        activeSessionID = session.id
        session.updateActivity()
    }

    func removeSession(withID sessionID: UUID) {
        guard let index = activeSessions.firstIndex(where: { $0.id == sessionID }) else { return }

        // Cancel any in-flight queries belonging to this session before removing it
        let session = activeSessions[index]
        for tab in session.queryTabs {
            if let state = tab.query {
                state.cancelExecution()
            }
        }

        // Stop health check before closing
        session.stopHealthCheck()

        // Close the database session properly to avoid driver crashes on deinit
        Task {
            for tab in session.queryTabs where tab.ownsSession {
                await tab.session.close()
            }
            await session.session.close()
        }

        activeSessions.remove(at: index)

        // Adjust active session
        if activeSessionID == sessionID {
            activeSessionID = activeSessions.first?.id
        }
    }

    func setActiveSession(_ sessionID: UUID) {
        guard activeSessions.contains(where: { $0.id == sessionID }) else { return }
        activeSessionID = sessionID

        // Update activity for the newly active session
        if let session = activeSession {
            session.updateActivity()
        }
    }

    func sessionForConnection(_ connectionID: UUID) -> ConnectionSession? {
        return activeSessions.first { $0.connection.id == connectionID }
    }

    // MARK: - Server Switching (Cmd+Tab style)

    func showServerSwitcher() {
        guard activeSessions.count > 1 else { return }
        isServerSwitcherVisible = true
    }

    func hideServerSwitcher() {
        isServerSwitcherVisible = false
    }

    func switchToNextServer() {
        guard activeSessions.count > 1 else { return }

        let sorted = sortedSessions
        guard let currentIndex = sorted.firstIndex(where: { $0.id == activeSessionID }) else {
            activeSessionID = sorted.first?.id
            return
        }

        let nextIndex = (currentIndex + 1) % sorted.count
        activeSessionID = sorted[nextIndex].id
        sorted[nextIndex].updateActivity()
    }

    func switchToPreviousServer() {
        guard activeSessions.count > 1 else { return }

        let sorted = sortedSessions
        guard let currentIndex = sorted.firstIndex(where: { $0.id == activeSessionID }) else {
            activeSessionID = sorted.first?.id
            return
        }

        let previousIndex = currentIndex == 0 ? sorted.count - 1 : currentIndex - 1
        activeSessionID = sorted[previousIndex].id
        sorted[previousIndex].updateActivity()
    }

    // MARK: - Query Tab Management

    func addQueryTab(toSessionID sessionID: UUID, withQuery query: String = "", database: String? = nil) {
        guard let session = activeSessions.first(where: { $0.id == sessionID }) else { return }
        session.addQueryTab(withQuery: query, database: database)
    }

    func addQueryTabToActiveSession(withQuery query: String = "", database: String? = nil) {
        guard let session = activeSession else { return }
        session.addQueryTab(withQuery: query, database: database)
    }

    func closeQueryTab(withID tabID: UUID, fromSessionID sessionID: UUID) {
        guard let session = activeSessions.first(where: { $0.id == sessionID }) else { return }
        session.closeQueryTab(withID: tabID)
    }
}
