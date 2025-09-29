import SwiftUI
import UniformTypeIdentifiers

struct ConnectionsSidebarView: View {
    @EnvironmentObject private var appModel: AppModel

    @Binding var selectedConnectionID: UUID?
    @Binding var selectedIdentityID: UUID?

    let onCreateConnection: (SavedFolder?) -> Void
    let onEditConnection: (SavedConnection) -> Void
    let onConnect: (SavedConnection) -> Void
    let onMoveConnection: (UUID, UUID?) -> Void
    let onMoveFolder: (UUID, UUID?) -> Void

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
            header
            Divider()
            List {
                Section(header: Text("Connections")) {
                    connectionsSection
                }

                Section(header: Text("Identities")) {
                    identitiesSection
                }

                authenticationSection
            }
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

    private var header: some View {
        HStack(spacing: 8) {
            Text("Connections")
                .font(.headline)
            Spacer()
            Menu {
                menuContent()
            } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: 14, weight: .medium))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(headerHighlight)
        .onDrop(of: [.utf8PlainText], delegate: ConnectionsDropDelegate(
            targetFolderID: nil,
            targetKind: .connections,
            activeDropTarget: $activeDropTarget,
            onMoveConnection: onMoveConnection,
            onMoveFolder: onMoveFolder
        ))
    }

    private var headerHighlight: Color {
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
                    onMoveConnection: onMoveConnection,
                    onMoveFolder: onMoveFolder
                )
            }
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
        }
    }

    private var authenticationSection: some View {
        Section("Authentication Methods") {
            ForEach(AuthenticationMethod.allCases, id: \.self) { method in
                HStack {
                    Text(method.displayName)
                    Spacer()
                    Text("Coming")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private func menuContent() -> some View {
        Section("Connections") {
            Button("New Connection", systemImage: "externaldrive.badge.plus") {
                onCreateConnection(nil)
            }
            Button("New Connection Folder", systemImage: "folder.badge.plus") {
                openFolderCreator(kind: .connections, parent: nil)
            }
        }

        Section("Identities") {
            Button("New Identity", systemImage: "person.badge.plus") {
                openIdentityCreator(parent: nil)
            }
            Button("New Identity Folder", systemImage: "folder.badge.plus") {
                openFolderCreator(kind: .identities, parent: nil)
            }
        }
    }

    @ViewBuilder
    private func contextMenuContent() -> some View {
        Button("New Connection") { onCreateConnection(nil) }
        Button("New Connection Folder") { openFolderCreator(kind: .connections, parent: nil) }
        Divider()
        Button("New Identity") { openIdentityCreator(parent: nil) }
        Button("New Identity Folder") { openFolderCreator(kind: .identities, parent: nil) }
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
        let folders = appModel.folders
            .filter { $0.kind == .connections && $0.parentFolderID == parentID }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let connections = appModel.connections
            .filter { $0.folderID == parentID }
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
        let folders = appModel.folders
            .filter { $0.kind == .identities && $0.parentFolderID == parentID }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let identities = appModel.identities
            .filter { $0.folderID == parentID }
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

        var result = false
        let semaphore = DispatchSemaphore(value: 0)
        provider.loadItem(forTypeIdentifier: UTType.utf8PlainText.identifier, options: nil) { item, _ in
            defer { semaphore.signal() }

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
                if targetKind == .connections {
                    onMoveConnection(id, targetFolderID)
                    result = true
                }
            case .folder(let id):
                onMoveFolder(id, targetFolderID)
                result = true
            }
        }
        semaphore.wait()
        activeDropTarget = nil
        return result
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
                onDelete: { onDelete(.folder(folder)) }
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
    @ViewBuilder var content: Content

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            content
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(folder.color)
                    .frame(width: 24, height: 24)
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
        .background(isHighlighted ? Color.accentColor.opacity(0.12) : Color.clear)
        .contextMenu {
            Button("New Connection", systemImage: "externaldrive.badge.plus", action: onCreateConnection)
            Button("New Folder", systemImage: "folder.badge.plus", action: onCreateFolder)
            Divider()
            Button("Edit", systemImage: "square.and.pencil", action: onEdit)
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }

    private var folderSubtitle: String {
        switch folder.credentialMode {
        case .none:
            return "No credentials"
        case .identity:
            if let identity = folder.identityID.flatMap({ id in appModel?.identities.first(where: { $0.id == id }) }) {
                return "Uses identity \(identity.name)"
            }
            return "Identity unavailable"
        case .inherit:
            if let identity = appModel?.folderIdentity(for: folder.id) {
                return "Inherits credentials (\(identity.name))"
            }
            return "Inherits credentials"
        }
    }

    @EnvironmentObject private var appModel: AppModel?
}

private struct ConnectionRowView: View {
    let connection: SavedConnection
    let isSelected: Bool
    let onTap: () -> Void
    let onConnect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(connection.color.opacity(0.2))
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: connection.databaseType.iconName)
                        .foregroundStyle(connection.color)
                )
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
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onTapGesture(count: 2, perform: onConnect)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
        .contextMenu {
            Button("Connect", action: onConnect)
            Divider()
            Button("Edit", action: onEdit)
            Button("Delete", role: .destructive, action: onDelete)
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
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(folder.color)
                    .frame(width: 20, height: 20)
                Text(folder.name)
                    .font(.subheadline)
                Spacer()
            }
            .padding(.vertical, 4)
        }
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
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
        .contextMenu {
            Button("Edit", action: onEdit)
            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}

// MARK: - Authentication Methods

private enum AuthenticationMethod: String, CaseIterable {
    case trust, reject, md5, password, gss, sspi, krb5, ident, pam, ldap, cert

    var displayName: String { rawValue.uppercased() }
}

// MARK: - Folder & Identity Sheet State

private enum DeletionTarget: Identifiable {
    case connection(SavedConnection)
    case folder(SavedFolder)
    case identity(SavedIdentity)

    var id: UUID {
        switch self {
        case .connection(let connection): return connection.id
        case .folder(let folder): return folder.id
        case .identity(let identity): return identity.id
        }
    }

    var displayName: String {
        switch self {
        case .connection(let connection): return connection.connectionName
        case .folder(let folder): return folder.name
        case .identity(let identity): return identity.name
        }
    }
}

private enum FolderEditorState: Identifiable {
    case create(kind: FolderKind, parent: SavedFolder?, token: UUID)
    case edit(folder: SavedFolder)

    var id: UUID {
        switch self {
        case .create(_, _, let token): return token
        case .edit(let folder): return folder.id
        }
    }
}

private enum IdentityEditorState: Identifiable {
    case create(parent: SavedFolder?, token: UUID)
    case edit(identity: SavedIdentity)

    var id: UUID {
        switch self {
        case .create(_, let token): return token
        case .edit(let identity): return identity.id
        }
    }
}

private struct FolderEditorSheet: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    let state: FolderEditorState

    @State private var name: String = ""
    @State private var selectedColorHex: String = Palette.defaults.first ?? "BAF2BB"
    @State private var credentialMode: FolderCredentialMode = .none
    @State private var selectedIdentityID: UUID?

    private var isIdentityFolder: Bool {
        switch state {
        case .create(let kind, _, _): return kind == .identities
        case .edit(let folder): return folder.kind == .identities
        }
    }

    private var parentFolder: SavedFolder? {
        switch state {
        case .create(_, let parent, _): return parent
        case .edit(let folder):
            guard let parentID = folder.parentFolderID else { return nil }
            return appModel.folders.first(where: { $0.id == parentID })
        }
    }

    private var editingFolder: SavedFolder? {
        if case .edit(let folder) = state { return folder }
        return nil
    }

    private var availableIdentities: [SavedIdentity] {
        appModel.identities.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(editingFolder == nil ? "New Folder" : "Edit Folder")
                .font(.title3)
                .fontWeight(.semibold)

            TextField("Folder Name", text: $name)
                .textFieldStyle(.roundedBorder)

            colorPalette

            if !isIdentityFolder {
                credentialPicker
            }

            if credentialMode == .identity && !availableIdentities.isEmpty {
                Picker("Identity", selection: Binding<UUID?>(
                    get: { selectedIdentityID },
                    set: { selectedIdentityID = $0 }
                )) {
                    ForEach(availableIdentities, id: \.id) { identity in
                        Text(identity.name).tag(UUID?.some(identity.id))
                    }
                }
                .pickerStyle(.menu)
            }

            Spacer()

            HStack {
                if editingFolder != nil {
                    Button("Delete", role: .destructive) {
                        guard let folder = editingFolder else { return }
                        Task {
                            await appModel.deleteFolder(folder)
                            dismiss()
                        }
                    }
                    Spacer()
                }

                Button("Cancel", role: .cancel) { dismiss() }
                Button("Save") { saveFolder() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .frame(minWidth: 320, minHeight: 300)
        .padding()
        .onAppear(perform: configureInitialState)
    }

    private var colorPalette: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                ForEach(Palette.defaults, id: \.self) { hex in
                    Circle()
                        .fill(Color(hex: hex) ?? .accentColor)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .strokeBorder(hex == selectedColorHex ? Color.primary : Color.clear, lineWidth: 2)
                        )
                        .onTapGesture { selectedColorHex = hex }
                }
            }
        }
    }

    private var credentialPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Credentials")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Picker("Credentials", selection: $credentialMode) {
                ForEach(FolderCredentialMode.allCases, id: \.self) { mode in
                    if mode == .inherit, parentFolder == nil {
                        EmptyView()
                    } else {
                        Text(mode.displayName).tag(mode)
                    }
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private func configureInitialState() {
        if let folder = editingFolder {
            name = folder.name
            selectedColorHex = folder.color.toHex() ?? selectedColorHex
            credentialMode = folder.credentialMode
            selectedIdentityID = folder.identityID
        } else if let parent = parentFolder {
            selectedColorHex = parent.color.toHex() ?? selectedColorHex
            if parent.kind == .connections {
                credentialMode = .inherit
            }
        }

        if isIdentityFolder {
            credentialMode = .none
        }
    }

    private func saveFolder() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let color = Color(hex: selectedColorHex) ?? .accentColor

        var folder = editingFolder ?? SavedFolder(name: trimmedName, parentFolderID: nil, color: color)
        folder.name = trimmedName
        folder.color = color
        folder.kind = editingFolder?.kind ?? {
            if case .create(let kind, _, _) = state { return kind }
            if case .edit(let existing) = state { return existing.kind }
            return .connections
        }()
        folder.parentFolderID = parentFolder?.id

        if folder.kind == .connections {
            folder.credentialMode = credentialMode
            folder.identityID = credentialMode == .identity ? selectedIdentityID : nil
        } else {
            folder.credentialMode = .none
            folder.identityID = nil
        }

        Task {
            await appModel.upsertFolder(folder)
            if folder.kind == .connections {
                appModel.selectedFolderID = folder.id
            }
            dismiss()
        }
    }

    private enum Palette {
        static let defaults: [String] = [
            "BAF2BB",
            "BAF2D8",
            "BAD7F2",
            "F2BAC9",
            "F2E2BA"
        ]
    }
}

private struct IdentityEditorSheet: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    let state: IdentityEditorState

    @State private var name: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var selectedFolderID: UUID?

    private var editingIdentity: SavedIdentity? {
        if case .edit(let identity) = state { return identity }
        return nil
    }

    private var availableFolders: [SavedFolder] {
        appModel.folders
            .filter { $0.kind == .identities }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(editingIdentity == nil ? "New Identity" : "Edit Identity")
                .font(.title3)
                .fontWeight(.semibold)

            TextField("Display Name", text: $name)
                .textFieldStyle(.roundedBorder)

            TextField("Username", text: $username)
                .textFieldStyle(.roundedBorder)

            SecureField(editingIdentity == nil ? "Password" : "New Password (optional)", text: $password)
                .textFieldStyle(.roundedBorder)

            if !availableFolders.isEmpty {
                Picker("Folder", selection: Binding<UUID?>(
                    get: { selectedFolderID },
                    set: { selectedFolderID = $0 }
                )) {
                    Text("No Folder").tag(UUID?.none)
                    ForEach(availableFolders, id: \.id) { folder in
                        Text(folder.name).tag(UUID?.some(folder.id))
                    }
                }
                .pickerStyle(.menu)
            }

            Spacer()

            HStack {
                if editingIdentity != nil {
                    Button("Delete", role: .destructive) {
                        guard let identity = editingIdentity else { return }
                        Task {
                            await appModel.deleteIdentity(identity)
                            dismiss()
                        }
                    }
                    Spacer()
                }

                Button("Cancel", role: .cancel) { dismiss() }
                Button("Save") { saveIdentity() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .frame(minWidth: 320, minHeight: 280)
        .padding()
        .onAppear(perform: configureInitialState)
    }

    private func configureInitialState() {
        if let identity = editingIdentity {
            name = identity.name
            username = identity.username
            selectedFolderID = identity.folderID
        } else if case .create(let parent, _) = state {
            selectedFolderID = parent?.id
        }
    }

    private func saveIdentity() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedUsername.isEmpty else { return }

        var identity = editingIdentity ?? SavedIdentity(name: trimmedName, username: trimmedUsername)
        identity.name = trimmedName
        identity.username = trimmedUsername
        identity.folderID = selectedFolderID

        let passwordValue = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let passwordToStore = passwordValue.isEmpty ? nil : passwordValue

        Task {
            await appModel.upsertIdentity(identity, password: passwordToStore)
            appModel.selectedIdentityID = identity.id
            dismiss()
        }
    }
}
