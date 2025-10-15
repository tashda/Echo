import SwiftUI
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

    @State private var searchText: String = ""
    @State private var expandedFolders: Set<UUID> = []
    @State private var folderEditorState: FolderEditorState?
    @State private var pendingDeletion: DeletionTarget?
    @State private var isAddMenuHovered = false

    private var currentProjectID: UUID? { appModel.selectedProject?.id }
    private var trimmedSearch: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isSearching: Bool { !trimmedSearch.isEmpty }

    private var rootConnections: [SavedConnection] { connections(in: nil) }
    private var connectionGroups: [ConnectionFolderGroup] { buildGroups(parentID: nil, depth: 0) }

    private var displayedRootConnections: [SavedConnection] { filterConnections(rootConnections) }
    private var displayedGroups: [ConnectionFolderGroup] { filterGroups(connectionGroups) }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    connectionsContent
                }
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
        }
        .background(Color.clear)
        .sheet(item: $folderEditorState) { state in
            FolderEditorSheet(state: state)
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
        .onAppear(perform: syncExpandedFoldersFromModel)
        .onChange(of: appModel.expandedConnectionFolderIDs) { newValue in
            if newValue != expandedFolders {
                expandedFolders = newValue
            }
        }
        .onChange(of: expandedFolders) { newValue in
            appModel.updateExpandedConnectionFolders(newValue)
        }
    }

    // MARK: - Search & Toolbar

    private var searchBar: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search connections", text: $searchText)
                    .textFieldStyle(.plain)

                if !trimmedSearch.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }

                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 1, height: 18)

                Menu {
                    Button("New Connection…", systemImage: "externaldrive.badge.plus") {
                        onCreateConnection(selectedConnectionFolder)
                        selectedIdentityID = nil
                    }
                    Button("New Connection Folder…", systemImage: "folder.badge.plus") {
                        openFolderCreator(parent: selectedConnectionFolder)
                        selectedIdentityID = nil
                    }
                    Divider()
                    Button("Manage Connections…", systemImage: "gearshape") {
                        openManageConnections()
                        selectedIdentityID = nil
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isAddMenuHovered ? Color.accentColor : Color.secondary.opacity(0.6))
                        .padding(2)
                }
                .menuStyle(.borderlessButton)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.12)) {
                        isAddMenuHovered = hovering
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )
        }
        .padding(12)
    }

    // MARK: - Content

    @ViewBuilder
    private var connectionsContent: some View {
        let roots = displayedRootConnections
        let groups = displayedGroups

        if roots.isEmpty && groups.isEmpty {
            ConnectionsEmptyState(query: trimmedSearch, isSearching: isSearching)
                .padding(.horizontal, 16)
                .padding(.top, 36)
        } else {
            ForEach(roots, id: \.id) { connection in
                ConnectionListRow(
                    connection: connection,
                    isSelected: selectedConnectionID == connection.id,
                    indent: 0,
                    onTap: { selectConnection(connection) },
                    onConnect: {
                        selectConnection(connection)
                        onConnect(connection)
                    },
                    onEdit: {
                        selectConnection(connection)
                        onEditConnection(connection)
                    },
                    onDuplicate: { onDuplicateConnection(connection) },
                    onDelete: { pendingDeletion = .connection(connection) }
                )
                .environmentObject(appModel)
            }

            ForEach(groups) { group in
                ConnectionFolderView(
                    group: group,
                    expandedFolders: $expandedFolders,
                    isSearching: isSearching,
                    selectedConnectionID: $selectedConnectionID,
                    onSelectFolder: { folder in appModel.selectedFolderID = folder.id },
                    onSelectConnection: { selectConnection($0) },
                    onConnect: onConnect,
                    onEditConnection: onEditConnection,
                    onDuplicate: onDuplicateConnection,
                    onDelete: { pendingDeletion = $0 },
                    onCreateConnection: { onCreateConnection($0) },
                    onCreateFolder: { openFolderCreator(parent: $0) },
                    onEditFolder: { openFolderEditor($0) },
                    onMoveConnection: onMoveConnection,
                    onMoveFolder: onMoveFolder
                )
                .environmentObject(appModel)
            }
        }
    }

    // MARK: - Helpers

    private var selectedConnectionFolder: SavedFolder? {
        guard let id = appModel.selectedFolderID else { return nil }
        return appModel.folders.first { $0.id == id && $0.kind == .connections }
    }

    private func selectConnection(_ connection: SavedConnection) {
        selectedIdentityID = nil
        selectedConnectionID = connection.id
    }

    private func openFolderCreator(parent: SavedFolder?) {
        folderEditorState = .create(kind: .connections, parent: parent, token: UUID())
    }

    private func openFolderEditor(_ folder: SavedFolder) {
        folderEditorState = .edit(folder: folder)
    }

    private func openManageConnections() {
#if os(macOS)
        ManageConnectionsWindowController.shared.present()
#else
        appModel.isManageConnectionsPresented = true
#endif
    }

    private func performDeletion(for target: DeletionTarget) {
        pendingDeletion = nil
        switch target {
        case .connection(let connection):
            Task { await appModel.deleteConnection(connection) }
        case .folder(let folder):
            Task { await appModel.deleteFolder(folder) }
        case .identity:
            break
        }
    }

    private func syncExpandedFoldersFromModel() {
        expandedFolders = appModel.expandedConnectionFolderIDs
    }

    private func connections(in folderID: UUID?) -> [SavedConnection] {
        guard let projectID = currentProjectID else { return [] }
        return appModel.connections
            .filter { $0.folderID == folderID && $0.projectID == projectID }
            .sorted { $0.connectionName.localizedCaseInsensitiveCompare($1.connectionName) == .orderedAscending }
    }

    private func buildGroups(parentID: UUID?, depth: Int) -> [ConnectionFolderGroup] {
        guard let projectID = currentProjectID else { return [] }
        let folders = appModel.folders
            .filter { $0.kind == .connections && $0.parentFolderID == parentID && $0.projectID == projectID }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        return folders.map { folder in
            ConnectionFolderGroup(
                folder: folder,
                depth: depth,
                connections: connections(in: folder.id),
                children: buildGroups(parentID: folder.id, depth: depth + 1)
            )
        }
    }

    private func filterGroups(_ groups: [ConnectionFolderGroup]) -> [ConnectionFolderGroup] {
        guard isSearching else { return groups }
        return groups.compactMap { filterGroup($0) }
    }

    private func filterGroup(_ group: ConnectionFolderGroup) -> ConnectionFolderGroup? {
        let folderMatches = matchesSearch(in: group.folder.name)
        let filteredConnections = folderMatches ? group.connections : filterConnections(group.connections)
        let filteredChildren = folderMatches ? group.children : filterGroups(group.children)

        if folderMatches || !filteredConnections.isEmpty || !filteredChildren.isEmpty {
            return ConnectionFolderGroup(
                folder: group.folder,
                depth: group.depth,
                connections: filteredConnections,
                children: filteredChildren
            )
        }
        return nil
    }

    private func filterConnections(_ connections: [SavedConnection]) -> [SavedConnection] {
        guard isSearching else { return connections }
        return connections.filter { matchesSearch(for: $0) }
    }

    private func matchesSearch(for connection: SavedConnection) -> Bool {
        guard !trimmedSearch.isEmpty else { return true }
        return connection.connectionName.localizedCaseInsensitiveContains(trimmedSearch) ||
            connection.host.localizedCaseInsensitiveContains(trimmedSearch)
    }

    private func matchesSearch(in text: String) -> Bool {
        guard !trimmedSearch.isEmpty else { return true }
        return text.localizedCaseInsensitiveContains(trimmedSearch)
    }
}

// MARK: - Connection Folder Group

private struct ConnectionFolderGroup: Identifiable {
    let folder: SavedFolder
    let depth: Int
    var connections: [SavedConnection]
    var children: [ConnectionFolderGroup]

    var id: UUID { folder.id }
    var totalConnectionCount: Int {
        connections.count + children.reduce(0) { $0 + $1.totalConnectionCount }
    }
}

private struct ConnectionFolderView: View {
    let group: ConnectionFolderGroup
    @Binding var expandedFolders: Set<UUID>
    let isSearching: Bool
    @Binding var selectedConnectionID: UUID?
    let onSelectFolder: (SavedFolder) -> Void
    let onSelectConnection: (SavedConnection) -> Void
    let onConnect: (SavedConnection) -> Void
    let onEditConnection: (SavedConnection) -> Void
    let onDuplicate: (SavedConnection) -> Void
    let onDelete: (DeletionTarget) -> Void
    let onCreateConnection: (SavedFolder?) -> Void
    let onCreateFolder: (SavedFolder?) -> Void
    let onEditFolder: (SavedFolder) -> Void
    let onMoveConnection: (UUID, UUID?) -> Void
    let onMoveFolder: (UUID, UUID?) -> Void

    @State private var isHovering = false
    @EnvironmentObject private var appModel: AppModel

    private var isExpanded: Bool {
        isSearching || expandedFolders.contains(group.folder.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            folderRow

            if isExpanded {
                ForEach(group.connections, id: \.id) { connection in
                    ConnectionListRow(
                        connection: connection,
                        isSelected: selectedConnectionID == connection.id,
                        indent: CGFloat(group.depth + 1) * 16,
                        onTap: {
                            onSelectConnection(connection)
                        },
                        onConnect: {
                            onSelectConnection(connection)
                            onConnect(connection)
                        },
                        onEdit: {
                            onSelectConnection(connection)
                            onEditConnection(connection)
                        },
                        onDuplicate: { onDuplicate(connection) },
                        onDelete: { onDelete(.connection(connection)) }
                    )
                    .environmentObject(appModel)
                }

                ForEach(group.children) { child in
                    ConnectionFolderView(
                        group: child,
                        expandedFolders: $expandedFolders,
                        isSearching: isSearching,
                        selectedConnectionID: $selectedConnectionID,
                        onSelectFolder: onSelectFolder,
                        onSelectConnection: onSelectConnection,
                        onConnect: onConnect,
                        onEditConnection: onEditConnection,
                        onDuplicate: onDuplicate,
                        onDelete: onDelete,
                        onCreateConnection: onCreateConnection,
                        onCreateFolder: onCreateFolder,
                        onEditFolder: onEditFolder,
                        onMoveConnection: onMoveConnection,
                        onMoveFolder: onMoveFolder
                    )
                    .environmentObject(appModel)
                }

                if group.connections.isEmpty && group.children.isEmpty {
                    EmptyFolderPlaceholder(indent: CGFloat(group.depth + 1) * 16)
                }
            }
        }
    }

    private var folderRow: some View {
        let indent = CGFloat(group.depth) * 16
        return HStack(spacing: 6) {
            Spacer().frame(width: indent)

            HStack(spacing: 8) {
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)

                Image(systemName: "folder.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(group.folder.color)

                Text(group.folder.name)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text("\(group.totalConnectionCount)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary.opacity(0.8))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(folderHighlight)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onTapGesture { toggleExpansion() }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.12)) {
                    isHovering = hovering
                }
            }
            .contextMenu {
                Button("New Connection", systemImage: "externaldrive.badge.plus") {
                    onCreateConnection(group.folder)
                }
                Button("New Folder", systemImage: "folder.badge.plus") {
                    onCreateFolder(group.folder)
                }
                Divider()
                Button("Rename Folder", systemImage: "square.and.pencil") {
                    onEditFolder(group.folder)
                }
                Button("Delete Folder", systemImage: "trash", role: .destructive) {
                    onDelete(.folder(group.folder))
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private var folderHighlight: some View {
        let base = RoundedRectangle(cornerRadius: 8, style: .continuous)
        if expandedFolders.contains(group.folder.id) {
            return AnyView(
                base
                    .fill(Color.accentColor.opacity(0.2))
                    .overlay(base.stroke(Color.accentColor.opacity(0.4), lineWidth: 0.9))
            )
        }
        if isHovering {
            return AnyView(
                base
                    .fill(Color.accentColor.opacity(0.12))
                    .overlay(base.stroke(Color.accentColor.opacity(0.35), lineWidth: 0.8))
            )
        }
        return AnyView(Color.clear)
    }

    private func toggleExpansion() {
        onSelectFolder(group.folder)
        guard !isSearching else { return }
        if expandedFolders.contains(group.folder.id) {
            expandedFolders.remove(group.folder.id)
        } else {
            expandedFolders.insert(group.folder.id)
        }
    }
}

// MARK: - Rows / Empty State

private struct ConnectionListRow: View {
    let connection: SavedConnection
    let isSelected: Bool
    let indent: CGFloat
    let onTap: () -> Void
    let onConnect: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    @EnvironmentObject private var appModel: AppModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    private var accentColor: Color {
        appModel.useServerColorAsAccent ? connection.color : Color.accentColor
    }

    private var displayName: String {
        let trimmed = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? connection.host : trimmed
    }

    var body: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: indent + 12)

            HStack(spacing: 8) {
                connectionIcon
                    .frame(width: 14, height: 14)

                Text(displayName)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if isHovering {
                    Button(action: onConnect) {
                        connectIcon
                            .frame(width: 12, height: 12)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(connectGlyphColor)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(highlightBackground)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onTapGesture(perform: onTap)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.12)) {
                    isHovering = hovering
                }
            }
            .contextMenu {
                Button(action: onConnect) {
                    Label {
                        Text("Connect")
                    } icon: {
                        connectIcon
                            .frame(width: 12, height: 12)
                            .foregroundStyle(connectGlyphColor)
                    }
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
            .highPriorityGesture(
                TapGesture(count: 2).onEnded {
                    onTap()
                    onConnect()
                }
            )
        }
    }

    @ViewBuilder
    private var connectionIcon: some View {
#if os(macOS)
        if let logoData = connection.logo,
           let nsImage = NSImage(data: logoData) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        } else {
            Image(connection.databaseType.iconName)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(accentColor)
        }
#else
        Image(connection.databaseType.iconName)
            .resizable()
            .renderingMode(.template)
            .aspectRatio(contentMode: .fit)
            .foregroundStyle(accentColor)
#endif
    }

    @ViewBuilder
    private var highlightBackground: some View {
        let base = RoundedRectangle(cornerRadius: 8, style: .continuous)

        if isSelected {
            base
                .fill(accentColor.opacity(0.2))
                .overlay(base.stroke(accentColor.opacity(0.4), lineWidth: 1))
        } else if isHovering {
            base
                .fill(accentColor.opacity(0.12))
                .overlay(base.stroke(accentColor.opacity(0.35), lineWidth: 0.8))
        } else {
            Color.clear
        }
    }

    private var connectIcon: some View {
        Image("connect.cables")
            .resizable()
            .renderingMode(.template)
            .aspectRatio(contentMode: .fit)
    }

    private var connectGlyphColor: Color {
        colorScheme == .dark ? .white : .black
    }
}

private struct EmptyFolderPlaceholder: View {
    let indent: CGFloat

    var body: some View {
        Text("No connections in this folder")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .padding(.leading, indent)
    }
}

private struct ConnectionsEmptyState: View {
    let query: String
    let isSearching: Bool

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: isSearching ? "magnifyingglass" : "externaldrive")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)

            if isSearching {
                Text("No matches for \(query.isEmpty ? "your search" : "\"\(query)\"")")
                    .font(.headline)
            } else {
                Text("No Connections")
                    .font(.headline)
            }

            Text(isSearching ? "Try adjusting your search." : "Use the plus button to add your first connection or organize folders.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
