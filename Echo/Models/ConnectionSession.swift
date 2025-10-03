import Foundation
import SwiftUI
import Combine

// MARK: - Connection Session Management

enum StructureLoadingState: Equatable {
    case idle
    case loading(progress: Double?)
    case ready
    case failed(message: String?)
}

/// Represents an active connection session to a database server
@MainActor
final class ConnectionSession: ObservableObject, Identifiable {
    let id: UUID
    let connection: SavedConnection
    let session: DatabaseSession

    @Published var selectedDatabaseName: String?
    @Published var databaseStructure: DatabaseStructure?
    @Published var connectionState: ConnectionState = .connected
    @Published var lastActivity: Date = Date()
    @Published var structureLoadingState: StructureLoadingState = .idle
    @Published var structureLoadingMessage: String?

    // Query tabs specific to this connection
    @Published var queryTabs: [WorkspaceTab] = []
    @Published var activeQueryTabID: UUID?

    init(id: UUID = UUID(), connection: SavedConnection, session: DatabaseSession) {
        self.id = id
        self.connection = connection
        self.session = session

        // Auto-select database if one is saved in the connection
        if !connection.database.isEmpty {
            self.selectedDatabaseName = connection.database
        } else {
            self.selectedDatabaseName = nil
        }
    }

    var activeQueryTab: WorkspaceTab? {
        guard let activeID = activeQueryTabID else { return nil }
        return queryTabs.first { $0.id == activeID }
    }

    var displayName: String {
        if let dbName = selectedDatabaseName {
            return "\(connection.connectionName) • \(dbName)"
        } else {
            return connection.connectionName
        }
    }

    var shortDisplayName: String {
        return connection.connectionName
    }

    var isConnected: Bool {
        return connectionState.isConnected
    }

    func addQueryTab(withQuery query: String = "", database: String? = nil) {
        let queryState = QueryEditorState(sql: query.isEmpty ? "SELECT current_timestamp;" : query)
        let tab = WorkspaceTab(
            connection: connection,
            session: session,
            connectionSessionID: id,
            title: "Query \(queryTabs.count + 1)",
            content: .query(queryState)
        )
        queryTabs.append(tab)
        activeQueryTabID = tab.id
        lastActivity = Date()
    }

    func closeQueryTab(withID tabID: UUID) {
        guard let index = queryTabs.firstIndex(where: { $0.id == tabID }) else { return }
        queryTabs.remove(at: index)

        // Adjust active tab
        if activeQueryTabID == tabID {
            if !queryTabs.isEmpty {
                // Select the previous tab, or the first one if we removed the first
                let newIndex = max(0, index - 1)
                activeQueryTabID = queryTabs.indices.contains(newIndex) ? queryTabs[newIndex].id : queryTabs.first?.id
            } else {
                activeQueryTabID = nil
            }
        }
        lastActivity = Date()
    }

    func updateActivity() {
        lastActivity = Date()
    }
}

// MARK: - Multi-Connection Manager

/// Manages multiple active database connections and provides server switching functionality
@MainActor
final class ConnectionSessionManager: ObservableObject {
    @Published var activeSessions: [ConnectionSession] = []
    @Published var activeSessionID: UUID?
    @Published var isServerSwitcherVisible = false

    // MARK: - Computed Properties

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
        activeSessions.removeAll { $0.connection.id == session.connection.id }

        // Add the new session
        activeSessions.append(session)
        activeSessionID = session.id
        session.updateActivity()
    }

    func removeSession(withID sessionID: UUID) {
        guard let index = activeSessions.firstIndex(where: { $0.id == sessionID }) else { return }
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

// MARK: - Server Switcher Data

struct ServerSwitcherItem: Identifiable {
    let id: UUID
    let session: ConnectionSession
    let isActive: Bool

    var displayName: String { session.displayName }
    var shortName: String { session.shortDisplayName }
    var queryTabCount: Int { session.queryTabs.count }
    var connectionColor: Color { session.connection.color }
    var lastActivity: Date { session.lastActivity }
}
