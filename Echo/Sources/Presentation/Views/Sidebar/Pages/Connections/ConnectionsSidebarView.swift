import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

struct ConnectionsSidebarView: View {
    @EnvironmentObject private var appModel: AppModel

    @Binding var selectedConnectionID: UUID?
    @Binding var selectedIdentityID: UUID?

    let onCreateConnection: (SavedFolder?) -> Void
    let onEditConnection: (SavedConnection) -> Void
    let onConnect: (SavedConnection) -> Void
    let onMoveConnection: (UUID, UUID?) -> Void
    let onMoveFolder: (UUID, UUID?) -> Void
    let onDuplicateConnection: (SavedConnection) -> Void

    @State private var expandedConnectionFolders: Set<UUID> = []
    @State private var expandedIdentityFolders: Set<UUID> = []
    @State private var folderEditorState: FolderEditorState?
    @State private var identityEditorState: IdentityEditorState?
    @State private var pendingDeletion: DeletionTarget?
    @State private var activeDropTarget: DropTarget?

    private var connectionItems: [SidebarItem] { buildConnectionItems(parentID: nil) }
    private var identityItems: [IdentityNode] { buildIdentityItems(parentID: nil) }

    var body: some View {
        VStack(spacing: 0) {
            addToolbar
            Divider()
            List {
                Section(header: Text("Connections")) {
                    connectionsSection
                }

                Section(header: Text("Identities")) {
                    identitiesSection
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.sidebar)
        }
        .contextMenu { contextMenuContent() }
        .sheet(item: $folderEditorState) { state in
            FolderEditorSheet(state: state)
                .environmentObject(appModel)
        }
        .sheet(item: $identityEditorState) { state in
            IdentityEditorSheet(state: state)
                .environmentObject(appModel)
        }
        .alert(
            "Delete Item?",
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            presenting: pendingDeletion
        ) { target in
            Button("Delete", role: .destructive) { performDeletion(for: target) }
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
        } message: { target in
            Text("Are you sure you want to delete \(target.displayName)? This action cannot be undone.")
        }
    }

    private var addToolbar: some View {
        HStack {
            Spacer()
            Menu {
                menuContent()
            } label: {
                Label("Add new", systemImage: "plus")
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(Color.secondary.opacity(0.15))
                    )
            }
            .menuStyle(.borderlessButton)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(addToolbarHighlight)
        .onDrop(of: [.utf8PlainText], delegate: ConnectionsDropDelegate(
            targetFolderID: nil,
            targetKind: .connections,
            activeDropTarget: $activeDropTarget,
            onMoveConnection: onMoveConnection,
            onMoveFolder: onMoveFolder
        ))
    }

    private var addToolbarHighlight: Color {
        activeDropTarget == DropTarget(folderID: nil, kind: .connections) ? Color.accentColor.opacity(0.12) : .clear
    }

    @ViewBuilder
    private var connectionsSection: some View {
        if connectionItems.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "externaldrive")
                    .font(.system(size: 32))
                    .foregroundStyle(.tertiary)
                Text("No Connections")
                    .font(.headline)
                Text("Use the plus button to add your first connection or organize folders.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .listRowBackground(Color.clear)
        } else {
            DropInsertionRow(isActive: activeDropTarget == DropTarget(folderID: nil, kind: .connections))
                .onDrop(of: [.utf8PlainText], delegate: ConnectionsDropDelegate(
                    targetFolderID: nil,
                    targetKind: .connections,
                    activeDropTarget: $activeDropTarget,
                    onMoveConnection: onMoveConnection,
                    onMoveFolder: onMoveFolder
                ))
                .listRowBackground(Color.clear)

            ForEach(connectionItems, id: \.id) { item in
                ConnectionSidebarItemView(
                    item: item,
                    selectedConnectionID: $selectedConnectionID,
                    expandedFolders: $expandedConnectionFolders,
                    activeDropTarget: $activeDropTarget,
                    onCreateConnection: onCreateConnection,
                    onCreateFolder: { parent in openFolderCreator(kind: .connections, parent: parent) },
                    onEditConnection: { connection in
                        selectedConnectionID = connection.id
                        onEditConnection(connection)
                    },
                    onEditFolder: { folder in openFolderEditor(folder) },
                    onDelete: { target in pendingDeletion = target },
                    onConnect: { connection in
                        selectedConnectionID = connection.id
                        onConnect(connection)
                    },
                    onSelectFolder: { folder in appModel.selectedFolderID = folder.id },
                    onDuplicate: { connection in onDuplicateConnection(connection) },
                    onMoveConnection: onMoveConnection,
                    onMoveFolder: onMoveFolder
                )
            }

            DropInsertionRow(isActive: activeDropTarget == DropTarget(folderID: nil, kind: .connections))
                .onDrop(of: [.utf8PlainText], delegate: ConnectionsDropDelegate(
                    targetFolderID: nil,
                    targetKind: .connections,
                    activeDropTarget: $activeDropTarget,
                    onMoveConnection: onMoveConnection,
                    onMoveFolder: onMoveFolder
                ))
                .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private var identitiesSection: some View {
        if identityItems.isEmpty && appModel.identities.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 32))
                    .foregroundStyle(.tertiary)
                Text("No Identities")
                    .font(.headline)
                Text("Create identities to reuse credentials across multiple connections.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .listRowBackground(Color.clear)
        } else {
            DropInsertionRow(isActive: activeDropTarget == DropTarget(folderID: nil, kind: .identities))
                .onDrop(of: [.utf8PlainText], delegate: ConnectionsDropDelegate(
                    targetFolderID: nil,
                    targetKind: .identities,
                    activeDropTarget: $activeDropTarget,
                    onMoveConnection: onMoveConnection,
                    onMoveFolder: onMoveFolder
                ))
                .listRowBackground(Color.clear)

            ForEach(identityItems) { item in
                IdentityNodeView(
                    node: item,
                    selectedIdentityID: $selectedIdentityID,
                    expandedFolders: $expandedIdentityFolders,
                    onCreateIdentity: { parent in openIdentityCreator(parent: parent) },
                    onCreateFolder: { parent in openFolderCreator(kind: .identities, parent: parent) },
                    onEditIdentity: { identity in
                        selectedIdentityID = identity.id
                        openIdentityEditor(identity)
                    },
                    onEditFolder: { folder in openFolderEditor(folder) },
                    onDelete: { target in pendingDeletion = target }
                )
            }

            DropInsertionRow(isActive: activeDropTarget == DropTarget(folderID: nil, kind: .identities))
                .onDrop(of: [.utf8PlainText], delegate: ConnectionsDropDelegate(
                    targetFolderID: nil,
                    targetKind: .identities,
                    activeDropTarget: $activeDropTarget,
                    onMoveConnection: onMoveConnection,
                    onMoveFolder: onMoveFolder
                ))
                .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private func menuContent() -> some View {
        Section("Connections") {
            Button("New Connection", systemImage: "externaldrive.badge.plus") {
                onCreateConnection(selectedConnectionFolder)
            }
            Button("New Connection Folder", systemImage: "folder.badge.plus") {
                openFolderCreator(kind: .connections, parent: selectedConnectionFolder)
            }
        }

        Section("Identities") {
            Button("New Identity", systemImage: "person.badge.plus") {
                openIdentityCreator(parent: selectedIdentityFolder)
            }
            Button("New Identity Folder", systemImage: "folder.badge.plus") {
                let parent = appModel.folders.first(where: { $0.kind == .identities && $0.id == selectedIdentityParentID })
                openFolderCreator(kind: .identities, parent: parent)
            }
        }
    }

    @ViewBuilder
    private func contextMenuContent() -> some View {
        Button {
            onCreateConnection(selectedConnectionFolder)
        } label: {
            Label("New Connection", systemImage: "externaldrive.badge.plus")
        }
        Button {
            openFolderCreator(kind: .connections, parent: selectedConnectionFolder)
        } label: {
            Label("New Connection Folder", systemImage: "folder.badge.plus")
        }
        Divider()
        Button {
            openIdentityCreator(parent: selectedIdentityFolder)
        } label: {
            Label("New Identity", systemImage: "person.badge.plus")
        }
        Button {
            let parent = appModel.folders.first(where: { $0.kind == .identities && $0.id == selectedIdentityParentID })
            openFolderCreator(kind: .identities, parent: parent)
        } label: {
            Label("New Identity Folder", systemImage: "folder.badge.plus")
        }
    }

    private var selectedIdentityParentID: UUID? {
        if let identityID = selectedIdentityID,
           let identity = appModel.identities.first(where: { $0.id == identityID }) {
            return identity.folderID
        }
        return nil
    }

    private var selectedIdentityFolder: SavedFolder? {
        selectedIdentityParentID.flatMap { id in
            appModel.folders.first { $0.id == id && $0.kind == .identities }
        }
    }

    private var selectedConnectionFolder: SavedFolder? {
        guard let id = appModel.selectedFolderID else { return nil }
        return appModel.folders.first { $0.id == id && $0.kind == .connections }
    }

    private func openFolderCreator(kind: FolderKind, parent: SavedFolder?) {
        folderEditorState = .create(kind: kind, parent: parent, token: UUID())
    }

    private func openFolderEditor(_ folder: SavedFolder) {
        folderEditorState = .edit(folder: folder)
    }

    private func openIdentityCreator(parent: SavedFolder?) {
        identityEditorState = .create(parent: parent, token: UUID())
    }

    private func openIdentityEditor(_ identity: SavedIdentity) {
        identityEditorState = .edit(identity: identity)
    }

    private func performDeletion(for target: DeletionTarget) {
        pendingDeletion = nil
        switch target {
        case .connection(let connection):
            Task { await appModel.deleteConnection(connection) }
        case .folder(let folder):
            Task { await appModel.deleteFolder(folder) }
        case .identity(let identity):
            Task { await appModel.deleteIdentity(identity) }
        }
    }

    private func buildConnectionItems(parentID: UUID?) -> [SidebarItem] {
        let currentProjectID = appModel.selectedProject?.id
        let folders = appModel.folders
            .filter { $0.kind == .connections && $0.parentFolderID == parentID && $0.projectID == currentProjectID }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let connections = appModel.connections
            .filter { $0.folderID == parentID && $0.projectID == currentProjectID }
            .sorted { $0.connectionName.localizedCaseInsensitiveCompare($1.connectionName) == .orderedAscending }

        var items: [SidebarItem] = folders.map { folder in
            var copy = folder
            copy.children = buildConnectionItems(parentID: folder.id)
            return .folder(copy)
        }
        items += connections.map { .connection($0) }
        return items
    }

    private func buildIdentityItems(parentID: UUID?) -> [IdentityNode] {
        let currentProjectID = appModel.selectedProject?.id
        let folders = appModel.folders
            .filter { $0.kind == .identities && $0.parentFolderID == parentID && $0.projectID == currentProjectID }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let identities = appModel.identities
            .filter { $0.folderID == parentID && $0.projectID == currentProjectID }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        var items: [IdentityNode] = folders.map { folder in
            IdentityNode(kind: .folder(folder), children: buildIdentityItems(parentID: folder.id))
        }
        items += identities.map { IdentityNode(kind: .identity($0)) }
        return items
    }
}

// MARK: - Drag & Drop Helpers

private enum DragPayload {
    case connection(UUID)
    case folder(UUID)

    init?(string: String) {
        let parts = string.split(separator: ":")
        guard parts.count == 2, let id = UUID(uuidString: String(parts[1])) else { return nil }
        switch parts[0] {
        case "connection": self = .connection(id)
        case "folder": self = .folder(id)
        default: return nil
        }
    }

    var stringValue: String {
        switch self {
        case .connection(let id): return "connection:\(id.uuidString)"
        case .folder(let id): return "folder:\(id.uuidString)"
        }
    }
}

private struct DropTarget: Equatable {
    let folderID: UUID?
    let kind: FolderKind
}

private struct DropInsertionRow: View {
    let isActive: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(isActive ? Color.accentColor.opacity(0.6) : Color.clear)
            .frame(height: isActive ? 6 : 2)
            .padding(.vertical, 4)
    }
}

private struct ConnectionsDropDelegate: DropDelegate {
    let targetFolderID: UUID?
    let targetKind: FolderKind
    @Binding var activeDropTarget: DropTarget?
    let onMoveConnection: (UUID, UUID?) -> Void
    let onMoveFolder: (UUID, UUID?) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.utf8PlainText])
    }

    func dropEntered(info: DropInfo) {
        activeDropTarget = DropTarget(folderID: targetFolderID, kind: targetKind)
    }

    func dropExited(info: DropInfo) {
        if activeDropTarget == DropTarget(folderID: targetFolderID, kind: targetKind) {
            activeDropTarget = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [UTType.utf8PlainText]).first else {
            activeDropTarget = nil
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
                return
            }

            switch payload {
            case .connection(let id):
                guard targetKind == .connections else { return }
                DispatchQueue.main.async {
                    onMoveConnection(id, targetFolderID)
                }
            case .folder(let id):
                DispatchQueue.main.async {
                    onMoveFolder(id, targetFolderID)
                }
            }
        }

        activeDropTarget = nil
        return true
    }
}

// MARK: - Connection Tree Views

private struct ConnectionSidebarItemView: View {
    let item: SidebarItem
    @Binding var selectedConnectionID: UUID?
    @Binding var expandedFolders: Set<UUID>
    @Binding var activeDropTarget: DropTarget?
    let onCreateConnection: (SavedFolder?) -> Void
    let onCreateFolder: (SavedFolder?) -> Void
    let onEditConnection: (SavedConnection) -> Void
    let onEditFolder: (SavedFolder) -> Void
    let onDelete: (DeletionTarget) -> Void
    let onConnect: (SavedConnection) -> Void
    let onSelectFolder: (SavedFolder) -> Void
    let onDuplicate: (SavedConnection) -> Void
    let onMoveConnection: (UUID, UUID?) -> Void
    let onMoveFolder: (UUID, UUID?) -> Void

    var body: some View {
        switch item {
        case .connection(let connection):
            ConnectionRowView(
                connection: connection,
                isSelected: selectedConnectionID == connection.id,
                onTap: {
                    selectedConnectionID = connection.id
                },
                onConnect: {
                    selectedConnectionID = connection.id
                    onConnect(connection)
                },
                onEdit: { onEditConnection(connection) },
                onDuplicate: { onDuplicate(connection) },
                onDelete: { onDelete(.connection(connection)) }
            )
            .onDrag {
                NSItemProvider(object: DragPayload.connection(connection.id).stringValue as NSString)
            }
        case .folder(let folder):
            ConnectionFolderRow(
                folder: folder,
                isExpanded: Binding(
                    get: { expandedFolders.contains(folder.id) },
                    set: { isExpanded in
                        if isExpanded {
                            expandedFolders.insert(folder.id)
                        } else {
                            expandedFolders.remove(folder.id)
                        }
                    }
                ),
                isHighlighted: activeDropTarget == DropTarget(folderID: folder.id, kind: .connections),
                onCreateConnection: { onCreateConnection(folder) },
                onCreateFolder: { onCreateFolder(folder) },
                onEdit: { onEditFolder(folder) },
                onDelete: { onDelete(.folder(folder)) },
                onSelect: { onSelectFolder(folder) }
            ) {
                ForEach(folder.children, id: \.id) { child in
                    ConnectionSidebarItemView(
                        item: child,
                        selectedConnectionID: $selectedConnectionID,
                        expandedFolders: $expandedFolders,
                        activeDropTarget: $activeDropTarget,
                        onCreateConnection: onCreateConnection,
                        onCreateFolder: onCreateFolder,
                        onEditConnection: onEditConnection,
                        onEditFolder: onEditFolder,
                    onDelete: onDelete,
                    onConnect: onConnect,
                    onSelectFolder: onSelectFolder,
                    onDuplicate: onDuplicate,
                    onMoveConnection: onMoveConnection,
                    onMoveFolder: onMoveFolder
                )
            }
            }
            .onDrag {
                NSItemProvider(object: DragPayload.folder(folder.id).stringValue as NSString)
            }
            .onDrop(
                of: [.utf8PlainText],
                delegate: ConnectionsDropDelegate(
                    targetFolderID: folder.id,
                    targetKind: .connections,
                    activeDropTarget: $activeDropTarget,
                    onMoveConnection: onMoveConnection,
                    onMoveFolder: onMoveFolder
                )
            )
        }
    }
}

private struct ConnectionFolderRow<Content: View>: View {
    let folder: SavedFolder
    @Binding var isExpanded: Bool
    let isHighlighted: Bool
    let onCreateConnection: () -> Void
    let onCreateFolder: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onSelect: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            content
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(folder.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(folder.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(folderSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .padding(.vertical, 4)
        .background(
            isHighlighted ? Color.accentColor.opacity(0.12) : Color.clear,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .contextMenu {
            Button("New Connection", systemImage: "externaldrive.badge.plus", action: onCreateConnection)
            Button("New Folder", systemImage: "folder.badge.plus", action: onCreateFolder)
            Divider()
            Button("Edit", systemImage: "square.and.pencil", action: onEdit)
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
        .simultaneousGesture(TapGesture().onEnded { onSelect() })
    }

    private var folderSubtitle: String {
        switch folder.credentialMode {
        case .none:
            return "No credentials"
        case .identity:
            if let identity = folder.identityID.flatMap({ id in appModel.identities.first(where: { $0.id == id }) }) {
                return "Uses identity \(identity.name)"
            }
            return "Identity unavailable"
        case .inherit:
            if let identity = appModel.folderIdentity(for: folder.id) {
                return "Inherits credentials (\(identity.name))"
            }
            return "Inherits credentials"
        }
    }

    @EnvironmentObject private var appModel: AppModel
}

private struct ConnectionRowView: View {
    let connection: SavedConnection
    let isSelected: Bool
    let onTap: () -> Void
    let onConnect: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(connection.color.opacity(0.16))
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(connection.color.opacity(0.4), lineWidth: 1)
                Image(connection.databaseType.iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
                    .foregroundStyle(connection.color)
            }
            .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(connection.connectionName.isEmpty ? "Untitled" : connection.connectionName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("\(connection.host):\(String(connection.port))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isHovering {
                HStack(spacing: 8) {
                    Button(action: onConnect) {
                        Image(systemName: "bolt.horizontal.circle")
                    }
                    .buttonStyle(.borderless)

                    Button(action: onEdit) {
                        Image(systemName: "square.and.pencil")
                    }
                    .buttonStyle(.borderless)

                    Button(action: onDuplicate) {
                        Image(systemName: "plus.square.on.square")
                    }
                    .buttonStyle(.borderless)

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(
            isSelected ? Color.accentColor.opacity(0.15) : Color.clear,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onTapGesture(count: 2, perform: onConnect)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
        .contextMenu {
            Button(action: onConnect) {
                Label("Connect", systemImage: "bolt.horizontal.circle")
            }
            Divider()
            Button(action: onEdit) {
                Label("Edit", systemImage: "square.and.pencil")
            }
            Button(action: onDuplicate) {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Identity Tree

private struct IdentityNode: Identifiable {
    enum Kind {
        case folder(SavedFolder)
        case identity(SavedIdentity)
    }

    var kind: Kind
    var children: [IdentityNode] = []

    var id: UUID {
        switch kind {
        case .folder(let folder): return folder.id
        case .identity(let identity): return identity.id
        }
    }
}

private struct IdentityNodeView: View {
    let node: IdentityNode
    @Binding var selectedIdentityID: UUID?
    @Binding var expandedFolders: Set<UUID>
    let onCreateIdentity: (SavedFolder?) -> Void
    let onCreateFolder: (SavedFolder?) -> Void
    let onEditIdentity: (SavedIdentity) -> Void
    let onEditFolder: (SavedFolder) -> Void
    let onDelete: (DeletionTarget) -> Void

    var body: some View {
        switch node.kind {
        case .folder(let folder):
            IdentityFolderRow(
                folder: folder,
                isExpanded: Binding(
                    get: { expandedFolders.contains(folder.id) },
                    set: { value in
                        if value {
                            expandedFolders.insert(folder.id)
                        } else {
                            expandedFolders.remove(folder.id)
                        }
                    }
                ),
                onCreateIdentity: { onCreateIdentity(folder) },
                onCreateFolder: { onCreateFolder(folder) },
                onEdit: { onEditFolder(folder) },
                onDelete: { onDelete(.folder(folder)) }
            ) {
                ForEach(node.children) { child in
                    IdentityNodeView(
                        node: child,
                        selectedIdentityID: $selectedIdentityID,
                        expandedFolders: $expandedFolders,
                        onCreateIdentity: onCreateIdentity,
                        onCreateFolder: onCreateFolder,
                        onEditIdentity: onEditIdentity,
                        onEditFolder: onEditFolder,
                        onDelete: onDelete
                    )
                }
            }
        case .identity(let identity):
            IdentityRowView(
                identity: identity,
                isSelected: selectedIdentityID == identity.id,
                onTap: { selectedIdentityID = identity.id },
                onEdit: { onEditIdentity(identity) },
                onDelete: { onDelete(.identity(identity)) }
            )
        }
    }
}

private struct IdentityFolderRow<Content: View>: View {
    let folder: SavedFolder
    @Binding var isExpanded: Bool
    let onCreateIdentity: () -> Void
    let onCreateFolder: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            content
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(folder.color)
                Text(folder.name)
                    .font(.subheadline)
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .background(
            Color.clear,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .contextMenu {
            Button("New Identity", systemImage: "person.badge.plus", action: onCreateIdentity)
            Button("New Folder", systemImage: "folder.badge.plus", action: onCreateFolder)
            Divider()
            Button("Edit", systemImage: "square.and.pencil", action: onEdit)
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }
}

private struct IdentityRowView: View {
    let identity: SavedIdentity
    let isSelected: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(identity.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(identity.username)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isHovering {
                HStack(spacing: 8) {
                    Button(action: onEdit) {
                        Image(systemName: "square.and.pencil")
                    }
                    .buttonStyle(.borderless)
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(
            isSelected ? Color.accentColor.opacity(0.15) : Color.clear,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit", systemImage: "square.and.pencil")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
