import SwiftUI
#if os(macOS)
import AppKit
#endif

struct ConnectionsSidebarView: View {
    @Environment(ProjectStore.self) internal var projectStore
    @Environment(ConnectionStore.self) internal var connectionStore
    @Environment(NavigationStore.self) internal var navigationStore
    @EnvironmentObject internal var environmentState: EnvironmentState

    @Binding var selectedConnectionID: UUID?
    @Binding var selectedIdentityID: UUID?

    let onCreateConnection: (SavedFolder?) -> Void
    let onEditConnection: (SavedConnection) -> Void
    let onConnect: (SavedConnection) -> Void
    let onMoveConnection: (UUID, UUID?) -> Void
    let onMoveFolder: (UUID, UUID?) -> Void
    let onDuplicateConnection: (SavedConnection) -> Void

    @State internal var searchText: String = ""
    @State internal var expandedFolders: Set<UUID> = []
    @State internal var folderEditorState: FolderEditorState?
    @State internal var pendingDeletion: DeletionTarget?
    
    internal var currentProjectID: UUID? { projectStore.selectedProject?.id }
    internal var trimmedSearch: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }
    internal var isSearching: Bool { !trimmedSearch.isEmpty }

    internal var rootConnections: [SavedConnection] { connections(in: nil) }
    internal var connectionGroups: [ConnectionFolderGroup] { buildGroups(parentID: nil, depth: 0) }

    internal var displayedRootConnections: [SavedConnection] { filterConnections(rootConnections) }
    internal var displayedGroups: [ConnectionFolderGroup] { filterGroups(connectionGroups) }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    connectionsContent
                }
                .padding(.vertical, SpacingTokens.xs)
            }
            .scrollIndicators(.hidden)
        }
        .accessibilityIdentifier("connections-sidebar")
        .background(Color.clear)
        .contextMenu { addMenuContent() }
        .sheet(item: $folderEditorState) { FolderEditorSheet(state: $0).environmentObject(environmentState) }
        .alert("Delete Item?", isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }), presenting: pendingDeletion) { target in
            Button("Delete", role: .destructive) { performDeletion(for: target) }
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
        } message: { Text("Are you sure you want to delete \($0.displayName)? This action cannot be undone.") }
        .onAppear(perform: syncExpandedFoldersFromModel)
        .onChange(of: connectionStore.expandedConnectionFolderIDs) { _, newValue in if newValue != expandedFolders { expandedFolders = newValue } }
        .onChange(of: expandedFolders) { _, newValue in connectionStore.updateExpandedConnectionFolders(newValue) }
    }

    private var searchBar: some View {
        SidebarSearchBar(placeholder: "Search connections", text: $searchText, showsClearButton: !trimmedSearch.isEmpty, onClear: { searchText = "" }) {
            Menu { addMenuContent() } label: { 
                Image(systemName: "plus.circle.fill")
                    .font(TypographyTokens.display.weight(.semibold))
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .padding(SpacingTokens.xxxs) 
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
        }
    }

    @ViewBuilder
    private var connectionsContent: some View {
        let roots = displayedRootConnections
        let groups = displayedGroups
        if roots.isEmpty && groups.isEmpty {
            ConnectionsEmptyState(query: trimmedSearch, isSearching: isSearching).padding(.horizontal, SpacingTokens.md).padding(.top, 36)
        } else {
            ForEach(roots, id: \.id) { connection in
                ConnectionListRow(connection: connection, isSelected: selectedConnectionID == connection.id, indent: 0, onTap: { selectConnection(connection) }, onConnect: { selectConnection(connection); onConnect(connection) }, onEdit: { selectConnection(connection); onEditConnection(connection) }, onDuplicate: { onDuplicateConnection(connection) }, onDelete: { pendingDeletion = .connection(connection) })
            }
            ForEach(groups) { group in
                ConnectionFolderView(group: group, expandedFolders: $expandedFolders, isSearching: isSearching, selectedConnectionID: $selectedConnectionID, onSelectFolder: { selectFolder($0) }, onSelectConnection: { selectConnection($0) }, onConnect: onConnect, onEditConnection: onEditConnection, onDuplicate: onDuplicateConnection, onDelete: { pendingDeletion = $0 }, onCreateConnection: { onCreateConnection($0) }, onCreateFolder: { openFolderCreator(parent: $0) }, onEditFolder: { openFolderEditor($0) }, onMoveConnection: onMoveConnection, onMoveFolder: onMoveFolder)
            }
        }
    }

    internal var selectedConnectionFolder: SavedFolder? {
        guard let id = connectionStore.selectedFolderID else { return nil }
        return connectionStore.folders.first { $0.id == id && $0.kind == .connections }
    }

    internal func selectConnection(_ connection: SavedConnection) {
        selectedIdentityID = nil; selectedConnectionID = connection.id; connectionStore.selectedFolderID = nil
    }

    internal func selectFolder(_ folder: SavedFolder) {
        selectedIdentityID = nil; selectedConnectionID = nil; connectionStore.selectedFolderID = folder.id
    }

    internal func openFolderCreator(parent: SavedFolder?) {
        folderEditorState = .create(kind: .connections, parent: parent, token: UUID())
    }

    internal func openFolderEditor(_ folder: SavedFolder) {
        folderEditorState = .edit(folder: folder)
    }

    internal func openManageConnections() {
#if os(macOS)
        ManageConnectionsWindowController.shared.present()
#else
        environmentState.isManageConnectionsPresented = true
#endif
    }

    @ViewBuilder
    internal func addMenuContent() -> some View {
        Button("New Connection…", systemImage: "externaldrive.badge.plus") { onCreateConnection(selectedConnectionFolder); selectedIdentityID = nil }
        Button("New Connection Folder…", systemImage: "folder.badge.plus") { openFolderCreator(parent: selectedConnectionFolder); selectedIdentityID = nil }
        Divider()
        Button("Manage Connections…", systemImage: "gearshape") { openManageConnections(); selectedIdentityID = nil }
    }

    internal func performDeletion(for target: DeletionTarget) {
        pendingDeletion = nil
        switch target {
        case .connection(let c): Task { await environmentState.deleteConnection(c) }
        case .folder(let f): Task { try? await connectionStore.deleteFolder(f) }
        case .identity: break
        }
    }

    internal func syncExpandedFoldersFromModel() { expandedFolders = connectionStore.expandedConnectionFolderIDs }
}
