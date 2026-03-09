import SwiftUI
import Combine
import EchoSense

@MainActor
final class ObjectBrowserSidebarViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var debouncedSearchText = ""
    @Published var isSearchFieldFocused = false
    @Published var expandedServerIDs: Set<UUID> = []
    @Published var knownSessionIDs: Set<UUID> = []

    /// Maps connection ID → session ID for the last initialized session.
    /// Used to detect reconnects (same connection ID, new session ID).
    private var lastInitializedSessionID: [UUID: UUID] = [:]

    // Per-session state
    @Published var expandedDatabasesBySession: [UUID: Set<String>] = [:]
    @Published var expandedObjectGroupsBySession: [UUID: Set<SchemaObjectInfo.ObjectType>] = [:]
    @Published var expandedObjectIDsBySession: [UUID: Set<String>] = [:]
    @Published var selectedSchemaNameBySession: [UUID: String] = [:]
    @Published var pinnedObjectIDsByDatabase: [String: Set<String>] = [:]
    @Published var pinnedSectionExpandedByDatabase: [String: Bool] = [:]
    @Published var databaseSchemaLoadingStates: [String: Bool] = [:]

    // Server folder groups (Databases, Management, etc.)
    @Published var databasesFolderExpandedBySession: [UUID: Bool] = [:]
    @Published var managementFolderExpandedBySession: [UUID: Bool] = [:]

    // Agent Jobs state (per-connection, MSSQL only)
    @Published var agentJobsExpandedBySession: [UUID: Bool] = [:]
    @Published var agentJobsBySession: [UUID: [AgentJobItem]] = [:]
    @Published var agentJobsLoadingBySession: [UUID: Bool] = [:]
    @Published var showNewJobSheet = false
    @Published var newJobSessionID: UUID?

    // Database properties sheet
    @Published var showDatabaseProperties = false
    @Published var propertiesDatabaseName: String?
    @Published var propertiesConnectionID: UUID?

    struct AgentJobItem: Identifiable, Hashable {
        let id: String
        let name: String
        let enabled: Bool
        let lastOutcome: String?
    }
    
    private var searchDebounceTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    func setupSearchDebounce(proxy: ScrollViewProxy) {
        $searchText
            .dropFirst()
            .sink { [weak self] newValue in
                guard let self else { return }
                self.searchDebounceTask?.cancel()
                let trimmedNew = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if trimmedNew.isEmpty {
                    self.searchDebounceTask = Task { @MainActor in
                        self.debouncedSearchText = ""
                        await Task.yield()
                        guard !Task.isCancelled else { return }
                        proxy.scrollTo(ExplorerSidebarConstants.objectsTopAnchor, anchor: .top)
                    }
                } else {
                    let pendingText = newValue
                    self.searchDebounceTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 200_000_000)
                        guard !Task.isCancelled else { return }
                        self.debouncedSearchText = pendingText
                        await Task.yield()
                        guard !Task.isCancelled else { return }
                        proxy.scrollTo(ExplorerSidebarConstants.objectsTopAnchor, anchor: .top)
                    }
                }
            }
            .store(in: &cancellables)
    }

    func stopSearchDebounce() {
        searchDebounceTask?.cancel()
        searchDebounceTask = nil
    }

    func resetFilters(for session: ConnectionSession?, selectedSession: ConnectionSession?) {
        if !searchText.isEmpty {
            searchText = ""
            debouncedSearchText = ""
            searchDebounceTask?.cancel()
        }
        guard let targetSession = session ?? selectedSession else { return }
        let connID = targetSession.connection.id
        selectedSchemaNameBySession.removeValue(forKey: connID)
        expandedObjectIDsBySession.removeValue(forKey: connID)
        let supportedSet = Set(supportedObjectTypes(for: targetSession))
        expandedObjectGroupsBySession[connID] = supportedSet
    }

    private func supportedObjectTypes(for session: ConnectionSession?) -> [SchemaObjectInfo.ObjectType] {
        guard let session else { return SchemaObjectInfo.ObjectType.allCases }
        return SchemaObjectInfo.ObjectType.supported(for: session.connection.databaseType)
    }

    func initializeSessionState(for session: ConnectionSession, autoExpandSections: Set<SidebarAutoExpandSection> = [.databases]) {
        let connID = session.connection.id
        let sessionID = session.id
        let supported = Set(supportedObjectTypes(for: session))

        // Detect reconnect: same connection ID but different session ID
        let isNewSession = lastInitializedSessionID[connID] != sessionID
        if isNewSession {
            lastInitializedSessionID[connID] = sessionID
            // Clear stale expansion state so settings are re-applied
            expandedObjectGroupsBySession.removeValue(forKey: connID)
            expandedDatabasesBySession.removeValue(forKey: connID)
            expandedObjectIDsBySession.removeValue(forKey: connID)
            databasesFolderExpandedBySession.removeValue(forKey: connID)
            managementFolderExpandedBySession.removeValue(forKey: connID)
            agentJobsExpandedBySession.removeValue(forKey: connID)
        }

        if expandedObjectGroupsBySession[connID] == nil {
            var groups = Set<SchemaObjectInfo.ObjectType>()
            for section in autoExpandSections {
                if let objectType = section.objectType, supported.contains(objectType) {
                    groups.insert(objectType)
                }
            }
            expandedObjectGroupsBySession[connID] = groups
        }

        if databasesFolderExpandedBySession[connID] == nil {
            databasesFolderExpandedBySession[connID] = autoExpandSections.contains(.databases)
        }

        if managementFolderExpandedBySession[connID] == nil {
            managementFolderExpandedBySession[connID] = autoExpandSections.contains(.management)
        }

        if agentJobsExpandedBySession[connID] == nil {
            agentJobsExpandedBySession[connID] = autoExpandSections.contains(.management)
        }
    }

    // MARK: - Database Expansion

    func isDatabaseExpanded(connectionID: UUID, databaseName: String) -> Bool {
        expandedDatabasesBySession[connectionID]?.contains(databaseName) ?? false
    }

    func toggleDatabaseExpanded(connectionID: UUID, databaseName: String) {
        var expanded = expandedDatabasesBySession[connectionID] ?? []
        if expanded.contains(databaseName) {
            expanded.remove(databaseName)
        } else {
            expanded.insert(databaseName)
        }
        expandedDatabasesBySession[connectionID] = expanded
    }

    func isDatabaseLoading(connectionID: UUID, databaseName: String) -> Bool {
        databaseSchemaLoadingStates[pinnedStorageKey(connectionID: connectionID, databaseName: databaseName)] ?? false
    }

    func setDatabaseLoading(connectionID: UUID, databaseName: String, loading: Bool) {
        databaseSchemaLoadingStates[pinnedStorageKey(connectionID: connectionID, databaseName: databaseName)] = loading
    }

    // MARK: - Per-Session Bindings

    func expandedObjectGroupsBinding(for connectionID: UUID) -> Binding<Set<SchemaObjectInfo.ObjectType>> {
        Binding(
            get: { [weak self] in self?.expandedObjectGroupsBySession[connectionID] ?? Set(SchemaObjectInfo.ObjectType.allCases) },
            set: { [weak self] in self?.expandedObjectGroupsBySession[connectionID] = $0 }
        )
    }

    func expandedObjectIDsBinding(for connectionID: UUID) -> Binding<Set<String>> {
        Binding(
            get: { [weak self] in self?.expandedObjectIDsBySession[connectionID] ?? [] },
            set: { [weak self] in self?.expandedObjectIDsBySession[connectionID] = $0 }
        )
    }

    func selectedSchemaNameBinding(for connectionID: UUID) -> Binding<String?> {
        Binding(
            get: { [weak self] in self?.selectedSchemaNameBySession[connectionID] },
            set: { [weak self] newValue in
                if let newValue {
                    self?.selectedSchemaNameBySession[connectionID] = newValue
                } else {
                    self?.selectedSchemaNameBySession.removeValue(forKey: connectionID)
                }
            }
        )
    }

    func ensureServerExpanded(for connectionID: UUID, sessions: [ConnectionSession]) {
        expandedServerIDs = expandedServerIDs.filter { id in
            sessions.contains { $0.connection.id == id }
        }
        expandedServerIDs.insert(connectionID)
    }

    func ensureDatabaseExpanded(connectionID: UUID, databaseName: String) {
        var expanded = expandedDatabasesBySession[connectionID] ?? []
        expanded.insert(databaseName)
        expandedDatabasesBySession[connectionID] = expanded
    }

    func pinnedStorageKey(connectionID: UUID, databaseName: String) -> String {
        "\(connectionID.uuidString)#\(databaseName)"
    }

    func pinnedObjectsBinding(for database: DatabaseInfo, connectionID: UUID) -> Binding<Set<String>> {
        let key = pinnedStorageKey(connectionID: connectionID, databaseName: database.name)
        return Binding(
            get: { [weak self] in self?.pinnedObjectIDsByDatabase[key] ?? [] },
            set: { [weak self] newValue in
                if newValue.isEmpty {
                    self?.pinnedObjectIDsByDatabase.removeValue(forKey: key)
                } else {
                    self?.pinnedObjectIDsByDatabase[key] = newValue
                }
            }
        )
    }

    func pinnedSectionExpandedBinding(for database: DatabaseInfo, connectionID: UUID) -> Binding<Bool> {
        let key = pinnedStorageKey(connectionID: connectionID, databaseName: database.name)
        return Binding(
            get: { [weak self] in self?.pinnedSectionExpandedByDatabase[key] ?? true },
            set: { [weak self] newValue in
                self?.pinnedSectionExpandedByDatabase[key] = newValue
            }
        )
    }
}
