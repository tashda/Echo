@preconcurrency import SwiftUI
import AppKit

@MainActor
struct ManageConnectionsView: View {
    @Environment(ProjectStore.self) internal var projectStore
    @Environment(ConnectionStore.self) internal var connectionStore
    @Environment(NavigationStore.self) internal var navigationStore
    
    @EnvironmentObject internal var appModel: AppModel
    @EnvironmentObject internal var appState: AppState
    @ObservedObject internal var themeManager = ThemeManager.shared
    @Environment(\.dismiss) internal var dismiss
    internal let onClose: (() -> Void)?

    @State internal var selectedSection: ManageSection? = .connections
    @State internal var sidebarSelection: SidebarSelection? = .section(.connections)
    @State internal var searchText = ""
    @State internal var folderEditorState: FolderEditorState?
    @State internal var identityEditorState: IdentityEditorState?
    @State internal var pendingDeletion: DeletionTarget?
    @State internal var connectionEditorPresentation: ConnectionEditorPresentation?
    @State internal var pendingDuplicateConnection: SavedConnection?
    @State internal var pendingConnectionMove: SavedConnection?
    @State internal var pendingIdentityMove: SavedIdentity?
    @State internal var connectionSelection = Set<SavedConnection.ID>()
    @State internal var identitySelection = Set<SavedIdentity.ID>()
    @State internal var connectionSortOrder: [KeyPathComparator<SavedConnection>] = []
    @State internal var identitySortOrder: [KeyPathComparator<SavedIdentity>] = []

    @State internal var expandedSections: Set<ManageSection> = [.connections, .identities]

    init(onClose: (() -> Void)? = nil) {
        self.onClose = onClose
    }

    internal var activeSection: ManageSection { selectedSection ?? .connections }

    var body: some View {
        contentView
            .onAppear(perform: ensureSectionSelection)
            .onAppear {
                if connectionSortOrder.isEmpty {
                    connectionSortOrder = [KeyPathComparator(\SavedConnection.connectionName, order: .forward)]
                }
                if identitySortOrder.isEmpty {
                    identitySortOrder = [KeyPathComparator(\SavedIdentity.name, order: .forward)]
                }
            }
    }

    private var contentView: some View {
        configuredSplitView
            .preferredColorScheme(themeManager.effectiveColorScheme)
            .sheet(item: $folderEditorState, content: folderEditorSheet)
            .sheet(item: $identityEditorState, content: identityEditorSheet)
            .sheet(item: $connectionEditorPresentation, content: connectionEditorSheet)
            .alert(
                "Delete Item?",
                isPresented: deletionAlertBinding,
                presenting: pendingDeletion,
                actions: deletionAlertActions,
                message: deletionAlertMessage
            )
            .confirmationDialog(
                "Duplicate Connection",
                isPresented: Binding(
                    get: { pendingDuplicateConnection != nil },
                    set: { isPresented in
                        if !isPresented { pendingDuplicateConnection = nil }
                    }
                ),
                titleVisibility: .visible,
                presenting: pendingDuplicateConnection
            ) { connection in
                Button("Duplicate with Bookmark History") {
                    performDuplicate(connection, copyBookmarks: true)
                }

                Button("Duplicate Only Connection") {
                    performDuplicate(connection, copyBookmarks: false)
                }

                Button("Cancel", role: .cancel) {
                    pendingDuplicateConnection = nil
                }
            } message: { _ in
                Text("Do you want to copy the bookmark history into the duplicated connection?")
            }
            .modifier(ChangeHandlers(
                connectionStore: connectionStore,
                projectStore: projectStore,
                selectedSection: $selectedSection,
                sidebarSelection: $sidebarSelection,
                pendingConnectionMove: $pendingConnectionMove,
                pendingIdentityMove: $pendingIdentityMove,
                filteredConnectionsForTable: filteredConnectionsForTable,
                filteredIdentitiesForTable: filteredIdentitiesForTable,
                onProjectChange: resetForProjectChange,
                onSectionChange: handleSectionChange,
                onSidebarSelectionChange: handleSidebarSelectionChange,
                onFolderIDChange: syncSidebarSelection,
                onConnectionsChange: { pruneConnectionSelection(allowedIDs: Set($0)) },
                onIdentitiesChange: { pruneIdentitySelection(allowedIDs: Set($0)) },
                onFoldersChange: handleFoldersChange
            ))
    }

    private var configuredSplitView: some View {
        splitView
            .frame(minWidth: 900, minHeight: 600)
    }

    private var splitView: some View {
        NavigationSplitView {
            sidebar
                .frame(minWidth: 220, idealWidth: 260, maxWidth: 300)
#if os(macOS)
                .toolbar(removing: .sidebarToggle)
#endif
        } detail: {
            detailContent
        }
#if os(macOS)
        .navigationSplitViewStyle(.balanced)
#endif
    }

    private var detailContent: some View {
        detailBody
            .background(themeManager.surfaceBackgroundColor)
            .accentColor(themeManager.accentColor)
            .searchable(
                text: $searchText,
                placement: .toolbar,
                prompt: Text(activeSection.searchPlaceholder)
            )
            .toolbar {
                ToolbarItem(placement: .principal) {
                    ToolbarTitleWithSubtitle(
                        title: navigationTitleText,
                        subtitle: navigationSubtitleText
                    )
                }
                ToolbarItem(placement: .primaryAction) {
                    addToolbarMenu
                }
            }
    }

    private var navigationTitleText: String {
        if case .folder(let folderID, _) = sidebarSelection,
           let folder = folder(withID: folderID) {
            return folder.displayName
        }
        return activeSection.title
    }

    private var navigationSubtitleText: String {
        if case .folder(_, _) = sidebarSelection {
            return activeSection.title
        }
        return ""
    }

    @ViewBuilder
    private var addToolbarMenu: some View {
        Menu {
            switch activeSection {
            case .connections:
                Button {
                    handlePrimaryAdd(for: .connections)
                } label: {
                    Label("New Connection", systemImage: "externaldrive.badge.plus")
                }
                Button {
                    presentCreateFolder(for: .connections)
                } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
            case .identities:
                Button {
                    handlePrimaryAdd(for: .identities)
                } label: {
                    Label("New Identity", systemImage: "person.crop.circle.badge.plus")
                }
                Button {
                    presentCreateFolder(for: .identities)
                } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
            }
        } label: {
            ToolbarAddButton()
        }
        .menuIndicator(.hidden)
        .menuStyle(.borderlessButton)
        .controlSize(.large)
        .help(activeSection == .connections ? "Add connection or folder" : "Add identity or folder")
    }

    var deletionAlertBinding: Binding<Bool> {
        Binding(
            get: { pendingDeletion != nil },
            set: { isPresented in
                if !isPresented { pendingDeletion = nil }
            }
        )
    }

    @ViewBuilder
    func folderEditorSheet(_ state: FolderEditorState) -> some View {
        FolderEditorSheet(state: state)
            .environmentObject(appModel)
    }

    @ViewBuilder
    func identityEditorSheet(_ state: IdentityEditorState) -> some View {
        IdentityEditorSheet(state: state)
            .environmentObject(appModel)
    }

    @ViewBuilder
    func connectionEditorSheet(_ presentation: ConnectionEditorPresentation) -> some View {
        ConnectionEditorView(connection: presentation.connection) { connection, password, action in
            handleConnectionEditorSave(connection: connection, password: password, action: action)
        }
        .environment(projectStore)
        .environment(connectionStore)
        .environment(navigationStore)
        .environmentObject(appModel)
        .environmentObject(appState)
    }

    @ViewBuilder
    func deletionAlertActions(target: DeletionTarget) -> some View {
        Button("Delete", role: .destructive) { performDeletion(for: target) }
        Button("Cancel", role: .cancel) { pendingDeletion = nil }
    }

    @ViewBuilder
    func deletionAlertMessage(target: DeletionTarget) -> some View {
        Text("Are you sure you want to delete \(target.displayName)? This action cannot be undone.")
    }

    internal var selectedProjectID: UUID? {
        projectStore.selectedProject?.id
    }

    internal var projectConnections: [SavedConnection] {
        connectionStore.connections.filter { $0.projectID == selectedProjectID }
    }

    internal var projectIdentities: [SavedIdentity] {
        connectionStore.identities.filter { $0.projectID == selectedProjectID }
    }

    internal var connectionFolders: [SavedFolder] {
        connectionStore.folders.filter { $0.kind == .connections && $0.projectID == selectedProjectID }
    }

    internal var identityFolders: [SavedFolder] {
        connectionStore.folders.filter { $0.kind == .identities && $0.projectID == selectedProjectID }
    }

    internal var connectionFolderNodes: [FolderNode] {
        buildFolderNodes(
            from: connectionFolders.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending },
            itemMap: Dictionary(grouping: projectConnections, by: { $0.folderID })
        )
    }

    internal var identityFolderNodes: [FolderNode] {
        buildFolderNodes(
            from: identityFolders.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending },
            itemMap: Dictionary(grouping: projectIdentities, by: { $0.folderID })
        )
    }

    internal var identityLookup: [UUID: SavedIdentity] {
        Dictionary(uniqueKeysWithValues: projectIdentities.map { ($0.id, $0) })
    }

    internal var normalizedQuery: String? {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed.lowercased()
    }

    internal var filteredConnectionsForTable: [SavedConnection] {
        var items = projectConnections

        if let folderID = activeFolderID(for: .connections) {
            let scope = folderScope(for: folderID, in: .connections)
            items = items.filter { connection in
                guard let id = connection.folderID else { return false }
                return scope.contains(id)
            }
        }

        if let query = normalizedQuery {
            items = items.filter { connectionMatches($0, query: query) }
        }

        return items.sorted(using: connectionSortOrder)
    }

    internal var filteredIdentitiesForTable: [SavedIdentity] {
        var items = projectIdentities

        if let folderID = activeFolderID(for: .identities) {
            let scope = folderScope(for: folderID, in: .identities)
            items = items.filter { identity in
                guard let id = identity.folderID else { return false }
                return scope.contains(id)
            }
        }

        if let query = normalizedQuery {
            items = items.filter { identityMatches($0, query: query) }
        }

        return items.sorted(using: identitySortOrder)
    }

    internal func connectionMatches(_ connection: SavedConnection, query: String) -> Bool {
        if connection.connectionName.lowercased().contains(query) { return true }
        if connection.host.lowercased().contains(query) { return true }
        if connection.database.lowercased().contains(query) { return true }
        if connection.username.lowercased().contains(query) { return true }
        if let identityID = connection.identityID,
           let identity = identityLookup[identityID],
           identity.name.lowercased().contains(query) {
            return true
        }
        return false
    }

    internal func identityMatches(_ identity: SavedIdentity, query: String) -> Bool {
        if identity.name.lowercased().contains(query) { return true }
        if identity.username.lowercased().contains(query) { return true }
        return false
    }

    internal func folderLookup(for section: ManageSection) -> [UUID: SavedFolder] {
        let folders = section == .connections ? connectionFolders : identityFolders
        return Dictionary(uniqueKeysWithValues: folders.map { ($0.id, $0) })
    }

    internal func buildFolderNodes<Item>(
        from folders: [SavedFolder],
        itemMap: [UUID?: [Item]]
    ) -> [FolderNode] {
        let grouped = Dictionary(grouping: folders, by: { $0.parentFolderID })

        func makeNodes(parent: UUID?) -> [FolderNode] {
            guard let items = grouped[parent] else { return [] }

            return items.map { folder in
                let children = makeNodes(parent: folder.id)
                return FolderNode(folder: folder, childNodes: children.isEmpty ? nil : children)
            }
        }

        return makeNodes(parent: nil)
    }

    internal func activeFolderID(for section: ManageSection) -> UUID? {
        guard let selection = sidebarSelection else { return nil }
        switch selection {
        case .section(let targetSection):
            return nil
        case .folder(let folderID, let targetSection):
            return targetSection == section ? folderID : nil
        }
    }

    internal func folderScope(for folderID: UUID, in section: ManageSection) -> Set<UUID> {
        var scope: Set<UUID> = [folderID]
        let folders = section == .connections ? connectionFolders : identityFolders
        var stack: [UUID] = [folderID]

        while let current = stack.popLast() {
            let children = folders.filter { $0.parentFolderID == current }
            for child in children {
                if scope.insert(child.id).inserted {
                    stack.append(child.id)
                }
            }
        }

        return scope
    }

    internal func folder(withID id: UUID) -> SavedFolder? {
        connectionStore.folders.first(where: { $0.id == id })
    }
}

private struct ChangeHandlers: ViewModifier {
    let connectionStore: ConnectionStore
    let projectStore: ProjectStore
    @Binding var selectedSection: ManageSection?
    @Binding var sidebarSelection: SidebarSelection?
    @Binding var pendingConnectionMove: SavedConnection?
    @Binding var pendingIdentityMove: SavedIdentity?
    
    let filteredConnectionsForTable: [SavedConnection]
    let filteredIdentitiesForTable: [SavedIdentity]
    
    let onProjectChange: () -> Void
    let onSectionChange: (ManageSection) -> Void
    let onSidebarSelectionChange: (SidebarSelection?) -> Void
    let onFolderIDChange: (UUID?) -> Void
    let onConnectionsChange: ([SavedConnection.ID]) -> Void
    let onIdentitiesChange: ([SavedIdentity.ID]) -> Void
    let onFoldersChange: ([SavedFolder], [SavedFolder]) -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: projectStore.selectedProject) { _, _ in onProjectChange() }
            .onChange(of: selectedSection) { _, newValue in
                if let section = newValue { onSectionChange(section) }
            }
            .onChange(of: sidebarSelection) { _, newValue in onSidebarSelectionChange(newValue) }
            .onChange(of: connectionStore.selectedFolderID) { _, newValue in onFolderIDChange(newValue) }
            .onChange(of: connectionStore.connections) { _, newValue in onConnectionsChange(newValue.map(\.id)) }
            .onChange(of: connectionStore.identities) { _, newValue in onIdentitiesChange(newValue.map(\.id)) }
            .onChange(of: connectionStore.folders) { oldValue, newValue in onFoldersChange(oldValue, newValue) }
    }
}
