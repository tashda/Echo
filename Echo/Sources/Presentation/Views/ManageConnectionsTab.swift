import SwiftUI
import AppKit
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
    @State private var folderEditorState: FolderEditorState?
    @State private var identityEditorState: IdentityEditorState?
    @State private var pendingDeletion: DeletionTarget?
    @State private var connectionEditorPresentation: ConnectionEditorPresentation?
    
    
    private var activeSection: ManageSection { selectedSection ?? .connections }
    
    var body: some View {
        splitView
            .navigationSplitViewStyle(.balanced)
            .frame(minWidth: 800, minHeight: 560)
            .sheet(item: $folderEditorState, content: folderEditorSheet)
            .sheet(item: $identityEditorState, content: identityEditorSheet)
            .sheet(item: $connectionEditorPresentation, content: connectionEditorSheet)
            .alert("Delete Item?", isPresented: deletionAlertBinding, presenting: pendingDeletion, actions: deletionAlertActions, message: deletionAlertMessage)
            .onChange(of: appModel.selectedProject?.id) { _, _ in resetForProjectChange() }
            .onChange(of: selectedSection) { _, section in if let section { handleSectionChange(section) } }
            .onChange(of: appModel.folders) { _, _ in pruneNavigationStacks() }
            .onAppear(perform: ensureSectionSelection)
    }
    
    private func handlePrimaryAdd(for section: ManageSection) {
        switch section {
        case .connections:
            createNewConnection()
        case .identities:
            createNewIdentity()
        }
    }
    
    private var addToolbarButton: some View {
        Button {
            handlePrimaryAdd(for: activeSection)
        } label: {
            Label(activeSection == .connections ? "New Connection" : "New Identity", systemImage: "plus")
        }
        .help(activeSection == .connections ? "Create a new connection" : "Create a new identity")
    }
    
    private var splitView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 260)
        } detail: {
            mainContent
                .frame(minWidth: 560)
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .searchable(
            text: $searchText,
            placement: .toolbar,
            prompt: activeSection == .connections ? "Search Connections" : "Search Identities"
        )
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                addToolbarButton
            }
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
        ManageConnectionsSidebar(selection: $selectedSection)
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

    // MARK: - Section Detail

    @ViewBuilder
    private var connectionsDetail: some View {
        sectionList(for: .connections)
    }

    @ViewBuilder
    private var identitiesDetail: some View {
        sectionList(for: .identities)
    }

    @ViewBuilder
    private func sectionList(for section: ManageSection) -> some View {
        let tree = section == .connections ? filteredConnectionTree : filteredIdentityTree

        if tree.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: section == .connections ? "externaldrive.badge.plus" : "person.crop.circle.badge.plus")
                    .font(.system(size: 34, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.accentColor)

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
            .padding(32)
        } else {
            ManageConnectionsListView(
                tree: tree,
                section: section,
                identityDisplayProvider: identityDisplay(for:),
                onConnect: connectToConnection,
                onEditConnection: editConnection,
                onDuplicateConnection: duplicateConnection,
                onEditIdentity: editIdentity,
                onEditFolder: editFolder,
                onDelete: handleDeletion,
                onMove: { payload, targetFolderID in
                    handleMove(payload, to: targetFolderID, in: section)
                }
            )
        }
    }

    private struct ManageConnectionsListView: View {
        
        
        let tree: [ItemNode]
        let section: ManageSection
        let identityDisplayProvider: (SavedConnection) -> IdentityDisplay
        let onConnect: (SavedConnection) -> Void
        let onEditConnection: (SavedConnection) -> Void
        let onDuplicateConnection: (SavedConnection) -> Void
        let onEditIdentity: (SavedIdentity) -> Void
        let onEditFolder: (SavedFolder) -> Void
        let onDelete: (ItemNode.Payload) -> Void
        let onMove: (DragPayload, UUID?) -> Void
        
        @State private var dropTargetID: UUID?
        @State private var rootDropActive = false
        
        private let parentLookup: [UUID: UUID?]
        private let nodeLookup: [UUID: ItemNode]
        
        init(
            tree: [ItemNode],
            section: ManageSection,
            identityDisplayProvider: @escaping (SavedConnection) -> IdentityDisplay,
            onConnect: @escaping (SavedConnection) -> Void,
            onEditConnection: @escaping (SavedConnection) -> Void,
            onDuplicateConnection: @escaping (SavedConnection) -> Void,
            onEditIdentity: @escaping (SavedIdentity) -> Void,
            onEditFolder: @escaping (SavedFolder) -> Void,
            onDelete: @escaping (ItemNode.Payload) -> Void,
            onMove: @escaping (DragPayload, UUID?) -> Void
        ) {
            self.tree = tree
            self.section = section
            self.identityDisplayProvider = identityDisplayProvider
            self.onConnect = onConnect
            self.onEditConnection = onEditConnection
            self.onDuplicateConnection = onDuplicateConnection
            self.onEditIdentity = onEditIdentity
            self.onEditFolder = onEditFolder
            self.onDelete = onDelete
            self.onMove = onMove
            
            let maps = Self.buildLookups(from: tree)
            self.parentLookup = maps.parent
            self.nodeLookup = maps.nodes
        }
        
        private static func buildLookups(from nodes: [ItemNode]) -> (parent: [UUID: UUID?], nodes: [UUID: ItemNode]) {
            var parents: [UUID: UUID?] = [:]
            var nodesMap: [UUID: ItemNode] = [:]
            
            func walk(_ current: [ItemNode], parent: UUID?) {
                for node in current {
                    parents[node.id] = parent
                    nodesMap[node.id] = node
                    walk(node.children, parent: node.id)
                }
            }
            
            walk(nodes, parent: nil)
            return (parents, nodesMap)
        }
        
        var body: some View {
            List {
                OutlineGroup(tree, children: \ItemNode.childNodes) { node in
                    rowContent(for: node)
                        .contextMenu { contextMenu(for: node) }
                        .listRowBackground(rowBackground(for: node))
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(Color(nsColor: .windowBackgroundColor))
            .onDrop(of: [UTType.utf8PlainText], isTargeted: $rootDropActive) { providers in
                defer { rootDropActive = false }
                return handleDrop(providers: providers, targetFolderID: nil)
            }
        }
        
        private func rowContent(for node: ItemNode) -> some View {
            let payload = node.payload
            let isDropTarget = dropTargetID == node.id
            
            return HStack(spacing: 10) {
                icon(for: payload)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(primaryTitle(for: payload))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.primary)
                    
                    if let subtitle = subtitle(for: node) {
                        Text(subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.secondary)
                    }
                    
                    if case .connection(let connection) = payload {
                        identityBadge(for: connection)
                    }
                }
                
                Spacer(minLength: 8)
                trailingControls(for: payload)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { activate(payload) }
            .onDrag { provider(for: node) }
            .onDrop(of: [UTType.utf8PlainText], isTargeted: Binding(
                get: { dropTargetID == node.id },
                set: { isTargeted in
                    dropTargetID = isTargeted ? node.id : nil
                }
            )) { providers in
                guard case .folder(let folder) = node.payload else { return false }
                return handleDrop(providers: providers, targetFolderID: folder.id)
            }
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isDropTarget ? Color.accentColor.opacity(0.12) : Color.clear)
            )
        }
        
        private func rowBackground(for node: ItemNode) -> Color? {
            dropTargetID == node.id ? Color.accentColor.opacity(0.08) : nil
        }
        
        private func icon(for payload: ItemNode.Payload) -> some View {
            let configuration = LabelConfiguration(for: payload)
            return Image(systemName: configuration.symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(configuration.tint)
        }
        
        private func trailingControls(for payload: ItemNode.Payload) -> some View {
            HStack(spacing: 6) {
                switch payload {
                case .connection(let connection):
                    Button { onConnect(connection) } label: {
                        Label("Connect", systemImage: "bolt.horizontal.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    
                    Menu {
                        Button("Edit") { onEditConnection(connection) }
                        Button("Duplicate") { onDuplicateConnection(connection) }
                        Button("Delete", role: .destructive) { onDelete(.connection(connection)) }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .menuIndicator(.hidden)
                    
                case .folder(let folder):
                    Button { onEditFolder(folder) } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    
                case .identity(let identity):
                    Button { onEditIdentity(identity) } label: {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }
        }
        
        private func primaryTitle(for payload: ItemNode.Payload) -> String {
            switch payload {
            case .folder(let folder):
                let trimmed = folder.name.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? "Untitled Folder" : trimmed
            case .connection(let connection):
                let trimmed = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? connection.host : trimmed
            case .identity(let identity):
                return identity.name
            }
        }
        
        private func subtitle(for node: ItemNode) -> String? {
            switch node.payload {
            case .folder:
                let folderCount = node.children.filter { if case .folder = $0.payload { return true } else { return false } }.count
                let itemCount = node.children.count - folderCount
                var parts: [String] = []
                if folderCount > 0 {
                    parts.append("\(folderCount) folder\(folderCount == 1 ? "" : "s")")
                }
                if itemCount > 0 {
                    let label = section == .connections ? "connection" : "identity"
                    parts.append("\(itemCount) \(label)\(itemCount == 1 ? "" : "s")")
                }
                return parts.isEmpty ? nil : parts.joined(separator: " • ")
            case .connection(let connection):
                var components: [String] = []
                let host = connection.host.trimmingCharacters(in: .whitespacesAndNewlines)
                if !host.isEmpty { components.append(host) }
                let database = connection.database.trimmingCharacters(in: .whitespacesAndNewlines)
                if !database.isEmpty { components.append(database) }
                return components.isEmpty ? nil : components.joined(separator: " • ")
            case .identity(let identity):
                let user = identity.username.trimmingCharacters(in: .whitespacesAndNewlines)
                return user.isEmpty ? nil : user
            }
        }
        
        private func identityBadge(for connection: SavedConnection) -> some View {
            let display = identityDisplayProvider(connection)
            return Group {
                if display.label.isEmpty {
                    EmptyView()
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: display.style.iconSymbol)
                            .font(.system(size: 10, weight: .semibold))
                        Text(display.label)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(display.style.foreground)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: display.style.pillBackgroundColor))
                    .clipShape(Capsule())
                }
            }
        }
        
        private func provider(for node: ItemNode) -> NSItemProvider {
            let payload: DragPayload
            switch node.payload {
            case .connection(let connection):
                payload = .connection(connection.id)
            case .identity(let identity):
                payload = .identity(identity.id)
            case .folder(let folder):
                payload = .folder(folder.id, folder.kind)
            }
            return NSItemProvider(object: payload.stringValue as NSString)
        }
        
        private func handleDrop(providers: [NSItemProvider], targetFolderID: UUID?) -> Bool {
            guard let payload = extractPayload(from: providers) else { return false }
            guard canDrop(payload, into: targetFolderID) else { return false }
            onMove(payload, targetFolderID)
            dropTargetID = nil
            return true
        }
        
        private func extractPayload(from providers: [NSItemProvider]) -> DragPayload? {
            guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.utf8PlainText.identifier) }) else { return nil }
            let semaphore = DispatchSemaphore(value: 0)
            var result: DragPayload?
            provider.loadItem(forTypeIdentifier: UTType.utf8PlainText.identifier, options: nil) { item, _ in
                defer { semaphore.signal() }
                if let data = item as? Data, let string = String(data: data, encoding: .utf8) {
                    result = DragPayload(string: string)
                } else if let string = item as? String {
                    result = DragPayload(string: string)
                }
            }
            semaphore.wait()
            return result
        }
        
        private func activate(_ payload: ItemNode.Payload) {
            switch payload {
            case .folder:
                break
            case .connection(let connection):
                onConnect(connection)
            case .identity(let identity):
                onEditIdentity(identity)
            }
        }
        
        private func canDrop(_ payload: DragPayload, into destinationFolderID: UUID?) -> Bool {
            switch section {
            case .connections:
                switch payload {
                case .connection:
                    return true
                case .folder(let folderID, let kind):
                    guard kind == .connections else { return false }
                    return !isInvalidFolderMove(folderID: folderID, destinationFolderID: destinationFolderID)
                case .identity:
                    return false
                }
            case .identities:
                switch payload {
                case .identity:
                    return true
                case .folder(let folderID, let kind):
                    guard kind == .identities else { return false }
                    return !isInvalidFolderMove(folderID: folderID, destinationFolderID: destinationFolderID)
                case .connection:
                    return false
                }
            }
        }
        
        private func isInvalidFolderMove(folderID: UUID, destinationFolderID: UUID?) -> Bool {
            guard let destination = destinationFolderID else { return false }
            if destination == folderID { return true }
            var current = parentLookup[destination] ?? nil
            while let ancestor = current {
                if ancestor == folderID { return true }
                current = parentLookup[ancestor] ?? nil
            }
            return false
        }
        
        @ViewBuilder
        private func contextMenu(for node: ItemNode) -> some View {
            switch node.payload {
            case .folder(let folder):
                Button("Rename") { onEditFolder(folder) }
                Button("Delete", role: .destructive) { onDelete(.folder(folder)) }
            case .connection(let connection):
                Button("Connect") { onConnect(connection) }
                Button("Edit") { onEditConnection(connection) }
                Button("Delete", role: .destructive) { onDelete(.connection(connection)) }
            case .identity(let identity):
                Button("Edit") { onEditIdentity(identity) }
                Button("Delete", role: .destructive) { onDelete(.identity(identity)) }
            }
        }
        
        private struct LabelConfiguration {
            let symbol: String
            let tint: Color
            
            init(for payload: ItemNode.Payload) {
                switch payload {
                case .folder:
                    symbol = "folder"
                    tint = Color(nsColor: .controlAccentColor)
                case .connection:
                    symbol = "server.rack"
                    tint = Color(nsColor: .systemBlue)
                case .identity:
                    symbol = "person.crop.circle"
                    tint = Color(nsColor: .systemPurple)
                }
            }
        }
    }

    // MARK: - Actions

    private func handleConnectionEditorSave(
        connection: SavedConnection,
        password: String?,
        action: ConnectionEditorView.SaveAction
    ) {
        Task {
            await appModel.upsertConnection(connection, password: password)

            await MainActor.run {
                selectedSection = .connections
                appModel.selectedFolderID = connection.folderID
                if action == .saveAndConnect {
                    appModel.selectedConnectionID = connection.id
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

    private func handleDeletion(_ payload: ItemNode.Payload) {
        switch payload {
        case .folder(let folder):
            pendingDeletion = .folder(folder)
        case .connection(let connection):
            pendingDeletion = .connection(connection)
        case .identity(let identity):
            pendingDeletion = .identity(identity)
        }
    }

    private func performDeletion(for target: DeletionTarget) {
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

    private func createNewConnection(in folder: SavedFolder? = nil) {
        selectedSection = .connections
        let parent = folder ?? defaultFolder(for: .connections)
        appModel.selectedFolderID = parent?.id
        connectionEditorPresentation = ConnectionEditorPresentation(connection: nil)
    }

    private func editConnection(_ connection: SavedConnection) {
        selectedSection = .connections
        appModel.selectedFolderID = connection.folderID
        connectionEditorPresentation = ConnectionEditorPresentation(connection: connection)
    }

    private func duplicateConnection(_ connection: SavedConnection) {
        Task { await appModel.duplicateConnection(connection) }
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

    private func createNewIdentity(in folder: SavedFolder? = nil) {
        selectedSection = .identities
        let parent = folder ?? defaultFolder(for: .identities)
        identityEditorState = .create(parent: parent, token: UUID())
    }

    private func editIdentity(_ identity: SavedIdentity) {
        identityEditorState = .edit(identity: identity)
    }

    private func editFolder(_ folder: SavedFolder) {
        folderEditorState = .edit(folder: folder)
    }

    private func defaultFolder(for section: ManageSection) -> SavedFolder? {
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

    private func folder(withID id: UUID) -> SavedFolder? {
        appModel.folders.first(where: { $0.id == id })
    }

    private func handleMove(_ payload: DragPayload, to targetFolderID: UUID?, in section: ManageSection) {
        switch payload {
        case .connection(let id):
            guard section == .connections else { return }
            appModel.moveConnection(id, toFolder: targetFolderID)
        case .identity(let id):
            guard section == .identities else { return }
            appModel.moveIdentity(id, toFolder: targetFolderID)
        case .folder(let id, let kind):
            guard kind == section.folderKind else { return }
            appModel.moveFolder(id, toParent: targetFolderID)
        }
    }

    // MARK: - Selection & Lifecycle

    private func resetForProjectChange() {
        searchText = ""
        pendingDeletion = nil
        connectionEditorPresentation = nil
        folderEditorState = nil
        identityEditorState = nil
        pruneNavigationStacks()
        ensureSectionSelection()
    }

    private func handleSectionChange(_ section: ManageSection) {
        searchText = ""
        if section == .connections {
            appModel.selectedIdentityID = nil
        }
    }

    private func pruneNavigationStacks() {
        guard let projectID = selectedProjectID else {
            appModel.selectedFolderID = nil
            appModel.selectedIdentityID = nil
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
        return trimmed.isEmpty ? nil : trimmed.lowercased()
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
                let children = buildNodes(
                    parentID: folder.id,
                    folderMap: folderMap,
                    connectionMap: connectionMap,
                    identityMap: identityMap
                )
                let connections = (connectionMap?[folder.id] ?? []).map { ItemNode(payload: .connection($0), children: []) }
                let identities = (identityMap?[folder.id] ?? []).map { ItemNode(payload: .identity($0), children: []) }
                nodes.append(ItemNode(payload: .folder(folder), children: children + connections + identities))
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

    private func identityDisplay(for connection: SavedConnection) -> IdentityDisplay {
        switch connection.credentialSource {
        case .identity:
            if let identityID = connection.identityID,
               let identity = identityLookup[identityID] {
                let detail = identity.username.trimmingCharacters(in: .whitespacesAndNewlines)
                return IdentityDisplay(label: identity.name, detail: detail.isEmpty ? nil : detail, style: .identity)
            }
            return IdentityDisplay(label: "Linked Identity", detail: nil, style: .identity)
        case .inherit:
            return IdentityDisplay(label: "Inherited Credentials", detail: nil, style: .inherit)
        case .manual:
            let detail = connection.username.trimmingCharacters(in: .whitespacesAndNewlines)
            return IdentityDisplay(label: "Manual Credentials", detail: detail.isEmpty ? nil : detail, style: .manual)
        }
    }

    private struct ManageConnectionsSidebar: View {
        @Binding var selection: ManageSection?
        
        var body: some View {
            List(selection: $selection) {
                ForEach(ManageSection.allCases) { section in
                    NavigationLink(value: section) {
                        Label(section.title, systemImage: section.icon)
                    }
                    .tag(section)
                }
            }
            .listStyle(.sidebar)
            .onAppear {
                if selection == nil {
                    selection = .connections
                }
            }
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
}

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

    func matches(_ query: String, section: ManageSection, identityLookup: [UUID: SavedIdentity]) -> Bool {
        switch payload {
        case .folder(let folder):
            return folder.name.lowercased().contains(query)
        case .connection(let connection):
            let lowercasedName = connection.connectionName.lowercased()
            if lowercasedName.contains(query) { return true }
            if connection.host.lowercased().contains(query) { return true }
            if connection.database.lowercased().contains(query) { return true }
            if connection.username.lowercased().contains(query) { return true }
            if let identityID = connection.identityID,
               let identity = identityLookup[identityID],
               identity.name.lowercased().contains(query) {
                return true
            }
            return false
        case .identity(let identity):
            if identity.name.lowercased().contains(query) { return true }
            return identity.username.lowercased().contains(query)
        }
    }
}

private struct IdentityDisplay {
    enum Style {
        case identity
        case inherit
        case manual

        var foreground: Color {
            switch self {
            case .identity: return Color(nsColor: .systemPurple)
            case .inherit: return Color(nsColor: .systemTeal)
            case .manual: return .secondary
            }
        }

        var iconSymbol: String {
            switch self {
            case .identity: return "person.crop.circle"
            case .inherit: return "arrow.triangle.branch"
            case .manual: return "key.fill"
            }
        }

        var pillBackgroundColor: NSColor {
            switch self {
            case .identity: return NSColor.systemPurple.withAlphaComponent(0.12)
            case .inherit: return NSColor.systemTeal.withAlphaComponent(0.12)
            case .manual: return NSColor.controlAccentColor.withAlphaComponent(0.1)
            }
        }
    }

    let label: String
    let detail: String?
    let style: Style
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
