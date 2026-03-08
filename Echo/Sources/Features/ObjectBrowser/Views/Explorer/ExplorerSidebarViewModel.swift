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

    // Per-session state
    @Published var expandedObjectGroupsBySession: [UUID: Set<SchemaObjectInfo.ObjectType>] = [:]
    @Published var expandedObjectIDsBySession: [UUID: Set<String>] = [:]
    @Published var selectedSchemaNameBySession: [UUID: String] = [:]
    @Published var pinnedObjectIDsByDatabase: [String: Set<String>] = [:]
    @Published var pinnedSectionExpandedByDatabase: [String: Bool] = [:]
    
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

    func initializeSessionState(for session: ConnectionSession) {
        let connID = session.connection.id
        if expandedObjectGroupsBySession[connID] == nil {
            expandedObjectGroupsBySession[connID] = Set(supportedObjectTypes(for: session))
        }
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
