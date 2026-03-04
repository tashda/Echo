import SwiftUI
import Combine
import EchoSense

@MainActor
final class ExplorerSidebarViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var debouncedSearchText = ""
    @Published var selectedSchemaName: String?
    @Published var isSearchFieldFocused = false
    @Published var expandedObjectGroups: Set<SchemaObjectInfo.ObjectType> = Set(SchemaObjectInfo.ObjectType.allCases)
    @Published var expandedServerIDs: Set<UUID> = []
    @Published var expandedObjectIDs: Set<String> = []
    @Published var expandedConnectedServerIDs: Set<UUID> = []
    @Published var isHoveringConnectedServers = false
    @Published var connectedServersHeight: CGFloat = 0
    @Published var knownSessionIDs: Set<UUID> = []
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
        if selectedSchemaName != nil {
            selectedSchemaName = nil
        }
        if !expandedObjectIDs.isEmpty {
            expandedObjectIDs.removeAll()
        }
        let targetSession = session ?? selectedSession
        let supportedSet = Set(supportedObjectTypes(for: targetSession))
        if supportedSet.isEmpty {
            if !expandedObjectGroups.isEmpty {
                expandedObjectGroups.removeAll()
            }
        } else if expandedObjectGroups != supportedSet {
            expandedObjectGroups = supportedSet
        }
    }

    private func supportedObjectTypes(for session: ConnectionSession?) -> [SchemaObjectInfo.ObjectType] {
        guard let session else { return SchemaObjectInfo.ObjectType.allCases }
        return SchemaObjectInfo.ObjectType.supported(for: session.connection.databaseType)
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
