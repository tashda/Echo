import SwiftUI
import AppKit

struct ManageConnectionsView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    private let onClose: (() -> Void)?

    @State private var selectedSection: ManageSection? = .connections
    @State private var sidebarSelection: SidebarSelection? = .section(.connections)
    @State private var searchText = ""
    @State private var folderEditorState: FolderEditorState?
    @State private var identityEditorState: IdentityEditorState?
    @State private var pendingDeletion: DeletionTarget?
    @State private var connectionEditorPresentation: ConnectionEditorPresentation?
    @State private var pendingDuplicateConnection: SavedConnection?
    @State private var pendingConnectionMove: SavedConnection?
    @State private var pendingIdentityMove: SavedIdentity?
    @State private var connectionSelection = Set<SavedConnection.ID>()
    @State private var identitySelection = Set<SavedIdentity.ID>()
    @State private var connectionSortOrder: [KeyPathComparator<SavedConnection>] = [
        .init(\.connectionName, order: .forward)
    ]
    @State private var identitySortOrder: [KeyPathComparator<SavedIdentity>] = [
        .init(\.name, order: .forward)
    ]

    @State private var expandedSections: Set<ManageSection> = [.connections, .identities]

    init(onClose: (() -> Void)? = nil) {
        self.onClose = onClose
    }

    private var activeSection: ManageSection { selectedSection ?? .connections }

    var body: some View {
        contentView
            .onAppear(perform: ensureSectionSelection)
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
                appModel: appModel,
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
        } detail: {
            detailContent
        }
#if os(macOS)
        .toolbar(.hidden, for: .windowToolbar)
        .toolbar(removing: .sidebarToggle)
        .toolbarRole(.editor)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                EmptyView()
            }
        }
        .ignoresSafeArea(edges: .top)
#endif
    }
}

// MARK: - Layout

private extension ManageConnectionsView {
    var detailContent: some View {
        detailBody
            .padding(.top, headerOverlayHeight)
            .background(themeManager.surfaceBackgroundColor)
            .accentColor(themeManager.accentColor)
            .ignoresSafeArea(edges: .top)
#if os(macOS)
            .toolbar(removing: .sidebarToggle)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    EmptyView()
                }
            }
#endif
            .overlay(alignment: .top) {
                VStack(spacing: 0) {
                    detailHeader
                    Divider()
                }
                .background(themeManager.surfaceBackgroundColor)
                .ignoresSafeArea(edges: .top)
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

    private var detailHeader: some View {
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(navigationTitleText)
                    .font(.system(size: titleFontSize, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                if navigationSubtitleText.isEmpty {
                    Text("placeholder")
                        .font(.system(size: 12))
                        .foregroundStyle(.clear)
                        .accessibilityHidden(true)
                        .lineLimit(1)
                } else {
                    Text(navigationSubtitleText)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)

            Spacer(minLength: 12)

            HStack(spacing: 10) {
                addMenuToolbarItem
                detailSearchField
            }
            .frame(height: controlAreaHeight, alignment: .bottom)
        }
        .frame(height: headerCoreHeight, alignment: .bottom)
        .padding(.horizontal, headerHorizontalPadding)
        .padding(.top, headerTopPadding)
        .padding(.bottom, headerBottomPadding)
    }

    @ViewBuilder
    private var detailSearchField: some View {
#if os(macOS)
        ManageConnectionsSearchField(text: $searchText, placeholder: activeSection.searchPlaceholder)
            .frame(width: searchFieldWidth, height: searchFieldHeight)
#else
        TextField(activeSection.searchPlaceholder, text: $searchText, prompt: Text(activeSection.searchPlaceholder))
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 280)
#endif
    }

    private var headerCoreHeight: CGFloat { 44 }
    private var headerTopPadding: CGFloat { 16 }
    private var headerBottomPadding: CGFloat { 14 }
    private var headerHorizontalPadding: CGFloat { 24 }
    private var controlAreaHeight: CGFloat { 32 }
    private var searchFieldWidth: CGFloat { 260 }
    private var searchFieldHeight: CGFloat { 30 }
    private var titleFontSize: CGFloat { 24 }
    private var headerOverlayHeight: CGFloat { headerTopPadding + headerCoreHeight + headerBottomPadding + 1 }

    @ViewBuilder
    private var addMenuToolbarItem: some View {
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
            addButtonLabel
        }
        .menuIndicator(.hidden)
        .menuStyle(.borderlessButton)
        .help(activeSection == .connections ? "Add connection or folder" : "Add identity or folder")
    }

    private var addButtonLabel: some View {
        RoundAddButtonLabel(themeManager: themeManager)
    }

    @ViewBuilder
    var sidebar: some View {
        sidebarList
    }

    @ViewBuilder
    private var sidebarList: some View {
        List(selection: $sidebarSelection) {
            ForEach(ManageSection.allCases) { section in
                sidebarSection(
                    section,
                    nodes: section == .connections ? connectionFolderNodes : identityFolderNodes,
                    totalCount: totalCount(for: section)
                )
            }
        }
        .listStyle(.sidebar)
#if os(macOS)
        .scrollContentBackground(.hidden)
        .background(themeManager.surfaceBackgroundColor)
#endif
    }

    @ViewBuilder
    func sidebarSection(
        _ section: ManageSection,
        nodes: [FolderNode],
        totalCount: Int
    ) -> some View {
        DisclosureGroup(isExpanded: binding(for: section)) {
            OutlineGroup(nodes, children: \.childNodes) { node in
                sidebarFolderLink(node: node, section: section)
            }
        } label: {
            NavigationLink(value: SidebarSelection.section(section)) {
                HStack(spacing: 6) {
                    Image(systemName: section.icon)
                    Text(section.title)
                }
            }
            .tag(SidebarSelection.section(section))
            .contextMenu {
                switch section {
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
            }
        }
    }

    @ViewBuilder
    func sidebarFolderLink(node: FolderNode, section: ManageSection) -> some View {
        NavigationLink(value: SidebarSelection.folder(node.folder.id, section)) {
            HStack(spacing: 6) {
                Image(systemName: "folder")
                Text(node.folder.displayName)
            }
        }
        .tag(SidebarSelection.folder(node.folder.id, section))
        .contextMenu {
            Button {
                createNewFolder(for: section, parent: node.folder)
            } label: {
                Text("New Subfolder")
            }

            Button {
                editFolder(node.folder)
            } label: {
                Text("Edit")
            }

            Divider()

            Button("Delete", role: .destructive) {
                handleDeletion(.folder(node.folder))
            }
        }
        .dropDestination(for: String.self) { items, location in
            if section == .connections {
                return handleConnectionDrop(items: items, folder: node.folder)
            } else {
                return handleIdentityDrop(items: items, folder: node.folder)
            }
        }
    }

    func totalCount(for section: ManageSection) -> Int {
        switch section {
        case .connections: return projectConnections.count
        case .identities: return projectIdentities.count
        }
    }

    func binding(for section: ManageSection) -> Binding<Bool> {
        Binding(
            get: { expandedSections.contains(section) },
            set: { isExpanded in
                if isExpanded {
                    expandedSections.insert(section)
                } else {
                    expandedSections.remove(section)
                }
            }
        )
    }

    @ViewBuilder
    var connectionsDetail: some View {
        if filteredConnectionsForTable.isEmpty {
            emptyState(for: .connections)
        } else {
            ConnectionsTableView(
                connections: filteredConnectionsForTable,
                selection: $connectionSelection,
                sortOrder: $connectionSortOrder,
                folderLookup: folderLookup(for: .connections),
                onConnect: connectToConnection,
                onEdit: editConnection,
                onDuplicate: duplicateConnection,
                onDelete: { handleDeletion(.connection($0)) },
                identityDecorationProvider: identityDecoration(for:),
                onDoubleClick: connectToConnection,
                moveConnectionToFolder: moveConnectionToFolder,
                createFolderAndMoveConnection: createFolderAndMoveConnection
            )
        }
    }

    @ViewBuilder
    var identitiesDetail: some View {
        if filteredIdentitiesForTable.isEmpty {
            emptyState(for: .identities)
        } else {
            IdentitiesTableView(
                identities: filteredIdentitiesForTable,
                selection: $identitySelection,
                sortOrder: $identitySortOrder,
                folderLookup: folderLookup(for: .identities),
                onEdit: editIdentity,
                onDelete: { handleDeletion(.identity($0)) },
                moveIdentityToFolder: moveIdentityToFolder,
                createFolderAndMoveIdentity: createFolderAndMoveIdentity
            )
        }
    }

    @ViewBuilder
    func emptyState(for section: ManageSection) -> some View {
        VStack(spacing: 14) {
            Image(systemName: section == .connections ? "externaldrive.badge.plus" : "person.crop.circle.badge.plus")
                .font(.system(size: 40, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(themeManager.accentColor)

            Text(section.emptyTitle)
                .font(.system(size: 18, weight: .semibold))

            Text(section.emptyMessage)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            Button {
                handlePrimaryAdd(for: section)
            } label: {
                Label(section.emptyActionTitle, systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeManager.surfaceBackgroundColor)
    }
}

// MARK: - Sheets & Alerts

private extension ManageConnectionsView {
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
}

// MARK: - Selection & Sync

private extension ManageConnectionsView {
    func handlePrimaryAdd(for section: ManageSection) {
        switch section {
        case .connections:
            createNewConnection()
        case .identities:
            createNewIdentity()
        }
    }

    func handleSectionChange(_ section: ManageSection) {
        searchText = ""
        if section == .connections {
            appModel.selectedIdentityID = nil
        }

        let target: SidebarSelection = .section(section)
        if sidebarSelection != target {
            sidebarSelection = target
        }
    }

    func handleSidebarSelectionChange(_ selection: SidebarSelection?) {
        guard let selection else { return }

        if selectedSection != selection.section {
            selectedSection = selection.section
        }

        switch selection {
        case .section:
            if appModel.selectedFolderID != nil {
                appModel.selectedFolderID = nil
            }
        case .folder(let folderID, _):
            if appModel.selectedFolderID != folderID {
                appModel.selectedFolderID = folderID
            }
        }
    }

    func syncSidebarSelection(withFolderID folderID: UUID?) {
        guard let folderID,
              let folder = folder(withID: folderID) else {
            let section = selectedSection ?? .connections
            let target: SidebarSelection = .section(section)
            if sidebarSelection != target {
                sidebarSelection = target
            }
            return
        }

        let section = folder.kind.manageSection
        if selectedSection != section {
            selectedSection = section
        }

        let target: SidebarSelection = .folder(folder.id, section)
        if sidebarSelection != target {
            sidebarSelection = target
        }
    }

    func pruneConnectionSelection(allowedIDs: Set<UUID>) {
        let invalid = connectionSelection.filter { !allowedIDs.contains($0) }
        if !invalid.isEmpty {
            connectionSelection.subtract(invalid)
        }
    }

    func pruneIdentitySelection(allowedIDs: Set<UUID>) {
        let invalid = identitySelection.filter { !allowedIDs.contains($0) }
        if !invalid.isEmpty {
            identitySelection.subtract(invalid)
        }
    }

    func resetForProjectChange() {
        searchText = ""
        pendingDeletion = nil
        connectionEditorPresentation = nil
        folderEditorState = nil
        identityEditorState = nil
        connectionSelection.removeAll()
        identitySelection.removeAll()
        selectedSection = .connections
        sidebarSelection = .section(.connections)
        pruneNavigationStacks()
        ensureSectionSelection()
    }

    func pruneNavigationStacks() {
        guard let projectID = selectedProjectID else {
            appModel.selectedFolderID = nil
            appModel.selectedIdentityID = nil
            appModel.selectedConnectionID = nil
            return
        }

        if let folderID = appModel.selectedFolderID,
           !appModel.folders.contains(where: { $0.id == folderID && $0.projectID == projectID }) {
            appModel.selectedFolderID = nil
        }

        if let identityID = appModel.selectedIdentityID,
           !appModel.identities.contains(where: { $0.id == identityID && $0.projectID == projectID }) {
            appModel.selectedIdentityID = nil
        }

        if let connectionID = appModel.selectedConnectionID,
           !appModel.connections.contains(where: { $0.id == connectionID && $0.projectID == projectID }) {
            appModel.selectedConnectionID = nil
        }

        syncSidebarSelection(withFolderID: appModel.selectedFolderID)
    }

    func ensureSectionSelection() {
        if selectedSection == nil {
            if let identityID = appModel.selectedIdentityID,
               appModel.identities.contains(where: { $0.id == identityID }) {
                selectedSection = .identities
            } else {
                selectedSection = .connections
            }
        }

        if sidebarSelection == nil {
            if let folderID = appModel.selectedFolderID {
                syncSidebarSelection(withFolderID: folderID)
            } else if let section = selectedSection {
                sidebarSelection = .section(section)
            } else {
                sidebarSelection = .section(.connections)
            }
        }

        if connectionSelection.isEmpty,
           let id = appModel.selectedConnectionID,
           filteredConnectionsForTable.contains(where: { $0.id == id }) {
            connectionSelection = [id]
        }

        if identitySelection.isEmpty,
           let id = appModel.selectedIdentityID,
           filteredIdentitiesForTable.contains(where: { $0.id == id }) {
            identitySelection = [id]
        }
    }
}

// MARK: - Data

private extension ManageConnectionsView {
    var selectedProjectID: UUID? {
        appModel.selectedProject?.id
    }

    var projectConnections: [SavedConnection] {
        appModel.connections.filter { $0.projectID == selectedProjectID }
    }

    var projectIdentities: [SavedIdentity] {
        appModel.identities.filter { $0.projectID == selectedProjectID }
    }

    var connectionFolders: [SavedFolder] {
        appModel.folders.filter { $0.kind == .connections && $0.projectID == selectedProjectID }
    }

    var identityFolders: [SavedFolder] {
        appModel.folders.filter { $0.kind == .identities && $0.projectID == selectedProjectID }
    }

    var connectionFolderNodes: [FolderNode] {
        buildFolderNodes(
            from: connectionFolders.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending },
            itemMap: Dictionary(grouping: projectConnections, by: { $0.folderID })
        )
    }

    var identityFolderNodes: [FolderNode] {
        buildFolderNodes(
            from: identityFolders.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending },
            itemMap: Dictionary(grouping: projectIdentities, by: { $0.folderID })
        )
    }

    var identityLookup: [UUID: SavedIdentity] {
        Dictionary(uniqueKeysWithValues: projectIdentities.map { ($0.id, $0) })
    }

    var normalizedQuery: String? {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed.lowercased()
    }

    var filteredConnectionsForTable: [SavedConnection] {
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

    var filteredIdentitiesForTable: [SavedIdentity] {
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

    func connectionMatches(_ connection: SavedConnection, query: String) -> Bool {
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

    func identityMatches(_ identity: SavedIdentity, query: String) -> Bool {
        if identity.name.lowercased().contains(query) { return true }
        if identity.username.lowercased().contains(query) { return true }
        return false
    }

    func folderLookup(for section: ManageSection) -> [UUID: SavedFolder] {
        let folders = section == .connections ? connectionFolders : identityFolders
        return Dictionary(uniqueKeysWithValues: folders.map { ($0.id, $0) })
    }

    func buildFolderNodes<Item>(
        from folders: [SavedFolder],
        itemMap: [UUID?: [Item]]
    ) -> [FolderNode] {
        let grouped = Dictionary(grouping: folders, by: { $0.parentFolderID })

        func makeNodes(parent: UUID?) -> [FolderNode] {
            guard let items = grouped[parent] else { return [] }

            return items.map { folder in
                let children = makeNodes(parent: folder.id)
                let childCount = children.reduce(0) { $0 + $1.totalItemCount }
                let directCount = itemMap[folder.id]?.count ?? 0
                return FolderNode(folder: folder, children: children, totalItemCount: directCount + childCount)
            }
        }

        return makeNodes(parent: nil)
    }

    func activeFolderID(for section: ManageSection) -> UUID? {
        guard let selection = sidebarSelection else { return nil }
        switch selection {
        case .section(let targetSection):
            return targetSection == section ? nil : nil
        case .folder(let folderID, let targetSection):
            return targetSection == section ? folderID : nil
        }
    }

    func folderScope(for folderID: UUID, in section: ManageSection) -> Set<UUID> {
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

    func folder(withID id: UUID) -> SavedFolder? {
        appModel.folders.first(where: { $0.id == id })
    }
}

// MARK: - Actions

private extension ManageConnectionsView {
    func handleConnectionEditorSave(
        connection: SavedConnection,
        password: String?,
        action: ConnectionEditorView.SaveAction
    ) {
        Task {
            await appModel.upsertConnection(connection, password: password)

            await MainActor.run {
                selectedSection = .connections
                appModel.selectedFolderID = connection.folderID
                connectionSelection = [connection.id]
                connectionEditorPresentation = nil
            }

            if action == .saveAndConnect {
                await appModel.connect(to: connection)
                await MainActor.run {
                    closeManageConnections()
                }
            }
        }
    }

    func handleDeletion(_ payload: DeletionTarget) {
        pendingDeletion = payload
    }

    func performDeletion(for target: DeletionTarget) {
        switch target {
        case .connection(let connection):
            Task { await appModel.deleteConnection(connection) }
        case .folder(let folder):
            Task { await appModel.deleteFolder(folder) }
        case .identity(let identity):
            Task { await appModel.deleteIdentity(identity) }
        }
        pendingDeletion = nil
    }

    func createNewConnection() {
        selectedSection = .connections
        let parent = currentFolder(for: .connections) ?? defaultFolder(for: .connections)
        appModel.selectedFolderID = parent?.id
        connectionEditorPresentation = ConnectionEditorPresentation(connection: nil)
    }

    func editConnection(_ connection: SavedConnection) {
        selectedSection = .connections
        appModel.selectedFolderID = connection.folderID
        connectionEditorPresentation = ConnectionEditorPresentation(connection: connection)
    }

    func duplicateConnection(_ connection: SavedConnection) {
        pendingDuplicateConnection = connection
    }

    func performDuplicate(_ connection: SavedConnection, copyBookmarks: Bool) {
        Task {
            pendingDuplicateConnection = nil
            await appModel.duplicateConnection(connection, copyBookmarks: copyBookmarks)
        }
    }

    func connectToConnection(_ connection: SavedConnection) {
        Task {
            await appModel.connect(to: connection)
            await MainActor.run {
                closeManageConnections()
            }
        }
    }

    func closeManageConnections() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    func createNewIdentity() {
        selectedSection = .identities
        let parent = currentFolder(for: .identities) ?? defaultFolder(for: .identities)
        identityEditorState = .create(parent: parent, token: UUID())
    }

    func createNewFolder(for section: ManageSection, parent: SavedFolder? = nil) {
        folderEditorState = .create(kind: section.folderKind, parent: parent, token: UUID())
    }

    func presentCreateFolder(for section: ManageSection) {
        let parent = currentFolder(for: section)
        createNewFolder(for: section, parent: parent)
    }

    func editIdentity(_ identity: SavedIdentity) {
        identityEditorState = .edit(identity: identity)
    }

    func editFolder(_ folder: SavedFolder) {
        folderEditorState = .edit(folder: folder)
    }

    func currentFolder(for section: ManageSection) -> SavedFolder? {
        if case .folder(let id, let selectedSection) = sidebarSelection,
           selectedSection == section {
            return folder(withID: id)
        }
        if let folderID = appModel.selectedFolderID,
           let folder = folder(withID: folderID),
           folder.kind.manageSection == section {
            return folder
        }
        return nil
    }

    func defaultFolder(for section: ManageSection) -> SavedFolder? {
        guard let projectID = selectedProjectID else { return nil }

        switch section {
        case .connections:
            if let folderID = appModel.selectedFolderID,
               let folder = folder(withID: folderID),
               folder.projectID == projectID,
               folder.kind == .connections {
                return folder
            }
            if let connectionID = appModel.selectedConnectionID,
               let connection = projectConnections.first(where: { $0.id == connectionID }),
               let folderID = connection.folderID,
               let folder = folder(withID: folderID) {
                return folder
            }
        case .identities:
            if let folderID = appModel.selectedFolderID,
               let folder = folder(withID: folderID),
               folder.projectID == projectID,
               folder.kind == .identities {
                return folder
            }
            if let identityID = appModel.selectedIdentityID,
               let identity = projectIdentities.first(where: { $0.id == identityID }),
               let folderID = identity.folderID,
               let folder = folder(withID: folderID) {
                return folder
            }
        }
        return nil
    }

    func moveConnectionToFolder(_ connection: SavedConnection, _ folder: SavedFolder) {
        var updatedConnection = connection
        updatedConnection.folderID = folder.id
        Task {
            await appModel.upsertConnection(updatedConnection, password: nil)
        }
    }

    func createFolderAndMoveConnection(_ connection: SavedConnection) {
        // Store the connection to move after creating the folder
        pendingConnectionMove = connection
        let parent = currentFolder(for: .connections)
        folderEditorState = .create(
            kind: .connections,
            parent: parent,
            token: UUID()
        )
    }

    func handleFoldersChange(_ oldFolders: [SavedFolder], _ newFolders: [SavedFolder]) {
        pruneNavigationStacks()

        // Check if a new folder was created while we have a pending connection move
        if let pendingConnection = pendingConnectionMove,
           newFolders.count > oldFolders.count,
           let newFolder = newFolders.first(where: { folder in
               !oldFolders.contains(where: { $0.id == folder.id }) && folder.kind == .connections
           }) {
            // Move the connection to the newly created folder
            moveConnectionToFolder(pendingConnection, newFolder)
            pendingConnectionMove = nil
        }

        // Check if a new folder was created while we have a pending identity move
        if let pendingIdentity = pendingIdentityMove,
           newFolders.count > oldFolders.count,
           let newFolder = newFolders.first(where: { folder in
               !oldFolders.contains(where: { $0.id == folder.id }) && folder.kind == .identities
           }) {
            // Move the identity to the newly created folder
            moveIdentityToFolder(pendingIdentity, newFolder)
            pendingIdentityMove = nil
        }
    }

    func handleConnectionDrop(items: [String], folder: SavedFolder) -> Bool {
        // Only allow drops into connection folders
        guard folder.kind == .connections else { return false }

        guard let firstItem = items.first,
              firstItem.hasPrefix("connection:"),
              let connectionID = UUID(uuidString: String(firstItem.dropFirst("connection:".count))),
              let connection = projectConnections.first(where: { $0.id == connectionID }) else {
            return false
        }

        moveConnectionToFolder(connection, folder)
        return true
    }

    func handleIdentityDrop(items: [String], folder: SavedFolder) -> Bool {
        // Only allow drops into identity folders
        guard folder.kind == .identities else { return false }

        guard let firstItem = items.first,
              firstItem.hasPrefix("identity:"),
              let identityID = UUID(uuidString: String(firstItem.dropFirst("identity:".count))),
              let identity = projectIdentities.first(where: { $0.id == identityID }) else {
            return false
        }

        moveIdentityToFolder(identity, folder)
        return true
    }

    func moveIdentityToFolder(_ identity: SavedIdentity, _ folder: SavedFolder) {
        var updatedIdentity = identity
        updatedIdentity.folderID = folder.id
        Task {
            await appModel.upsertIdentity(updatedIdentity, password: nil)
        }
    }

    func createFolderAndMoveIdentity(_ identity: SavedIdentity) {
        pendingIdentityMove = identity
        let parent = currentFolder(for: .identities)
        folderEditorState = .create(
            kind: .identities,
            parent: parent,
            token: UUID()
        )
    }
}

// MARK: - Decorations

private extension ManageConnectionsView {
    func identityDecoration(for connection: SavedConnection) -> IdentityDecoration? {
        switch connection.credentialSource {
        case .identity:
            guard let identityID = connection.identityID,
                  let identity = identityLookup[identityID] else {
                return IdentityDecoration(
                    symbol: "person.fill",
                    label: "Identity",
                    tooltip: "Linked identity"
                )
            }

            var tooltip = identity.name
            let detail = identity.username.trimmingCharacters(in: .whitespacesAndNewlines)
            if !detail.isEmpty {
                tooltip += " — \(detail)"
            }

            return IdentityDecoration(
                symbol: "person.fill",
                label: identity.name,
                tooltip: tooltip
            )

        case .inherit:
            return IdentityDecoration(
                symbol: "arrow.triangle.branch",
                label: "Inherited",
                tooltip: "Inherits credentials"
            )

        case .manual:
            let username = connection.username.trimmingCharacters(in: .whitespacesAndNewlines)
            let tooltip = username.isEmpty ? "Manual credentials" : "Manual credentials — \(username)"
            return IdentityDecoration(
                symbol: "key.fill",
                label: username.isEmpty ? "Manual" : username,
                tooltip: tooltip
            )
        }
    }
}

// MARK: - Supporting Types

private enum ManageSection: String, CaseIterable, Identifiable {
    case connections
    case identities

    var id: String { rawValue }

    var title: String {
        switch self {
        case .connections: return "Connections"
        case .identities: return "Identities"
        }
    }

    var icon: String {
        switch self {
        case .connections: return "externaldrive"
        case .identities: return "person.crop.circle"
        }
    }

    var folderKind: FolderKind {
        switch self {
        case .connections: return .connections
        case .identities: return .identities
        }
    }

    var emptyTitle: String {
        switch self {
        case .connections: return "No Connections"
        case .identities: return "No Identities"
        }
    }

    var emptyMessage: String {
        switch self {
        case .connections: return "Create a connection to start exploring your databases."
        case .identities: return "Create identities to reuse credentials across multiple connections."
        }
    }

    var emptyActionTitle: String {
        switch self {
        case .connections: return "New Connection"
        case .identities: return "New Identity"
        }
    }

    var primaryAddHelp: String {
        switch self {
        case .connections: return "Create a new connection"
        case .identities: return "Create a new identity"
        }
    }

    var createFolderHelp: String {
        switch self {
        case .connections: return "Create a new connection folder"
        case .identities: return "Create a new identity folder"
        }
    }

    var createFolderTitle: String {
        switch self {
        case .connections: return "New Folder"
        case .identities: return "New Folder"
        }
    }

    var searchPlaceholder: String {
        switch self {
        case .connections: return "Search connections"
        case .identities: return "Search identities"
        }
    }
}

private enum SidebarSelection: Hashable, Identifiable {
    case section(ManageSection)
    case folder(UUID, ManageSection)

    var id: String {
        switch self {
        case .section(let section):
            return "section-\(section.id)"
        case .folder(let id, let section):
            return "folder-\(section.id)-\(id.uuidString)"
        }
    }

    var section: ManageSection {
        switch self {
        case .section(let section):
            return section
        case .folder(_, let section):
            return section
        }
    }
}

private struct FolderNode: Identifiable, Hashable {
    let folder: SavedFolder
    var children: [FolderNode]
    var totalItemCount: Int

    var id: UUID { folder.id }

    var childNodes: [FolderNode]? {
        children.isEmpty ? nil : children
    }
}

private struct IdentityDecoration {
    let symbol: String
    let label: String
    let tooltip: String?
}

private struct ConnectionEditorPresentation: Identifiable {
    let id = UUID()
    let connection: SavedConnection?
}

private extension FolderKind {
    var manageSection: ManageSection {
        switch self {
        case .connections: return .connections
        case .identities: return .identities
        }
    }
}

private extension SavedFolder {
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Folder" : trimmed
    }
}

// MARK: - Table Views

private struct ConnectionsTableView: View {
    let connections: [SavedConnection]
    @Binding var selection: Set<SavedConnection.ID>
    @Binding var sortOrder: [KeyPathComparator<SavedConnection>]
    let folderLookup: [UUID: SavedFolder]
    let onConnect: (SavedConnection) -> Void
    let onEdit: (SavedConnection) -> Void
    let onDuplicate: (SavedConnection) -> Void
    let onDelete: (SavedConnection) -> Void
    let identityDecorationProvider: (SavedConnection) -> IdentityDecoration?
    let onDoubleClick: (SavedConnection) -> Void
    let moveConnectionToFolder: (SavedConnection, SavedFolder) -> Void
    let createFolderAndMoveConnection: (SavedConnection) -> Void
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        DoubleClickableTable(
            connections: connections,
            selection: $selection,
            onDoubleClick: onDoubleClick
        ) {
            Table(of: SavedConnection.self, selection: $selection, sortOrder: $sortOrder) {
                TableColumn("") { connection in
                    ConnectionIconCell(connection: connection)
                }
                .width(28)

                TableColumn("Name", value: \.connectionName) { connection in
                    Text(displayName(for: connection))
                }

                TableColumn("Server") { connection in
                    Text(serverLabel(for: connection))
                }

                TableColumn("Database", value: \.database) { connection in
                    Text(connection.database.isEmpty ? "—" : connection.database)
                }

                TableColumn("Credentials") { connection in
                    if let decoration = identityDecorationProvider(connection) {
                        Label {
                            Text(decoration.label)
                        } icon: {
                            Image(systemName: decoration.symbol)
                        }
                        .foregroundStyle(.secondary)
                        .help(decoration.tooltip ?? decoration.label)
                    } else {
                        Text("—")
                            .foregroundStyle(.secondary)
                    }
                }

                TableColumn("Folder") { connection in
                    if let folderID = connection.folderID,
                       let folder = folderLookup[folderID] {
                        Text(folder.displayName)
                    } else {
                        Text("—")
                            .foregroundStyle(.secondary)
                    }
                }

                TableColumn("Type") { connection in
                    Text(connection.databaseType.displayName)
                }
            } rows: {
                ForEach(connections) { connection in
                    TableRow(connection)
                        .itemProvider {
                            NSItemProvider(object: "connection:\(connection.id.uuidString)" as NSString)
                        }
                }
            }
            .contextMenu(forSelectionType: SavedConnection.ID.self) { items in
                if let selectionID = items.first,
                   let connection = connections.first(where: { $0.id == selectionID }) {
                    Button {
                        onConnect(connection)
                    } label: {
                        Text("Connect")
                    }

                    Button {
                        onEdit(connection)
                    } label: {
                        Text("Edit")
                    }

                    Button {
                        onDuplicate(connection)
                    } label: {
                        Text("Duplicate")
                    }

                    Menu("Move to Folder") {
                        ForEach(Array(folderLookup.values).sorted(by: { $0.name < $1.name }), id: \.id) { folder in
                            Button(folder.displayName) {
                                moveConnectionToFolder(connection, folder)
                            }
                        }
                        Divider()
                        Button("Create New Folder...") {
                            createFolderAndMoveConnection(connection)
                        }
                    }

                    Divider()
                    Button("Delete", role: .destructive) { onDelete(connection) }
                }
            }
        }
        .background(themeManager.surfaceBackgroundColor)
    }

    private func displayName(for connection: SavedConnection) -> String {
        let trimmed = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? connection.host : trimmed
    }

    private func serverLabel(for connection: SavedConnection) -> String {
        if connection.port > 0 {
            return "\(connection.host):\(connection.port)"
        }
        return connection.host.isEmpty ? "—" : connection.host
    }
}

private struct ConnectionIconCell: View {
    let connection: SavedConnection

    var body: some View {
        iconView
            .frame(width: 20, height: 20)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var iconView: some View {
        if let (image, isTemplate) = iconInfo {
            if isTemplate {
                image
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.primary)
            } else {
                image
                    .renderingMode(.original)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        } else {
            fallbackIcon
        }
    }

    private var fallbackIcon: some View {
        Image(systemName: "externaldrive")
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundStyle(.primary)
    }

    private var iconInfo: (Image, Bool)? {
#if canImport(AppKit)
        if let nsImage = NSImage(named: connection.databaseType.iconName) {
            return (Image(nsImage: nsImage), nsImage.isTemplate)
        }
#elseif canImport(UIKit)
        if let uiImage = UIImage(named: connection.databaseType.iconName) {
            let isTemplate = uiImage.renderingMode == .alwaysTemplate || uiImage.isSymbolImage
            let rendered = uiImage.withRenderingMode(isTemplate ? .alwaysTemplate : .alwaysOriginal)
            return (Image(uiImage: rendered), isTemplate)
        }
#endif
        return nil
    }
}

private struct IdentityIconCell: View {
    let identity: SavedIdentity

    var body: some View {
        Image(systemName: "person.crop.circle.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(Color.primary)
            .frame(width: 20, height: 20)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityHidden(true)
    }
}

private struct IdentitiesTableView: View {
    let identities: [SavedIdentity]
    @Binding var selection: Set<SavedIdentity.ID>
    @Binding var sortOrder: [KeyPathComparator<SavedIdentity>]
    let folderLookup: [UUID: SavedFolder]
    let onEdit: (SavedIdentity) -> Void
    let onDelete: (SavedIdentity) -> Void
    let moveIdentityToFolder: (SavedIdentity, SavedFolder) -> Void
    let createFolderAndMoveIdentity: (SavedIdentity) -> Void
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        ThemedTableContainer {
            Table(of: SavedIdentity.self, selection: $selection, sortOrder: $sortOrder) {
                TableColumn("") { identity in
                    IdentityIconCell(identity: identity)
                }
                .width(28)

                TableColumn("Name", value: \.name) { identity in
                    HStack(spacing: 6) {
                        Text(identity.name)
                        Spacer(minLength: 0)
                    }
                }

                TableColumn("Username", value: \.username) { identity in
                    let username = identity.username.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !username.isEmpty {
                        HStack(spacing: 6) {
                            Text(username)
                            Spacer(minLength: 0)
                        }
                    } else {
                        HStack(spacing: 6) {
                            Text("—")
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 0)
                        }
                    }
                }

                TableColumn("Folder") { identity in
                    if let folderID = identity.folderID,
                       let folder = folderLookup[folderID] {
                        HStack(spacing: 6) {
                            Text(folder.displayName)
                            Spacer(minLength: 0)
                        }
                    } else {
                        HStack(spacing: 6) {
                            Text("—")
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 0)
                        }
                    }
                }

                TableColumn("Updated") { identity in
                    if let updatedAt = identity.updatedAt {
                        HStack(spacing: 6) {
                            Text(updatedAt, style: .date)
                            Spacer(minLength: 0)
                        }
                    } else {
                        HStack(spacing: 6) {
                            Text(identity.createdAt, style: .date)
                            Spacer(minLength: 0)
                        }
                    }
                }

            } rows: {
                ForEach(identities) { identity in
                    TableRow(identity)
                        .itemProvider {
                            NSItemProvider(object: "identity:\(identity.id.uuidString)" as NSString)
                        }
                }
            }
            .contextMenu {
                if let selectionID = selection.first,
                   let identity = identities.first(where: { $0.id == selectionID }) {
                    Button {
                        onEdit(identity)
                    } label: {
                        Text("Edit")
                    }

                    Menu("Move to Folder") {
                        ForEach(Array(folderLookup.values).sorted(by: { $0.name < $1.name }), id: \.id) { folder in
                            Button(folder.displayName) {
                                moveIdentityToFolder(identity, folder)
                            }
                        }
                        Divider()
                        Button("Create New Folder...") {
                            createFolderAndMoveIdentity(identity)
                        }
                    }

                    Divider()

                    Button("Delete", role: .destructive) { onDelete(identity) }
                }
            }
        }
    }
}

private extension ManageConnectionsView {
    @ViewBuilder
    var detailBody: some View {
        switch activeSection {
        case .connections:
            connectionsDetail
        case .identities:
            identitiesDetail
        }
    }

    private var selectedConnection: SavedConnection? {
        guard let selectedID = connectionSelection.first else { return nil }
        return filteredConnectionsForTable.first(where: { $0.id == selectedID })
    }
}

// MARK: - Change Handlers

private struct ChangeHandlers: ViewModifier {
    let appModel: AppModel
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
    let onConnectionsChange: ([UUID]) -> Void
    let onIdentitiesChange: ([UUID]) -> Void
    let onFoldersChange: ([SavedFolder], [SavedFolder]) -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: appModel.selectedProject?.id) { _, _ in
                onProjectChange()
            }
            .onChange(of: selectedSection) { _, section in
                if let section { onSectionChange(section) }
            }
            .onChange(of: sidebarSelection) { _, selection in
                onSidebarSelectionChange(selection)
            }
            .onChange(of: appModel.selectedFolderID) { _, folderID in
                onFolderIDChange(folderID)
            }
            .onChange(of: filteredConnectionsForTable.map(\.id)) { _, ids in
                onConnectionsChange(ids)
            }
            .onChange(of: filteredIdentitiesForTable.map(\.id)) { _, ids in
                onIdentitiesChange(ids)
            }
            .onChange(of: appModel.folders) { oldFolders, newFolders in
                onFoldersChange(oldFolders, newFolders)
            }
    }
}

#if os(macOS)
private struct ManageConnectionsSearchField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let searchField = NSSearchField()
        searchField.placeholderString = placeholder
        searchField.stringValue = text
        searchField.delegate = context.coordinator
        searchField.sendsSearchStringImmediately = true
        searchField.sendsWholeSearchString = true
        searchField.controlSize = .large
        searchField.font = NSFont.systemFont(ofSize: 14)
        searchField.focusRingType = .none
        searchField.isBordered = true
        searchField.isBezeled = true
        searchField.drawsBackground = true
        searchField.bezelStyle = .roundedBezel
        if let cell = searchField.cell as? NSSearchFieldCell {
            cell.controlSize = .large
            cell.placeholderAttributedString = NSAttributedString(
                string: placeholder,
                attributes: [
                    .foregroundColor: NSColor.placeholderTextColor.withAlphaComponent(0.9),
                    .font: NSFont.systemFont(ofSize: 13)
                ]
            )
        }
        searchField.translatesAutoresizingMaskIntoConstraints = false
        return searchField
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        if nsView.placeholderString != placeholder {
            nsView.placeholderString = placeholder
        }
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let searchField = obj.object as? NSSearchField else { return }
            if text != searchField.stringValue {
                text = searchField.stringValue
            }
        }
    }
}

private struct RoundAddButtonLabel: View {
    @ObservedObject var themeManager: ThemeManager
    @State private var isHovered = false

    var body: some View {
        let isDark = themeManager.effectiveColorScheme == .dark
        let baseFillTop = isDark ? Color.white.opacity(0.26) : Color.white
        let baseFillBottom = isDark ? Color.white.opacity(0.18) : Color.white.opacity(0.88)
        let hoverFillTop = isDark ? Color.white.opacity(0.32) : Color.white
        let hoverFillBottom = isDark ? Color.white.opacity(0.24) : Color.white.opacity(0.95)
        let fillGradient = LinearGradient(
            colors: isHovered ? [hoverFillTop, hoverFillBottom] : [baseFillTop, baseFillBottom],
            startPoint: .top,
            endPoint: .bottom
        )
        let baseStroke = isDark ? Color.white.opacity(0.35) : Color.black.opacity(0.12)
        let hoverStroke = isDark ? Color.white.opacity(0.45) : Color.black.opacity(0.18)
        let stroke = isHovered ? hoverStroke : baseStroke
        let highlight = isDark ? Color.white.opacity(0.22) : Color.white.opacity(0.75)
        let iconColor = Color(nsColor: isDark ? .secondaryLabelColor : .tertiaryLabelColor)

        return Circle()
            .fill(fillGradient)
            .overlay(
                Circle()
                    .strokeBorder(stroke, lineWidth: 1)
                    .overlay(
                        Circle()
                            .strokeBorder(highlight, lineWidth: 0.5)
                            .blendMode(.plusLighter)
                    )
            )
            .overlay(
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(iconColor)
            )
            .frame(width: 30, height: 30)
            .contentShape(Circle())
            .onHover { isHovered = $0 }
            .shadow(color: Color.black.opacity(isDark ? 0.25 : 0.08), radius: isHovered ? 1.5 : 1, y: 0.5)
    }
}
#endif
// MARK: - Double-Click Support

#if os(macOS)
private struct ThemedTableContainer<Content: View>: NSViewRepresentable {
    let content: Content
    @ObservedObject private var themeManager = ThemeManager.shared
    let onConfigure: ((NSTableView) -> Void)?

    init(onConfigure: ((NSTableView) -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.onConfigure = onConfigure
    }

    func makeNSView(context: Context) -> NSHostingView<Content> {
        let hostingView = NSHostingView(rootView: content)

        DispatchQueue.main.async {
            if let tableView = findTableView(in: hostingView) {
                context.coordinator.tableView = tableView
                configure(tableView: tableView)
            }
        }

        return hostingView
    }

    func updateNSView(_ nsView: NSHostingView<Content>, context: Context) {
        nsView.rootView = content
        if let tableView = context.coordinator.tableView {
            configure(tableView: tableView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func configure(tableView: NSTableView) {
        applyTheme(to: tableView)
        onConfigure?(tableView)
    }

    private func applyTheme(to tableView: NSTableView) {
        applyTableTheme(tableView, themeManager: themeManager)
    }

    private func findTableView(in view: NSView) -> NSTableView? {
        if let tableView = view as? NSTableView {
            return tableView
        }
        for subview in view.subviews {
            if let found = findTableView(in: subview) {
                return found
            }
        }
        return nil
    }

    class Coordinator {
        weak var tableView: NSTableView?
    }
}

private struct DoubleClickableTable<Content: View>: NSViewRepresentable {
    let connections: [SavedConnection]
    @Binding var selection: Set<SavedConnection.ID>
    let onDoubleClick: (SavedConnection) -> Void
    let content: Content
    @ObservedObject private var themeManager = ThemeManager.shared

    init(
        connections: [SavedConnection],
        selection: Binding<Set<SavedConnection.ID>>,
        onDoubleClick: @escaping (SavedConnection) -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.connections = connections
        self._selection = selection
        self.onDoubleClick = onDoubleClick
        self.content = content()
    }

    func makeNSView(context: Context) -> NSHostingView<Content> {
        let hostingView = NSHostingView(rootView: content)

        DispatchQueue.main.async {
            if let tableView = findTableView(in: hostingView) {
                tableView.doubleAction = #selector(Coordinator.tableViewDoubleClicked(_:))
                tableView.target = context.coordinator
                applyTableTheme(tableView, themeManager: themeManager)
                context.coordinator.tableView = tableView
            }
        }

        return hostingView
    }

    func updateNSView(_ nsView: NSHostingView<Content>, context: Context) {
        nsView.rootView = content
        context.coordinator.connections = connections
        context.coordinator.selection = selection
        context.coordinator.onDoubleClick = onDoubleClick
        if let tableView = context.coordinator.tableView {
            applyTableTheme(tableView, themeManager: themeManager)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(connections: connections, selection: selection, onDoubleClick: onDoubleClick)
    }

    private func findTableView(in view: NSView) -> NSTableView? {
        if let tableView = view as? NSTableView {
            return tableView
        }
        for subview in view.subviews {
            if let found = findTableView(in: subview) {
                return found
            }
        }
        return nil
    }

    class Coordinator: NSObject {
        var connections: [SavedConnection]
        var selection: Set<SavedConnection.ID>
        var onDoubleClick: (SavedConnection) -> Void
        weak var tableView: NSTableView?

        init(connections: [SavedConnection], selection: Set<SavedConnection.ID>, onDoubleClick: @escaping (SavedConnection) -> Void) {
            self.connections = connections
            self.selection = selection
            self.onDoubleClick = onDoubleClick
        }

        @objc func tableViewDoubleClicked(_ sender: NSTableView) {
            guard sender.clickedRow >= 0,
                  sender.clickedRow < connections.count else { return }

            let connection = connections[sender.clickedRow]
            onDoubleClick(connection)
        }
    }
}

private func applyTableTheme(_ tableView: NSTableView, themeManager: ThemeManager) {
    let tone = themeManager.activePaletteTone
    tableView.appearance = NSAppearance(named: tone == .dark ? .darkAqua : .aqua)
    let base = themeManager.surfaceBackgroundNSColor
    tableView.backgroundColor = base
    tableView.usesAlternatingRowBackgroundColors = themeManager.resultsAlternateRowShading
    tableView.selectionHighlightStyle = .regular
    tableView.intercellSpacing = NSSize(width: 0, height: 0)
    tableView.enclosingScrollView?.drawsBackground = true
    tableView.enclosingScrollView?.backgroundColor = base

    if !themeManager.resultsAlternateRowShading {
        tableView.gridColor = themeManager.surfaceForegroundNSColor.withAlphaComponent(0.12)
    }
}

private struct ToolbarFlexibleSpacer: View {
    var body: some View {
        HStack { Spacer(minLength: 0) }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
#else
private struct ThemedTableContainer<Content: View>: View {
    let content: Content

    init(onConfigure: ((Any) -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View { content }
}
#endif
