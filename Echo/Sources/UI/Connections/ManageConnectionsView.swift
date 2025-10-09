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

struct ManageConnectionsView: View {
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
    @State private var pendingDuplicateConnection: SavedConnection?
    
    
    private var activeSection: ManageSection { selectedSection ?? .connections }
    
    var body: some View {
        splitView
            .navigationSplitViewStyle(.balanced)
            .frame(minWidth: 800, minHeight: 560)
            .sheet(item: $folderEditorState, content: folderEditorSheet)
            .sheet(item: $identityEditorState, content: identityEditorSheet)
            .sheet(item: $connectionEditorPresentation, content: connectionEditorSheet)
            .alert("Delete Item?", isPresented: deletionAlertBinding, presenting: pendingDeletion, actions: deletionAlertActions, message: deletionAlertMessage)
            .confirmationDialog(
                "Duplicate Connection",
                isPresented: Binding(
                    get: { pendingDuplicateConnection != nil },
                    set: { isPresented in if !isPresented { pendingDuplicateConnection = nil } }
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
    
    private var splitView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 260)
        } detail: {
            mainContent
                .frame(minWidth: 560)
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .toolbar(.hidden, for: .windowToolbar)
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
                searchText: $searchText,
                identityDecorationProvider: identityDecoration(for:),
                folderDecorationProvider: folderDecoration(for:),
                onConnect: connectToConnection,
                onEditConnection: editConnection,
                onDuplicateConnection: duplicateConnection,
                onEditIdentity: editIdentity,
                onEditFolder: editFolder,
                onDelete: handleDeletion,
                onMove: { payload, targetFolderID in
                    handleMove(payload, to: targetFolderID, in: section)
                },
                onPrimaryAdd: { handlePrimaryAdd(for: section) },
                onCreateFolder: { createNewFolder(for: section) }
            )
        }
    }

    private struct ManageConnectionsListView: View {


        let tree: [ItemNode]
        let section: ManageSection
        let searchText: Binding<String>
        let identityDecorationProvider: (SavedConnection) -> IdentityDecoration?
        let folderDecorationProvider: (SavedFolder) -> IdentityDecoration?
        let onConnect: (SavedConnection) -> Void
        let onEditConnection: (SavedConnection) -> Void
        let onDuplicateConnection: (SavedConnection) -> Void
        let onEditIdentity: (SavedIdentity) -> Void
        let onEditFolder: (SavedFolder) -> Void
        let onDelete: (ItemNode.Payload) -> Void
        let onMove: (DragPayload, UUID?) -> Void
        let onPrimaryAdd: () -> Void
        let onCreateFolder: () -> Void

        @State private var dropTargetID: UUID?
        @State private var rootDropActive = false
        @State private var hoveredNodeID: UUID?
        @State private var isProcessingDrop = false

        private let parentLookup: [UUID: UUID?]

        init(
            tree: [ItemNode],
            section: ManageSection,
            searchText: Binding<String>,
            identityDecorationProvider: @escaping (SavedConnection) -> IdentityDecoration?,
            folderDecorationProvider: @escaping (SavedFolder) -> IdentityDecoration?,
            onConnect: @escaping (SavedConnection) -> Void,
            onEditConnection: @escaping (SavedConnection) -> Void,
            onDuplicateConnection: @escaping (SavedConnection) -> Void,
            onEditIdentity: @escaping (SavedIdentity) -> Void,
            onEditFolder: @escaping (SavedFolder) -> Void,
            onDelete: @escaping (ItemNode.Payload) -> Void,
            onMove: @escaping (DragPayload, UUID?) -> Void,
            onPrimaryAdd: @escaping () -> Void,
            onCreateFolder: @escaping () -> Void
        ) {
            self.tree = tree
            self.section = section
            self.searchText = searchText
            self.identityDecorationProvider = identityDecorationProvider
            self.folderDecorationProvider = folderDecorationProvider
            self.onConnect = onConnect
            self.onEditConnection = onEditConnection
            self.onDuplicateConnection = onDuplicateConnection
            self.onEditIdentity = onEditIdentity
            self.onEditFolder = onEditFolder
            self.onDelete = onDelete
            self.onMove = onMove
            self.onPrimaryAdd = onPrimaryAdd
            self.onCreateFolder = onCreateFolder

            self.parentLookup = Self.buildParentLookup(from: tree)
        }

        private static func buildParentLookup(from nodes: [ItemNode]) -> [UUID: UUID?] {
            var parents: [UUID: UUID?] = [:]

            func walk(_ current: [ItemNode], parent: UUID?) {
                for node in current {
                    parents[node.id] = parent
                    walk(node.children, parent: node.id)
                }
            }

            walk(nodes, parent: nil)
            return parents
        }

        var body: some View {
            List {
                OutlineGroup(tree, children: \ItemNode.childNodes) { node in
                    nodeRow(for: node, isHovered: hoveredNodeID == node.id)
                        .contentShape(Rectangle())
                        .listRowBackground(rowBackground(for: node))
                        .contextMenu { contextMenu(for: node) }
                        .onTapGesture(count: 2) { activate(node.payload) }
                        .onDrag { provider(for: node) }
                        .onDrop(of: [UTType.utf8PlainText], isTargeted: dropTargetBinding(for: node)) { providers in
                            handleDrop(providers: providers, targetFor: node)
                        }
                        .onHover { isHovering in
                            hoveredNodeID = isHovering ? node.id : (hoveredNodeID == node.id ? nil : hoveredNodeID)
                        }
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .alternatingRowBackgrounds()
            .environment(\.defaultMinListRowHeight, 40)
            .onDrop(of: [UTType.utf8PlainText], isTargeted: $rootDropActive) { providers in
                defer { rootDropActive = false }
                guard dropTargetID == nil else { return false }
                return handleDrop(providers: providers, targetFolderID: nil)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomBar
            }
            .overlay(alignment: .topTrailing) {
                searchField
            }
        }

        private var searchField: some View {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(section.searchPlaceholder, text: searchText)
                    .textFieldStyle(.plain)
                    .frame(width: 200)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08))
            )
            .padding(.top, 12)
            .padding(.trailing, 16)
        }

        private var bottomBar: some View {
            HStack(spacing: 8) {
                Button(action: onPrimaryAdd) {
                    Image(systemName: section.primaryAddSymbol)
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help(section.primaryAddHelp)
                .tint(Color(nsColor: .controlAccentColor))

                Button(action: onCreateFolder) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help(section.createFolderHelp)
                .tint(Color(nsColor: .controlAccentColor))

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .overlay(alignment: .top) { Divider() }
        }

        private func dropTargetBinding(for node: ItemNode) -> Binding<Bool> {
            let isFolder: Bool
            if case .folder = node.payload {
                isFolder = true
            } else {
                isFolder = false
            }

            return Binding(
                get: { isFolder && dropTargetID == node.id },
                set: { isTargeted in
                    guard isFolder else {
                        dropTargetID = nil
                        return
                    }
                    dropTargetID = isTargeted ? node.id : nil
                }
            )
        }

        private func rowBackground(for node: ItemNode) -> Color? {
            dropTargetID == node.id ? Color.accentColor.opacity(0.08) : nil
        }

        private func handleDrop(providers: [NSItemProvider], targetFor node: ItemNode) -> Bool {
            guard case .folder(let folder) = node.payload else { return false }
            return handleDrop(providers: providers, targetFolderID: folder.id)
        }

        @ViewBuilder
        private func nodeRow(for node: ItemNode, isHovered: Bool) -> some View {
            switch node.payload {
            case .folder(let folder):
                folderRow(folder, summary: subtitle(for: node), isHovered: isHovered)
            case .connection(let connection):
                connectionRow(connection, summary: subtitle(for: node), isHovered: isHovered)
            case .identity(let identity):
                identityRow(identity, summary: subtitle(for: node), isHovered: isHovered)
            }
        }

        private func folderRow(_ folder: SavedFolder, summary: String?, isHovered: Bool) -> some View {
            let decoration = folderDecorationProvider(folder)

            return HStack(spacing: 12) {
                Image(systemName: "folder")
                    .symbolVariant(.fill)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(Color(nsColor: .controlAccentColor))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(primaryTitle(for: .folder(folder)))
                            .font(.body.weight(.medium))
                        if let decoration {
                            IdentityBubble(decoration: decoration)
                        }
                    }

                    if let summary {
                        Text(summary)
                            .font(.system(size: 12))
                            .italic()
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 12)

                Menu {
                    Button("Edit") { onEditFolder(folder) }
                    Button("Delete", role: .destructive) { onDelete(.folder(folder)) }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                }
                .menuIndicator(.hidden)
                .controlSize(.small)
                .menuStyle(BorderlessButtonMenuStyle())
                .opacity(isHovered ? 1 : 0)
                .allowsHitTesting(isHovered)
            }
            .frame(minHeight: 44, alignment: .center)
            .padding(.vertical, 2)
        }

        private func connectionRow(_ connection: SavedConnection, summary: String?, isHovered: Bool) -> some View {
            let decoration = identityDecorationProvider(connection)

            return HStack(spacing: 12) {
                Image(systemName: "server.rack")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(nsColor: .systemBlue))
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(primaryTitle(for: .connection(connection)))
                            .font(.body.weight(.medium))
                        if let decoration {
                            IdentityBubble(decoration: decoration)
                        }
                    }

                    if let summary {
                        Text(summary)
                            .font(.system(size: 12))
                            .italic()
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 12)

                HStack(spacing: 8) {
                    Button(action: { onConnect(connection) }) {
                        Image(systemName: "bolt.horizontal")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .help("Connect")

                    Menu {
                        Button("Edit") { onEditConnection(connection) }
                        Button("Duplicate") { onDuplicateConnection(connection) }
                        Divider()
                        Button("Delete", role: .destructive) { onDelete(.connection(connection)) }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .menuIndicator(.hidden)
                    .controlSize(.small)
                    .menuStyle(BorderlessButtonMenuStyle())
                }
                .opacity(isHovered ? 1 : 0)
                .allowsHitTesting(isHovered)
            }
            .frame(minHeight: 44, alignment: .center)
            .padding(.vertical, 2)
        }

        private func identityRow(_ identity: SavedIdentity, summary: String?, isHovered: Bool) -> some View {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(Color(nsColor: .systemPurple))
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 3) {
                    Text(primaryTitle(for: .identity(identity)))
                        .font(.body.weight(.medium))
                    if let summary {
                        Text(summary)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 12)

                Menu {
                    Button("Edit") { onEditIdentity(identity) }
                    Divider()
                    Button("Delete", role: .destructive) { onDelete(.identity(identity)) }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                }
                .menuIndicator(.hidden)
                .controlSize(.small)
                .menuStyle(BorderlessButtonMenuStyle())
                .opacity(isHovered ? 1 : 0)
                .allowsHitTesting(isHovered)
            }
            .frame(minHeight: 44, alignment: .center)
            .padding(.vertical, 2)
        }

        private struct IdentityBubble: View {
            let decoration: IdentityDecoration

            var body: some View {
                Image(systemName: decoration.symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(decoration.tint)
                    .frame(width: 16, height: 16)
                    .background(
                        Circle()
                            .fill(decoration.tint.opacity(0.18))
                    )
                    .overlay(
                        Circle()
                            .stroke(decoration.tint.opacity(0.35), lineWidth: 0.5)
                    )
                    .help(decoration.tooltip ?? "")
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
            guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else { return false }

            if isProcessingDrop { return false }
            isProcessingDrop = true

            provider.loadObject(ofClass: NSString.self) { object, _ in
                guard let string = object as? String,
                      let payload = DragPayload(string: string) else {
                    DispatchQueue.main.async {
                        isProcessingDrop = false
                        dropTargetID = nil
                    }
                    return
                }

                DispatchQueue.main.async {
                    defer {
                        dropTargetID = nil
                        isProcessingDrop = false
                    }

                    guard canDrop(payload, into: targetFolderID) else { return }
                    onMove(payload, targetFolderID)
                }
            }

            return true
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
                Button("Edit") { onEditFolder(folder) }
                Button("Delete", role: .destructive) { onDelete(.folder(folder)) }
            case .connection(let connection):
                Button("Connect") { onConnect(connection) }
                Button("Edit") { onEditConnection(connection) }
                Button("Duplicate") { onDuplicateConnection(connection) }
                Button("Delete", role: .destructive) { onDelete(.connection(connection)) }
            case .identity(let identity):
                Button("Edit") { onEditIdentity(identity) }
                Button("Delete", role: .destructive) { onDelete(.identity(identity)) }
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
                    appModel.isManageConnectionsPresented = false
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
        pendingDuplicateConnection = connection
    }

    private func performDuplicate(_ connection: SavedConnection, copyBookmarks: Bool) {
        Task {
            pendingDuplicateConnection = nil
            await appModel.duplicateConnection(connection, copyBookmarks: copyBookmarks)
        }
    }

    private func connectToConnection(_ connection: SavedConnection) {
        Task {
            await appModel.connect(to: connection)
            await MainActor.run {
                appModel.isManageConnectionsPresented = false
                dismiss()
            }
        }
    }

    private func createNewIdentity(in folder: SavedFolder? = nil) {
        selectedSection = .identities
        let parent = folder ?? defaultFolder(for: .identities)
        identityEditorState = .create(parent: parent, token: UUID())
    }

    private func createNewFolder(for section: ManageSection, parent: SavedFolder? = nil) {
        folderEditorState = .create(kind: section.folderKind, parent: parent, token: UUID())
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
                nodes.append(ItemNode(payload: .folder(folder), children: children))
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

    private func identityDecoration(for connection: SavedConnection) -> IdentityDecoration? {
        switch connection.credentialSource {
        case .identity:
            guard let identityID = connection.identityID,
                  let identity = identityLookup[identityID] else {
                return IdentityDecoration(
                    symbol: "person.fill",
                    tint: Color(nsColor: .systemPurple),
                    tooltip: "Linked Identity"
                )
            }

            var tooltip = identity.name
            let detail = identity.username.trimmingCharacters(in: .whitespacesAndNewlines)
            if !detail.isEmpty {
                tooltip += " — \(detail)"
            }

            return IdentityDecoration(
                symbol: "person.fill",
                tint: Color(nsColor: .systemPurple),
                tooltip: tooltip
            )

        case .inherit:
            return IdentityDecoration(
                symbol: "arrow.triangle.branch",
                tint: Color(nsColor: .systemTeal),
                tooltip: "Inherited credentials"
            )

        case .manual:
            let username = connection.username.trimmingCharacters(in: .whitespacesAndNewlines)
            let tooltip = username.isEmpty ? "Manual credentials" : "Manual credentials — \(username)"
            return IdentityDecoration(
                symbol: "key.fill",
                tint: Color(nsColor: .systemBlue),
                tooltip: tooltip
            )
        }
    }

    private func folderDecoration(for folder: SavedFolder) -> IdentityDecoration? {
        switch folder.credentialMode {
        case .none:
            return nil
        case .manual:
            let username = folder.manualUsername?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let tooltip = username.isEmpty ? "Manual credentials" : "Manual credentials — \(username)"
            return IdentityDecoration(
                symbol: "key.fill",
                tint: Color(nsColor: .systemBlue),
                tooltip: tooltip
            )
        case .identity:
            guard let identityID = folder.identityID,
                  let identity = identityLookup[identityID] else {
                return IdentityDecoration(
                    symbol: "person.fill",
                    tint: Color(nsColor: .systemPurple),
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
                tint: Color(nsColor: .systemPurple),
                tooltip: tooltip
            )
        case .inherit:
            return IdentityDecoration(
                symbol: "arrow.triangle.branch",
                tint: Color(nsColor: .systemTeal),
                tooltip: "Inherits credentials"
            )
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
            .scrollContentBackground(.hidden)
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

    var primaryAddSymbol: String { "plus" }

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

    var searchPlaceholder: String {
        switch self {
        case .connections: return "Search connections"
        case .identities: return "Search identities"
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

private struct IdentityDecoration {
    let symbol: String
    let tint: Color
    let tooltip: String?
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
