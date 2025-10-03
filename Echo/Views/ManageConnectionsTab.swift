import SwiftUI
import UniformTypeIdentifiers

private enum ManageConnectionsLayout {
    static let tileWidth: CGFloat = 180
    static let tileHeight: CGFloat = 76
    static let identityHeight: CGFloat = 60
    static let tileCornerRadius: CGFloat = 10
    static let tileSpacing: CGFloat = 10
}

struct ManageConnectionsTab: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedSection: ManageSection? = .connections
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var searchText = ""
    @State private var connectionFolderPath: [UUID] = []
    @State private var identityFolderPath: [UUID] = []
    @State private var folderEditorState: FolderEditorState?
    @State private var identityEditorState: IdentityEditorState?
    @State private var pendingDeletion: DeletionTarget?
    @State private var dragState: DragState?
    @State private var activeDropTarget: DropTarget?
    @State private var hoverOpenWorkItem: DispatchWorkItem?
    @State private var backNavigationWorkItem: DispatchWorkItem?
    @State private var cancelHovering = false
    @State private var activeBreadcrumbTarget: BreadcrumbTarget?
    @State private var connectionEditorPresentation: ConnectionEditorPresentation?


    private var activeSection: ManageSection { selectedSection ?? .connections }

    var body: some View { configuredSplitView }

    private var configuredSplitView: some View {
        splitView
            .frame(minWidth: 760, minHeight: 520)
            .background(Color(nsColor: .windowBackgroundColor))
            .toolbar { toolbarContent }
            .searchable(text: $searchText, placement: .toolbar, prompt: Text("Search \(activeSection.title.lowercased())"))
            .sheet(item: $folderEditorState, content: folderEditorSheet)
            .sheet(item: $identityEditorState, content: identityEditorSheet)
            .sheet(item: $connectionEditorPresentation, content: connectionEditorSheet)
            .alert("Delete Item?", isPresented: deletionAlertBinding, presenting: pendingDeletion, actions: deletionAlertActions, message: deletionAlertMessage)
            .onChange(of: appModel.selectedProject?.id) { _, _ in resetForProjectChange() }
            .onChange(of: selectedSection) { _, section in if let section { handleSectionChange(section) } }
            .onChange(of: appModel.folders) { _, _ in pruneNavigationStacks() }
            .onAppear(perform: ensureSectionSelection)
    }

    private var splitView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 260)
        } detail: {
            mainContent
                .frame(minWidth: 620, idealWidth: 760)
                .background(Color(nsColor: .windowBackgroundColor))
        }
    }

    // MARK: - Sheets & Alerts

    private var deletionAlertBinding: Binding<Bool> {
        Binding(
            get: { pendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    pendingDeletion = nil
                }
            }
        )
    }

    @ViewBuilder
    private func folderEditorSheet(_ state: FolderEditorState) -> some View {
        FolderEditorSheet(state: state)
            .environmentObject(appModel)
    }

    @ViewBuilder
    private func identityEditorSheet(_ state: IdentityEditorState) -> some View {
        IdentityEditorSheet(state: state)
            .environmentObject(appModel)
    }

    @ViewBuilder
    private func connectionEditorSheet(_ presentation: ConnectionEditorPresentation) -> some View {
        ConnectionEditorView(connection: presentation.connection) { connection, password, action in
            handleConnectionEditorSave(connection: connection, password: password, action: action)
        }
        .environmentObject(appModel)
        .environmentObject(appState)
    }

    @ViewBuilder
    private func deletionAlertActions(target: DeletionTarget) -> some View {
        Button("Delete", role: .destructive) { performDeletion(for: target) }
        Button("Cancel", role: .cancel) { pendingDeletion = nil }
    }

    @ViewBuilder
    private func deletionAlertMessage(target: DeletionTarget) -> some View {
        Text("Are you sure you want to delete \(target.displayName)? This action cannot be undone.")
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var sidebar: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            List(selection: $selectedSection) {
                ForEach(ManageSection.allCases) { section in
                    Label(section.title, systemImage: section.icon)
                        .tag(section)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, -6)
            .overlay(alignment: .trailing) {
                Divider()
                    .opacity(0.4)
                    .ignoresSafeArea()
            }
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        Group {
            switch activeSection {
            case .connections:
                connectionsDetail
            case .identities:
                identitiesDetail
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }


    // MARK: - Context Menus

    @ViewBuilder
    private func contextMenu(for node: ItemNode, in section: ManageSection) -> some View {
        switch node.payload {
        case .folder(let folder):
            Button {
                openFolder(folder, in: section)
            } label: {
                Label("Open", systemImage: "folder")
            }
            Button {
                createSubfolder(for: folder)
            } label: {
                Label("New Subfolder", systemImage: "folder.badge.plus")
            }
            if section == .connections {
                Button {
                    createNewConnection(in: folder)
                } label: {
                    Label("New Connection", systemImage: "externaldrive.badge.plus")
                }
            } else {
                Button {
                    createNewIdentity(in: folder)
                } label: {
                    Label("New Identity", systemImage: "person.badge.plus")
                }
            }
            Divider()
            Button {
                editFolder(folder)
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Button(role: .destructive) {
                pendingDeletion = .folder(folder)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        case .connection(let connection):
            Button {
                connectToConnection(connection)
            } label: {
                Label("Connect", systemImage: "bolt.horizontal.circle")
            }
            Button {
                editConnection(connection)
            } label: {
                Label("Edit", systemImage: "square.and.pencil")
            }
            Button {
                duplicateConnection(connection)
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            Divider()
            Button {
                moveConnection(connection, to: nil)
            } label: {
                Label("Move to Root", systemImage: "arrowshape.turn.up.left")
            }
            ForEach(connectionFoldersSorted) { folder in
                if folder.id != connection.folderID {
                    Button {
                        moveConnection(connection, to: folder)
                    } label: {
                        Label("Move to \(folder.name)", systemImage: "folder")
                    }
                }
            }
            Divider()
            Button(role: .destructive) {
                pendingDeletion = .connection(connection)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        case .identity(let identity):
            Button {
                editIdentity(identity)
            } label: {
                Label("Edit", systemImage: "square.and.pencil")
            }
            Divider()
            Button {
                moveIdentity(identity, to: nil)
            } label: {
                Label("Move to Root", systemImage: "arrowshape.turn.up.left")
            }
            ForEach(identityFoldersSorted) { folder in
                if folder.id != identity.folderID {
                    Button {
                        moveIdentity(identity, to: folder)
                    } label: {
                        Label("Move to \(folder.name)", systemImage: "folder")
                    }
                }
            }
            Divider()
            Button(role: .destructive) {
                pendingDeletion = .identity(identity)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Section Detail (Card Layout)

    @ViewBuilder
    private var connectionsDetail: some View {
        let children = currentChildren(for: .connections)
        sectionDetail(
            section: .connections,
            folderNodes: children.folders,
            itemNodes: children.items,
            emptyIcon: "externaldrive.badge.plus",
            emptyTitle: "No Connections",
            emptyDescription: "Create your first connection to get started",
            emptyActionTitle: "New Connection",
            emptyAction: { createNewConnection() }
        ) { node in
            connectionCard(for: node)
        }
    }

    @ViewBuilder
    private var identitiesDetail: some View {
        let children = currentChildren(for: .identities)
        sectionDetail(
            section: .identities,
            folderNodes: children.folders,
            itemNodes: children.items,
            emptyIcon: "person.crop.circle.badge.plus",
            emptyTitle: "No Identities",
            emptyDescription: "Create identities to reuse credentials across connections",
            emptyActionTitle: "New Identity",
            emptyAction: { createNewIdentity() }
        ) { node in
            identityCard(for: node)
        }
    }

    @ViewBuilder
    private func sectionDetail<ItemContent: View>(
        section: ManageSection,
        folderNodes: [ItemNode],
        itemNodes: [ItemNode],
        emptyIcon: String,
        emptyTitle: String,
        emptyDescription: String,
        emptyActionTitle: String,
        emptyAction: @escaping () -> Void,
        @ViewBuilder itemContent: @escaping (ItemNode) -> ItemContent
    ) -> some View {
        let isEmpty = folderNodes.isEmpty && itemNodes.isEmpty
        let targetFolderID = currentFolderID(for: section)
        let rootTarget = DropTarget(section: section, folderID: targetFolderID, isRoot: true)

        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    breadcrumbs(for: section)

                    if isEmpty {
                        SectionEmptyState(
                            icon: emptyIcon,
                            title: emptyTitle,
                            description: emptyDescription,
                            actionTitle: emptyActionTitle,
                            action: emptyAction
                        )
                        .frame(maxWidth: .infinity)
                    } else {
                        if !itemNodes.isEmpty {
                            SectionGroupHeader(title: section.itemsHeaderTitle, count: itemNodes.count)
                            LazyVGrid(columns: adaptiveColumns, spacing: ManageConnectionsLayout.tileSpacing) {
                                ForEach(itemNodes) { node in
                                    itemContent(node)
                                }
                            }
                        }

                        if !folderNodes.isEmpty {
                            SectionGroupHeader(title: "Folders", count: folderNodes.count)
                            LazyVGrid(columns: adaptiveColumns, spacing: ManageConnectionsLayout.tileSpacing) {
                                ForEach(folderNodes) { node in
                                    folderCard(for: node, in: section)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.clear)
            .overlay {
                if activeDropTarget == rootTarget {
                    Color.accentColor.opacity(0.08)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: ManageConnectionsLayout.tileCornerRadius + 4,
                                style: .continuous
                            )
                        )
                        .padding(10)
                        .transition(.opacity)
                }
            }
            .onDrop(
                of: [.utf8PlainText],
                delegate: RootDropDelegate(
                    section: section,
                    targetFolderID: targetFolderID,
                    activeDropTarget: $activeDropTarget,
                    onMove: { payload, targetID in
                        handleMove(payload, to: targetID, in: section)
                    },
                    clearDragState: clearDragState
                )
            )

            if dragState != nil {
                cancelMoveOverlay
                    .padding(.bottom, 16)
            }
        }
        .contextMenu { backgroundContextMenu(for: section) }
    }

    private var adaptiveColumns: [GridItem] {
        [GridItem(
            .adaptive(minimum: ManageConnectionsLayout.tileWidth, maximum: ManageConnectionsLayout.tileWidth),
            spacing: ManageConnectionsLayout.tileSpacing,
            alignment: .top
        )]
    }

    @ViewBuilder
    private func folderCard(for node: ItemNode, in section: ManageSection) -> some View {
        if case .folder(let folder) = node.payload {
            let summary = folderSummary(for: folder, in: section)
            let isTargeted = activeDropTarget == DropTarget(section: section, folderID: folder.id, isRoot: false)

            FolderCard(
                folder: folder,
                summary: summary,
                isTargeted: isTargeted,
                onOpen: { openFolder(folder, in: section) }
            )
            .contextMenu { contextMenu(for: node, in: section) }
            .onDrag {
                dragState = DragState(
                    payload: .folder(folder.id, folder.kind),
                    sourceSection: section,
                    sourceFolderID: folder.parentFolderID
                )
                cancelAutoOpen()
                return NSItemProvider(object: DragPayload.folder(folder.id, folder.kind).stringValue as NSString)
            }
            .onDrop(
                of: [.utf8PlainText],
                delegate: FolderDropDelegate(
                    section: section,
                    folder: folder,
                    activeDropTarget: $activeDropTarget,
                    scheduleAutoOpen: { scheduleAutoOpen(for: folder, in: section) },
                    cancelAutoOpen: cancelAutoOpen,
                    onMove: { payload, target in
                        handleMove(payload, to: target, in: section)
                    },
                    clearDragState: clearDragState
                )
            )
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func connectionCard(for node: ItemNode) -> some View {
        if case .connection(let connection) = node.payload {
            ConnectionCard(
                connection: connection,
                identityDisplay: identityDisplay(for: connection),
                onEdit: { editConnection(connection) },
                onDelete: { pendingDeletion = .connection(connection) }
            )
            .contextMenu { contextMenu(for: node, in: .connections) }
            .onDrag {
                dragState = DragState(
                    payload: .connection(connection.id),
                    sourceSection: .connections,
                    sourceFolderID: connection.folderID
                )
                cancelAutoOpen()
                return NSItemProvider(object: DragPayload.connection(connection.id).stringValue as NSString)
            }
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func identityCard(for node: ItemNode) -> some View {
        if case .identity(let identity) = node.payload {
            let folderName = identity.folderID.flatMap { folderForID($0)?.name } ?? "Root"
            IdentityCard(
                identity: identity,
                folderName: folderName,
                onEdit: { editIdentity(identity) },
                onDelete: { pendingDeletion = .identity(identity) }
            )
            .contextMenu { contextMenu(for: node, in: .identities) }
            .onDrag {
                dragState = DragState(
                    payload: .identity(identity.id),
                    sourceSection: .identities,
                    sourceFolderID: identity.folderID
                )
                cancelAutoOpen()
                return NSItemProvider(object: DragPayload.identity(identity.id).stringValue as NSString)
            }
        } else {
            EmptyView()
        }
    }

    private var cancelMoveOverlay: some View {
        CancelDropZone(isHovering: cancelHovering)
            .onDrop(of: [.utf8PlainText], isTargeted: Binding(
                get: { cancelHovering },
                set: { hovered in
                    cancelHovering = hovered
                    if !hovered {
                        cancelAutoOpen()
                        cancelBackNavigationHover()
                    }
                }
            )) { _ in
                cancelPendingMove()
                return true
            }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text("Manage \(activeSection.title)")
                .font(.system(size: 15, weight: .semibold))
        }

        ToolbarItemGroup(placement: .primaryAction) {
            switch activeSection {
            case .connections:
                Button(action: { createNewConnection() }) {
                    Label("New Connection", systemImage: "plus")
                }
                Button(action: { createNewFolder(.connections) }) {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
            case .identities:
                Button(action: { createNewIdentity() }) {
                    Label("New Identity", systemImage: "plus")
                }
                Button(action: { createNewFolder(.identities) }) {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
            }
        }
    }

    // MARK: - Actions

    private func handleConnectionEditorSave(connection: SavedConnection, password: String?, action: ConnectionEditorView.SaveAction) {
        Task {
            await appModel.upsertConnection(connection, password: password)

            await MainActor.run {
                selectedSection = .connections
                appModel.selectedFolderID = connection.folderID
                if action == .saveAndConnect {
                    appModel.selectedConnectionID = connection.id
                }
                if let folderID = connection.folderID, let folder = folderForID(folderID) {
                    connectionFolderPath = pathForFolder(folder)
                } else {
                    connectionFolderPath = []
                }
                connectionEditorPresentation = nil
            }

            if action == .saveAndConnect {
                await appModel.connect(to: connection)
                await MainActor.run {
                    appModel.showManageConnectionsTab = false
                    dismiss()
                }
            }
        }
    }

    private func createNewConnection(in folder: SavedFolder? = nil) {
        selectedSection = .connections
        let parentFolder = folder ?? currentFolder(for: .connections)
        appModel.selectedFolderID = parentFolder?.id
        connectionEditorPresentation = ConnectionEditorPresentation(connection: nil)
    }

    private func createNewIdentity(in folder: SavedFolder? = nil) {
        selectedSection = .identities
        identityEditorState = .create(parent: folder ?? currentFolder(for: .identities), token: UUID())
    }

    private func createNewFolder(_ kind: FolderKind, parent: SavedFolder? = nil) {
        switch kind {
        case .connections: selectedSection = .connections
        case .identities: selectedSection = .identities
        }
        let parent = parent ?? currentFolder(for: kind)
        folderEditorState = .create(kind: kind, parent: parent, token: UUID())
    }

    private func createSubfolder(for folder: SavedFolder) {
        selectedSection = folder.kind == .connections ? .connections : .identities
        folderEditorState = .create(kind: folder.kind, parent: folder, token: UUID())
    }

    private func editConnection(_ connection: SavedConnection) {
        selectedSection = .connections
        appModel.selectedFolderID = connection.folderID
        connectionEditorPresentation = ConnectionEditorPresentation(connection: connection)
    }

    private func editIdentity(_ identity: SavedIdentity) {
        identityEditorState = .edit(identity: identity)
    }

    private func editFolder(_ folder: SavedFolder) {
        folderEditorState = .edit(folder: folder)
    }

    private func deleteConnection(_ connection: SavedConnection) {
        Task {
            await appModel.deleteConnection(connection)
        }
    }

    private func deleteIdentity(_ identity: SavedIdentity) {
        Task {
            await appModel.deleteIdentity(identity)
        }
    }

    private func deleteFolder(_ folder: SavedFolder) {
        Task {
            await appModel.deleteFolder(folder)
        }
    }

    private func connectToConnection(_ connection: SavedConnection) {
        Task {
            await appModel.connect(to: connection)
            await MainActor.run {
                appModel.showManageConnectionsTab = false
                dismiss()
            }
        }
    }

    private func moveConnection(_ connection: SavedConnection, to folder: SavedFolder?) {
        appModel.moveConnection(connection.id, toFolder: folder?.id)
    }

    private func moveIdentity(_ identity: SavedIdentity, to folder: SavedFolder?) {
        appModel.moveIdentity(identity.id, toFolder: folder?.id)
    }

    private func duplicateConnection(_ connection: SavedConnection) {
        Task {
            await appModel.duplicateConnection(connection)
        }
    }

    private func performDeletion(for target: DeletionTarget) {
        switch target {
        case .connection(let connection):
            deleteConnection(connection)
        case .folder(let folder):
            deleteFolder(folder)
        case .identity(let identity):
            deleteIdentity(identity)
        }
        pendingDeletion = nil
    }

    private func currentFolder(for kind: FolderKind) -> SavedFolder? {
        let folderID: UUID?
        switch kind {
        case .connections:
            folderID = connectionFolderPath.last
        case .identities:
            folderID = identityFolderPath.last
        }
        guard let id = folderID else { return nil }
        return appModel.folders.first(where: { $0.id == id && $0.kind == kind })
    }

    private func currentFolderID(for section: ManageSection) -> UUID? {
        switch section {
        case .connections: return connectionFolderPath.last
        case .identities: return identityFolderPath.last
        }
    }

    private func folderPath(for section: ManageSection) -> [UUID] {
        switch section {
        case .connections: return connectionFolderPath
        case .identities: return identityFolderPath
        }
    }

    private func setFolderPath(_ path: [UUID], for section: ManageSection) {
        switch section {
        case .connections: connectionFolderPath = path
        case .identities: identityFolderPath = path
        }
    }

    private func openFolder(_ folder: SavedFolder, in section: ManageSection) {
        // Ensure navigation follows real hierarchy
        let path = pathForFolder(folder)
        setFolderPath(path, for: section)
    }

    private func navigateToFolder(withID id: UUID, in section: ManageSection) {
        guard let folder = folderForID(id) else { return }
        let path = pathForFolder(folder)
        setFolderPath(path, for: section)
    }

    private func folderForID(_ id: UUID) -> SavedFolder? {
        appModel.folders.first(where: { $0.id == id })
    }

    private func pathForFolder(_ folder: SavedFolder) -> [UUID] {
        var identifiers: [UUID] = []
        var current: SavedFolder? = folder
        let projectID = selectedProjectID
        while let node = current {
            if node.projectID == projectID {
                identifiers.insert(node.id, at: 0)
            }
            if let parentID = node.parentFolderID,
               let parent = folderForID(parentID) {
                current = parent
            } else {
                current = nil
            }
        }
        return identifiers
    }

    private func clearDragState() {
        dragState = nil
        activeDropTarget = nil
        cancelHovering = false
        activeBreadcrumbTarget = nil
        cancelAutoOpen()
        cancelBackNavigationHover()
    }

    private func cancelPendingMove() {
        clearDragState()
    }

    private func scheduleAutoOpen(for folder: SavedFolder, in section: ManageSection) {
        cancelAutoOpen()
        let workItem = DispatchWorkItem {
            openFolder(folder, in: section)
            activeDropTarget = DropTarget(section: section, folderID: folder.id, isRoot: true)
        }
        hoverOpenWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55, execute: workItem)
    }

    private func cancelAutoOpen() {
        hoverOpenWorkItem?.cancel()
        hoverOpenWorkItem = nil
    }

    private func scheduleBreadcrumbNavigation(to path: [UUID], in section: ManageSection) {
        cancelBackNavigationHover()
        guard folderPath(for: section) != path else { return }
        let workItem = DispatchWorkItem { setFolderPath(path, for: section) }
        backNavigationWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    private func cancelBackNavigationHover() {
        backNavigationWorkItem?.cancel()
        backNavigationWorkItem = nil
    }

    private func ensureSectionSelection() {
        if selectedSection == nil {
            if let identityID = appModel.selectedIdentityID,
               appModel.identities.contains(where: { $0.id == identityID }) {
                selectedSection = .identities
            } else {
                selectedSection = .connections
            }
        }

        guard let projectID = selectedProjectID else { return }

        if connectionFolderPath.isEmpty,
           let folderID = appModel.selectedFolderID,
           let folder = appModel.folders.first(where: { $0.id == folderID && $0.kind == .connections && $0.projectID == projectID }) {
            connectionFolderPath = pathForFolder(folder)
        }

        if identityFolderPath.isEmpty,
           let identityID = appModel.selectedIdentityID,
           let identity = appModel.identities.first(where: { $0.id == identityID && $0.projectID == projectID }),
           let folderID = identity.folderID,
           let folder = appModel.folders.first(where: { $0.id == folderID && $0.kind == .identities && $0.projectID == projectID }) {
            identityFolderPath = pathForFolder(folder)
        }
    }

    private func resetForProjectChange() {
        searchText = ""
        connectionFolderPath = []
        identityFolderPath = []
        clearDragState()
        selectedSection = .connections
    }

    private func handleSectionChange(_ section: ManageSection) {
        searchText = ""
        clearDragState()
    }

    private func pruneNavigationStacks() {
        prunePath(&connectionFolderPath, kind: .connections)
        prunePath(&identityFolderPath, kind: .identities)
    }

    private func prunePath(_ path: inout [UUID], kind: FolderKind) {
        var validated: [UUID] = []
        var expectedParent: UUID? = nil
        for identifier in path {
            guard let folder = folderForID(identifier),
                  folder.kind == kind,
                  folder.parentFolderID == expectedParent else {
                break
            }
            validated.append(identifier)
            expectedParent = identifier
        }
        path = validated
    }

    private func currentChildren(for section: ManageSection) -> (folders: [ItemNode], items: [ItemNode]) {
        let tree: [ItemNode]
        switch section {
        case .connections: tree = filteredConnectionTree
        case .identities: tree = filteredIdentityTree
        }

        let nodes = childNodes(of: currentFolderID(for: section), in: tree)
        let folders = nodes.filter { if case .folder = $0.payload { return true } else { return false } }
        let items = nodes.filter { node in
            switch (section, node.payload) {
            case (.connections, .connection): return true
            case (.identities, .identity): return true
            default: return false
            }
        }
        return (folders, items)
    }

    private func childNodes(of folderID: UUID?, in tree: [ItemNode]) -> [ItemNode] {
        guard let folderID else { return tree }
        return findNode(withID: folderID, in: tree)?.children ?? []
    }

    private func findNode(withID id: UUID, in nodes: [ItemNode]) -> ItemNode? {
        for node in nodes {
            if node.id == id {
                return node
            }
            if let found = findNode(withID: id, in: node.children) {
                return found
            }
        }
        return nil
    }

    private func handleMove(_ payload: DragPayload, to folderID: UUID?, in section: ManageSection) {
        switch payload {
        case .connection(let id):
            guard section == .connections else { return }
            appModel.moveConnection(id, toFolder: folderID)
        case .identity(let id):
            guard section == .identities else { return }
            appModel.moveIdentity(id, toFolder: folderID)
        case .folder(let id, let kind):
            guard kind == section.folderKind else { return }
            appModel.moveFolder(id, toParent: folderID)
        }
        clearDragState()
    }

    private func folderSummary(for folder: SavedFolder, in section: ManageSection) -> FolderSummary {
        switch section {
        case .connections:
            let folders = connectionFolders.filter { $0.parentFolderID == folder.id }
            let connections = projectConnections.filter { $0.folderID == folder.id }
            return FolderSummary(folderCount: folders.count, itemCount: connections.count, itemLabel: "connection")
        case .identities:
            let folders = identityFolders.filter { $0.parentFolderID == folder.id }
            let identities = projectIdentities.filter { $0.folderID == folder.id }
            return FolderSummary(folderCount: folders.count, itemCount: identities.count, itemLabel: "identity")
        }
    }

    private func identityDisplay(for connection: SavedConnection) -> IdentityDisplay {
        switch connection.credentialSource {
        case .identity:
            if let identityID = connection.identityID,
               let identity = identityLookup[identityID] {
                let detail = identity.username.isEmpty ? nil : identity.username
                return IdentityDisplay(label: identity.name, detail: detail, style: .identity)
            }
            return IdentityDisplay(label: "Linked identity", detail: nil, style: .identity)
        case .inherit:
            return IdentityDisplay(label: "Inherited credentials", detail: nil, style: .inherit)
        case .manual:
            let detail = connection.username.isEmpty ? nil : connection.username
            return IdentityDisplay(label: "Manual credentials", detail: detail, style: .manual)
        }
    }

    @ViewBuilder
    private func breadcrumbs(for section: ManageSection) -> some View {
        if folderPath(for: section).isEmpty {
            EmptyView()
        } else {
            breadcrumbsContent(for: section)
        }
    }

    @ViewBuilder
    private func breadcrumbsContent(for section: ManageSection) -> some View {
        let crumbs = breadcrumbItems(for: section)
        let parent = parentBreadcrumb(for: section)
        let currentID = currentFolderID(for: section)
        let directoryTarget = DropTarget(section: section, folderID: currentID, isRoot: currentID == nil)
        let isDirectoryTargeted = activeDropTarget == directoryTarget

        VStack(alignment: .leading, spacing: 6) {
            Label("Location", systemImage: "folder")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                if let back = parent {
                    BreadcrumbBackButton(
                        isTargeted: activeBreadcrumbTarget == BreadcrumbTarget(section: section, folderID: back.folderID)
                    ) {
                        setFolderPath(back.path, for: section)
                    }
                    .onDrop(
                        of: [.utf8PlainText],
                        delegate: BreadcrumbDropDelegate(
                            section: section,
                            breadcrumb: back,
                            activeBreadcrumbTarget: $activeBreadcrumbTarget,
                            scheduleNavigation: { scheduleBreadcrumbNavigation(to: back.path, in: section) },
                            cancelNavigation: cancelBackNavigationHover,
                            onMove: { payload, folderID in
                                handleMove(payload, to: folderID, in: section)
                            },
                            clearDragState: clearDragState
                        )
                    )

                    Divider()
                        .frame(height: 18)
                        .padding(.trailing, 2)
                }

                ForEach(Array(crumbs.enumerated()), id: \.element.id) { index, crumb in
                    BreadcrumbChip(
                        title: crumb.title,
                        isCurrent: crumb.folderID == currentID,
                        isTargeted: activeBreadcrumbTarget == BreadcrumbTarget(section: section, folderID: crumb.folderID)
                    ) {
                        setFolderPath(crumb.path, for: section)
                    }
                    .onDrop(
                        of: [.utf8PlainText],
                        delegate: BreadcrumbDropDelegate(
                            section: section,
                            breadcrumb: crumb,
                            activeBreadcrumbTarget: $activeBreadcrumbTarget,
                            scheduleNavigation: { scheduleBreadcrumbNavigation(to: crumb.path, in: section) },
                            cancelNavigation: cancelBackNavigationHover,
                            onMove: { payload, folderID in
                                handleMove(payload, to: folderID, in: section)
                            },
                            clearDragState: clearDragState
                        )
                    )

                    if index < crumbs.count - 1 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                isDirectoryTargeted ? Color.accentColor.opacity(0.6) : Color.primary.opacity(0.08),
                                lineWidth: isDirectoryTargeted ? 1.6 : 1
                            )
                    )
            )
            .onDrop(
                of: [.utf8PlainText],
                delegate: DirectoryDropDelegate(
                    section: section,
                    folderID: currentID,
                    activeDropTarget: $activeDropTarget,
                    onMove: { payload, target in
                        handleMove(payload, to: target, in: section)
                    },
                    clearDragState: clearDragState
                )
            )
        }
    }

    private func breadcrumbItems(for section: ManageSection) -> [Breadcrumb] {
        var items: [Breadcrumb] = []
        items.append(Breadcrumb(folderID: nil, title: section.title, path: []))
        var path: [UUID] = []
        for identifier in folderPath(for: section) {
            path.append(identifier)
            if let folder = folderForID(identifier) {
                items.append(Breadcrumb(folderID: identifier, title: folder.name, path: path))
            }
        }
        return items
    }

    private func parentBreadcrumb(for section: ManageSection) -> Breadcrumb? {
        var path = folderPath(for: section)
        guard !path.isEmpty else { return nil }
        path.removeLast()
        let folderID = path.last
        let title: String
        if let id = folderID, let folder = folderForID(id) {
            title = folder.name
        } else {
            title = section.title
        }
        return Breadcrumb(folderID: folderID, title: title, path: path)
    }

    @ViewBuilder
    private func backgroundContextMenu(for section: ManageSection) -> some View {
        switch section {
        case .connections:
            Button {
                createNewConnection()
            } label: {
                Label("Create New Connection", systemImage: "externaldrive.badge.plus")
            }
            Button {
                createNewFolder(.connections)
            } label: {
                Label("Create New Folder", systemImage: "folder.badge.plus")
            }
        case .identities:
            Button {
                createNewIdentity()
            } label: {
                Label("Create New Identity", systemImage: "person.badge.plus")
            }
            Button {
                createNewFolder(.identities)
            } label: {
                Label("Create New Folder", systemImage: "folder.badge.plus")
            }
        }
    }

    // MARK: - Data Sources

    private var selectedProjectID: UUID? {
        appModel.selectedProject?.id
    }

    private var projectConnections: [SavedConnection] {
        appModel.connections.filter { $0.projectID == selectedProjectID }
    }

    private var projectIdentities: [SavedIdentity] {
        appModel.identities.filter { $0.projectID == selectedProjectID }
    }

    private var connectionFoldersSorted: [SavedFolder] {
        connectionFolders.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var identityFoldersSorted: [SavedFolder] {
        identityFolders.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var connectionFolders: [SavedFolder] {
        appModel.folders.filter { $0.kind == .connections && $0.projectID == selectedProjectID }
    }

    private var identityFolders: [SavedFolder] {
        appModel.folders.filter { $0.kind == .identities && $0.projectID == selectedProjectID }
    }

    private var identityLookup: [UUID: SavedIdentity] {
        Dictionary(uniqueKeysWithValues: projectIdentities.map { ($0.id, $0) })
    }

    private var filteredConnectionTree: [ItemNode] {
        let tree = buildTree(for: .connections)
        guard let query = normalizedQuery else { return tree }
        return filter(tree, for: .connections, query: query)
    }

    private var filteredIdentityTree: [ItemNode] {
        let tree = buildTree(for: .identities)
        guard let query = normalizedQuery else { return tree }
        return filter(tree, for: .identities, query: query)
    }

    private var normalizedQuery: String? {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func buildTree(for section: ManageSection) -> [ItemNode] {
        switch section {
        case .connections:
            let folderMap = Dictionary(grouping: connectionFoldersSorted, by: { $0.parentFolderID })
            let itemMap = Dictionary(grouping: projectConnections.sorted { $0.connectionName.localizedCaseInsensitiveCompare($1.connectionName) == .orderedAscending }, by: { $0.folderID })
            return buildNodes(parentID: nil, folderMap: folderMap, connectionMap: itemMap, identityMap: nil)
        case .identities:
            let folderMap = Dictionary(grouping: identityFoldersSorted, by: { $0.parentFolderID })
            let itemMap = Dictionary(grouping: projectIdentities.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }, by: { $0.folderID })
            return buildNodes(parentID: nil, folderMap: folderMap, connectionMap: nil, identityMap: itemMap)
        }
    }

    private func buildNodes(
        parentID: UUID?,
        folderMap: [UUID?: [SavedFolder]],
        connectionMap: [UUID?: [SavedConnection]]?,
        identityMap: [UUID?: [SavedIdentity]]?
    ) -> [ItemNode] {
        var nodes: [ItemNode] = []

        if let folders = folderMap[parentID] {
            for folder in folders {
                let childFolders = buildNodes(
                    parentID: folder.id,
                    folderMap: folderMap,
                    connectionMap: connectionMap,
                    identityMap: identityMap
                )
                let connections = (connectionMap?[folder.id] ?? []).map { ItemNode(payload: .connection($0), children: []) }
                let identities = (identityMap?[folder.id] ?? []).map { ItemNode(payload: .identity($0), children: []) }
                nodes.append(
                    ItemNode(
                        payload: .folder(folder),
                        children: childFolders + connections + identities
                    )
                )
            }
        }

        if let connections = connectionMap?[parentID] {
            nodes += connections.map { ItemNode(payload: .connection($0), children: []) }
        }

        if let identities = identityMap?[parentID] {
            nodes += identities.map { ItemNode(payload: .identity($0), children: []) }
        }

        return nodes
    }

    private func filter(_ nodes: [ItemNode], for section: ManageSection, query: String) -> [ItemNode] {
        nodes.compactMap { node in
            let filteredChildren = filter(node.children, for: section, query: query)
            if node.matches(query, section: section, identityLookup: identityLookup) {
                return ItemNode(payload: node.payload, children: filteredChildren)
            }
            if !filteredChildren.isEmpty {
                return ItemNode(payload: node.payload, children: filteredChildren)
            }
            return nil
        }
    }

    // MARK: - Formatters

    private let dateFormatter = RelativeDateTimeFormatter()
}

// MARK: - Manage Section

enum ManageSection: String, CaseIterable, Identifiable {
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

    var color: Color {
        switch self {
        case .connections: return .blue
        case .identities: return .purple
        }
    }

    var itemsHeaderTitle: String {
        switch self {
        case .connections: return "Connections"
        case .identities: return "Identities"
        }
    }

    var folderKind: FolderKind {
        switch self {
        case .connections: return .connections
        case .identities: return .identities
        }
    }
}

// MARK: - Item Node

private struct ItemNode: Identifiable {
    enum Payload {
        case folder(SavedFolder)
        case connection(SavedConnection)
        case identity(SavedIdentity)
    }

    let payload: Payload
    var children: [ItemNode]

    var id: UUID {
        switch payload {
        case .folder(let folder): return folder.id
        case .connection(let connection): return connection.id
        case .identity(let identity): return identity.id
        }
    }

    var childNodes: [ItemNode]? {
        children.isEmpty ? nil : children
    }

    func descendantCount(for section: ManageSection) -> Int {
        switch payload {
        case .folder:
            return children.reduce(0) { $0 + $1.descendantCount(for: section) }
        case .connection:
            return section == .connections ? 1 : 0
        case .identity:
            return section == .identities ? 1 : 0
        }
    }

    func matches(_ query: String, section: ManageSection, identityLookup: [UUID: SavedIdentity]) -> Bool {
        let lowered = query.lowercased()
        switch payload {
        case .folder(let folder):
            return folder.name.lowercased().contains(lowered)
        case .connection(let connection):
            let identityName = connection.identityID.flatMap { identityLookup[$0]?.name.lowercased() } ?? ""
            return connection.connectionName.lowercased().contains(lowered) ||
                connection.host.lowercased().contains(lowered) ||
                connection.database.lowercased().contains(lowered) ||
                connection.username.lowercased().contains(lowered) ||
                identityName.contains(lowered)
        case .identity(let identity):
            return identity.name.lowercased().contains(lowered) ||
                identity.username.lowercased().contains(lowered)
        }
    }
}

// MARK: - Card Helpers & Supporting Types

private struct FolderSummary {
    let folderCount: Int
    let itemCount: Int
    let itemLabel: String

    var folderText: String {
        "\(folderCount) folder\(folderCount == 1 ? "" : "s")"
    }

    var itemText: String {
        "\(itemCount) \(itemLabel)\(itemCount == 1 ? "" : "s")"
    }
}

private struct IdentityDisplay {
    enum Style {
        case identity
        case inherit
        case manual

        var foreground: Color {
            switch self {
            case .identity: return .purple
            case .inherit: return .teal
            case .manual: return .secondary
            }
        }

        var icon: String {
            switch self {
            case .identity: return "person.crop.circle"
            case .inherit: return "arrow.triangle.branch"
            case .manual: return "key"
            }
        }

        var iconSymbol: String {
            switch self {
            case .identity: return "person.crop.circle"
            case .inherit: return "arrow.triangle.branch"
            case .manual: return "key.fill"
            }
        }
    }

    let label: String
    let detail: String?
    let style: Style
}

private struct Breadcrumb: Identifiable {
    let folderID: UUID?
    let title: String
    let path: [UUID]

    var id: String {
        folderID?.uuidString ?? "root"
    }
}

private struct BreadcrumbTarget: Equatable {
    let section: ManageSection
    let folderID: UUID?
}

private struct DragState: Equatable {
    let payload: DragPayload
    let sourceSection: ManageSection
    let sourceFolderID: UUID?
}

private struct ConnectionEditorPresentation: Identifiable {
    let id = UUID()
    let connection: SavedConnection?
}

private enum DragPayload: Equatable {
    case connection(UUID)
    case identity(UUID)
    case folder(UUID, FolderKind)

    init?(string: String) {
        let parts = string.split(separator: ":")
        guard let type = parts.first else { return nil }

        switch type {
        case "connection":
            guard parts.count == 2, let id = UUID(uuidString: String(parts[1])) else { return nil }
            self = .connection(id)
        case "identity":
            guard parts.count == 2, let id = UUID(uuidString: String(parts[1])) else { return nil }
            self = .identity(id)
        case "folder":
            guard parts.count == 3,
                  let kind = FolderKind(rawValue: String(parts[1])),
                  let id = UUID(uuidString: String(parts[2])) else { return nil }
            self = .folder(id, kind)
        default:
            return nil
        }
    }

    var stringValue: String {
        switch self {
        case .connection(let id):
            return "connection:\(id.uuidString)"
        case .identity(let id):
            return "identity:\(id.uuidString)"
        case .folder(let id, let kind):
            return "folder:\(kind.rawValue):\(id.uuidString)"
        }
    }
}

private struct DropTarget: Equatable {
    let section: ManageSection
    let folderID: UUID?
    let isRoot: Bool
}

private struct RootDropDelegate: DropDelegate {
    let section: ManageSection
    let targetFolderID: UUID?
    @Binding var activeDropTarget: DropTarget?
    let onMove: (DragPayload, UUID?) -> Void
    let clearDragState: () -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.utf8PlainText])
    }

    func dropEntered(info: DropInfo) {
        activeDropTarget = DropTarget(section: section, folderID: targetFolderID, isRoot: true)
    }

    func dropExited(info: DropInfo) {
        if activeDropTarget == DropTarget(section: section, folderID: targetFolderID, isRoot: true) {
            activeDropTarget = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [UTType.utf8PlainText]).first else {
            activeDropTarget = nil
            clearDragState()
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.utf8PlainText.identifier, options: nil) { item, _ in
            let string: String?
            if let data = item as? Data {
                string = String(data: data, encoding: .utf8)
            } else if let text = item as? String {
                string = text
            } else if let nsText = item as? NSString {
                string = String(nsText)
            } else {
                string = nil
            }

            guard let raw = string,
                  let payload = DragPayload(string: raw) else {
                DispatchQueue.main.async { clearDragState() }
                return
            }

            DispatchQueue.main.async {
                onMove(payload, targetFolderID)
            }
        }

        activeDropTarget = nil
        return true
    }
}

private struct FolderDropDelegate: DropDelegate {
    let section: ManageSection
    let folder: SavedFolder
    @Binding var activeDropTarget: DropTarget?
    let scheduleAutoOpen: () -> Void
    let cancelAutoOpen: () -> Void
    let onMove: (DragPayload, UUID?) -> Void
    let clearDragState: () -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.utf8PlainText])
    }

    func dropEntered(info: DropInfo) {
        activeDropTarget = DropTarget(section: section, folderID: folder.id, isRoot: false)
        scheduleAutoOpen()
    }

    func dropExited(info: DropInfo) {
        if activeDropTarget == DropTarget(section: section, folderID: folder.id, isRoot: false) {
            activeDropTarget = nil
        }
        cancelAutoOpen()
    }

    func performDrop(info: DropInfo) -> Bool {
        cancelAutoOpen()
        guard let provider = info.itemProviders(for: [UTType.utf8PlainText]).first else {
            activeDropTarget = nil
            clearDragState()
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.utf8PlainText.identifier, options: nil) { item, _ in
            let string: String?
            if let data = item as? Data {
                string = String(data: data, encoding: .utf8)
            } else if let text = item as? String {
                string = text
            } else if let nsText = item as? NSString {
                string = String(nsText)
            } else {
                string = nil
            }

            guard let raw = string,
                  let payload = DragPayload(string: raw) else {
                DispatchQueue.main.async { clearDragState() }
                return
            }

            DispatchQueue.main.async {
                onMove(payload, folder.id)
            }
        }

        activeDropTarget = nil
        return true
    }
}

private struct DirectoryDropDelegate: DropDelegate {
    let section: ManageSection
    let folderID: UUID?
    @Binding var activeDropTarget: DropTarget?
    let onMove: (DragPayload, UUID?) -> Void
    let clearDragState: () -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.utf8PlainText])
    }

    func dropEntered(info: DropInfo) {
        activeDropTarget = DropTarget(section: section, folderID: folderID, isRoot: folderID == nil)
    }

    func dropExited(info: DropInfo) {
        if activeDropTarget == DropTarget(section: section, folderID: folderID, isRoot: folderID == nil) {
            activeDropTarget = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [UTType.utf8PlainText]).first else {
            activeDropTarget = nil
            clearDragState()
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.utf8PlainText.identifier, options: nil) { item, _ in
            let string: String?
            if let data = item as? Data {
                string = String(data: data, encoding: .utf8)
            } else if let text = item as? String {
                string = text
            } else if let nsText = item as? NSString {
                string = String(nsText)
            } else {
                string = nil
            }

            guard let raw = string,
                  let payload = DragPayload(string: raw) else {
                DispatchQueue.main.async { clearDragState() }
                return
            }

            DispatchQueue.main.async {
                onMove(payload, folderID)
            }
        }

        activeDropTarget = nil
        return true
    }
}

private struct BreadcrumbDropDelegate: DropDelegate {
    let section: ManageSection
    let breadcrumb: Breadcrumb
    @Binding var activeBreadcrumbTarget: BreadcrumbTarget?
    let scheduleNavigation: () -> Void
    let cancelNavigation: () -> Void
    let onMove: (DragPayload, UUID?) -> Void
    let clearDragState: () -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.utf8PlainText])
    }

    func dropEntered(info: DropInfo) {
        activeBreadcrumbTarget = BreadcrumbTarget(section: section, folderID: breadcrumb.folderID)
        scheduleNavigation()
    }

    func dropExited(info: DropInfo) {
        if activeBreadcrumbTarget == BreadcrumbTarget(section: section, folderID: breadcrumb.folderID) {
            activeBreadcrumbTarget = nil
        }
        cancelNavigation()
    }

    func performDrop(info: DropInfo) -> Bool {
        cancelNavigation()
        guard let provider = info.itemProviders(for: [UTType.utf8PlainText]).first else {
            activeBreadcrumbTarget = nil
            clearDragState()
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.utf8PlainText.identifier, options: nil) { item, _ in
            let string: String?
            if let data = item as? Data {
                string = String(data: data, encoding: .utf8)
            } else if let text = item as? String {
                string = text
            } else if let nsText = item as? NSString {
                string = String(nsText)
            } else {
                string = nil
            }

            guard let raw = string,
                  let payload = DragPayload(string: raw) else {
                DispatchQueue.main.async { clearDragState() }
                return
            }

            DispatchQueue.main.async {
                onMove(payload, breadcrumb.folderID)
            }
        }

        activeBreadcrumbTarget = nil
        return true
    }
}

private struct CancelDropZone: View {
    let isHovering: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text("Cancel Move")
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isHovering ? Color.red.opacity(0.9) : backgroundColor)
                    .overlay(
                        Capsule()
                            .stroke(isHovering ? Color.clear : Color.red.opacity(0.28), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 6)
            )
            .foregroundStyle(isHovering ? Color.white : Color.red)
            .animation(.easeInOut(duration: 0.18), value: isHovering)
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.white.opacity(0.7)
    }
}

private struct SectionEmptyState: View {
    let icon: String
    let title: String
    let description: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.18), Color.accentColor.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }

            Button(action: action) {
                Label(actionTitle, systemImage: "plus")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(36)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.04), radius: 14, x: 0, y: 8)
        )
    }
}

private struct SectionGroupHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("· \(count)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 4)
    }
}

private struct FolderCard: View {
    let folder: SavedFolder
    let summary: FolderSummary
    let isTargeted: Bool
    let onOpen: () -> Void

    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme

    private var accentColor: Color { folder.color }
    private var summaryLine: String { "\(summary.folderText) • \(summary.itemText)" }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            folderBadge

            VStack(alignment: .leading, spacing: 3) {
                Text(folder.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(summary.itemText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(
            width: ManageConnectionsLayout.tileWidth,
            height: ManageConnectionsLayout.tileHeight,
            alignment: .center
        )
        .background(
            RoundedRectangle(cornerRadius: ManageConnectionsLayout.tileCornerRadius, style: .continuous)
                .fill(tileBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ManageConnectionsLayout.tileCornerRadius, style: .continuous)
                .stroke(borderColor, lineWidth: isTargeted ? 1.6 : 1)
        )
        .shadow(color: shadowColor, radius: isHovering ? 9 : 5, x: 0, y: isHovering ? 6 : 3)
        .contentShape(RoundedRectangle(cornerRadius: ManageConnectionsLayout.tileCornerRadius, style: .continuous))
        .animation(.easeInOut(duration: 0.18), value: isHovering)
        .animation(.easeInOut(duration: 0.18), value: isTargeted)
        .onHover { isHovering = $0 }
        .onTapGesture { onOpen() }
    }
    private var folderBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accentColor.opacity(0.65), accentColor.opacity(0.32)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28, height: 28)

            Image(systemName: "folder.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white)
        }
    }

    private var tileBackground: Color {
        if isTargeted {
            return accentColor.opacity(colorScheme == .dark ? 0.38 : 0.16)
        }
        if colorScheme == .dark {
            return Color(nsColor: .controlBackgroundColor).opacity(isHovering ? 0.82 : 0.72)
        }
        return Color(nsColor: .controlBackgroundColor).opacity(isHovering ? 1.0 : 0.96)
    }

    private var borderColor: Color {
        if isTargeted { return accentColor.opacity(0.85) }
        return Color.primary.opacity(colorScheme == .dark ? 0.22 : 0.12)
    }

    private var shadowColor: Color {
        Color.black.opacity(colorScheme == .dark ? (isHovering ? 0.3 : 0.18) : (isHovering ? 0.16 : 0.08))
    }
}


private struct ConnectionCard: View {
    let connection: SavedConnection
    let identityDisplay: IdentityDisplay
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme

    private var accentColor: Color {
        Color(hex: connection.colorHex) ?? .accentColor
    }

    private var accentGradient: LinearGradient {
        LinearGradient(colors: [accentColor.opacity(0.85), accentColor.opacity(0.45)], startPoint: .top, endPoint: .bottom)
    }

    private var displayName: String {
        connection.connectionName.isEmpty ? "Untitled" : connection.connectionName
    }

    private var databaseLabel: String? {
        let trimmed = connection.database.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var identityLine: String {
        if let detail = identityDisplay.detail, !detail.isEmpty {
            return "\(identityDisplay.label) · \(detail)"
        }
        return identityDisplay.label
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            accentBadge

            VStack(alignment: .leading, spacing: 3) {
                Text(displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Label("\(connection.host):\(connection.port)", systemImage: "globe")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
                    .imageScale(.small)
                    .lineLimit(1)

                if let database = databaseLabel {
                    Label(database, systemImage: "cylinder.split.1x2")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .labelStyle(.titleAndIcon)
                        .imageScale(.small)
                        .lineLimit(1)
                }

                Label(identityLine, systemImage: identityDisplay.style.iconSymbol)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(identityDisplay.style.foreground.opacity(0.85))
                    .labelStyle(.titleAndIcon)
                    .imageScale(.small)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(
            width: ManageConnectionsLayout.tileWidth,
            height: ManageConnectionsLayout.tileHeight,
            alignment: .center
        )
        .background(
            RoundedRectangle(cornerRadius: ManageConnectionsLayout.tileCornerRadius, style: .continuous)
                .fill(tileBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ManageConnectionsLayout.tileCornerRadius, style: .continuous)
                .stroke(borderColor, lineWidth: isHovering ? 1.4 : 1)
        )
        .overlay(alignment: .trailing) {
            HoverActionStrip(isHovering: isHovering, onEdit: onEdit, onDelete: onDelete)
                .padding(6)
                .padding(.trailing, 2)
        }
        .shadow(color: shadowColor, radius: isHovering ? 10 : 6, x: 0, y: isHovering ? 8 : 4)
        .contentShape(RoundedRectangle(cornerRadius: ManageConnectionsLayout.tileCornerRadius, style: .continuous))
        .onHover { isHovering = $0 }
    }

    private var tileBackground: Color {
        if colorScheme == .dark {
            return Color(nsColor: .controlBackgroundColor).opacity(isHovering ? 0.9 : 0.78)
        }
        return Color(nsColor: .controlBackgroundColor).opacity(isHovering ? 1.0 : 0.97)
    }

    private var borderColor: Color {
        accentColor.opacity(isHovering ? 0.5 : 0.28)
    }

    private var shadowColor: Color {
        accentColor.opacity(colorScheme == .dark ? (isHovering ? 0.45 : 0.28) : (isHovering ? 0.2 : 0.1))
    }

    private var accentBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(accentGradient)
                .frame(width: 30, height: 30)
            Image(connection.databaseType.iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .foregroundStyle(Color.white)
        }
        .shadow(color: accentColor.opacity(0.25), radius: 6, x: 0, y: 4)
    }
}

private struct HoverActionStrip: View {
    let isHovering: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            HoverActionButton(systemImage: "pencil", tint: .secondary, action: onEdit)
            HoverActionButton(systemImage: "trash", tint: .red, action: onDelete)
        }
        .opacity(isHovering ? 1 : 0)
        .animation(.easeInOut(duration: 0.18), value: isHovering)
        .allowsHitTesting(isHovering)
    }
}

private struct IdentityCard: View {
    let identity: SavedIdentity
    let folderName: String
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme

    private var subtitle: String {
        identity.username.isEmpty ? "—" : identity.username
    }

    private var accentGradient: LinearGradient {
        LinearGradient(colors: [Color.purple.opacity(0.9), Color.pink.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var folderLabel: String? {
        let trimmed = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "Root" ? nil : trimmed
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            identityBadge

            VStack(alignment: .leading, spacing: 2) {
                Text(identity.name)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let folderLabel {
                    Text(folderLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(
            width: ManageConnectionsLayout.tileWidth,
            height: ManageConnectionsLayout.identityHeight,
            alignment: .center
        )
        .background(
            RoundedRectangle(cornerRadius: ManageConnectionsLayout.tileCornerRadius, style: .continuous)
                .fill(tileBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ManageConnectionsLayout.tileCornerRadius, style: .continuous)
                .stroke(borderColor, lineWidth: isHovering ? 1.4 : 1)
        )
        .overlay(alignment: .trailing) {
            HoverActionStrip(isHovering: isHovering, onEdit: onEdit, onDelete: onDelete)
                .padding(6)
                .padding(.trailing, 2)
        }
        .shadow(color: shadowColor, radius: isHovering ? 10 : 6, x: 0, y: isHovering ? 8 : 4)
        .contentShape(RoundedRectangle(cornerRadius: ManageConnectionsLayout.tileCornerRadius, style: .continuous))
        .onHover { isHovering = $0 }
    }

    private var tileBackground: Color {
        if colorScheme == .dark {
            return Color(nsColor: .controlBackgroundColor).opacity(isHovering ? 0.88 : 0.78)
        }
        return Color(nsColor: .controlBackgroundColor).opacity(isHovering ? 1.0 : 0.97)
    }

    private var borderColor: Color {
        Color.purple.opacity(isHovering ? 0.5 : 0.28)
    }

    private var shadowColor: Color {
        Color.purple.opacity(colorScheme == .dark ? (isHovering ? 0.48 : 0.3) : (isHovering ? 0.2 : 0.1))
    }

    private var identityBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(accentGradient)
                .frame(width: 28, height: 28)
            Image(systemName: "person.crop.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white)
        }
        .shadow(color: Color.purple.opacity(0.25), radius: 6, x: 0, y: 4)
    }
}

private struct HoverActionButton: View {
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
                .padding(6)
                .background(
                    Circle()
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.98))
                        .shadow(color: Color.black.opacity(0.16), radius: 4, x: 0, y: 2)
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(tint)
    }
}

private struct BreadcrumbChip: View {
    let title: String
    let isCurrent: Bool
    let isTargeted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: isCurrent ? .semibold : .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(minHeight: 26)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(chipBackground)
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(chipForeground)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(chipStroke, lineWidth: isTargeted ? 1.5 : (isCurrent ? 1.2 : 1))
        )
        .animation(.easeInOut(duration: 0.16), value: isTargeted)
        .animation(.easeInOut(duration: 0.16), value: isCurrent)
    }

    private var chipBackground: Color {
        if isTargeted { return Color.accentColor.opacity(0.22) }
        if isCurrent { return Color.accentColor.opacity(0.16) }
        return Color.primary.opacity(0.04)
    }

    private var chipForeground: Color {
        if isTargeted || isCurrent { return .accentColor }
        return .primary
    }

    private var chipStroke: Color {
        if isTargeted || isCurrent { return Color.accentColor.opacity(0.6) }
        return Color.primary.opacity(0.08)
    }
}

private struct BreadcrumbBackButton: View {
    let isTargeted: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 11, weight: .semibold))
                .padding(6)
                .background(
                    Circle()
                        .fill(isTargeted ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary)
        .animation(.easeInOut(duration: 0.16), value: isTargeted)
    }
}
