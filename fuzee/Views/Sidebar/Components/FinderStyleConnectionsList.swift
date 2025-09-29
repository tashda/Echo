import SwiftUI

// MARK: - Reusable Finder-Style Connections List

struct FinderStyleConnectionsList: View {
    let items: [SidebarItem]
    @Binding var selectedConnectionID: UUID?
    @Binding var selectedFolderID: UUID?

    // Configuration options
    let showHeader: Bool
    let isCompactMode: Bool
    let maxHeight: CGFloat?

    // Callbacks - all optional for popup use
    let onAddConnection: ((SavedFolder?) -> Void)?
    let onAddFolder: ((SavedFolder?) -> Void)?
    let onEditItem: ((SidebarItem) -> Void)?
    let onDeleteItem: ((SidebarItem) -> Void)?
    let onDuplicateItem: ((SidebarItem) -> Void)?
    let onConnectToConnection: ((SavedConnection) -> Void)?
    let onMoveConnection: ((UUID, SavedFolder?) -> Void)?

    @ObservedObject private var dragManager = DragDropManager.shared
    @EnvironmentObject var appModel: AppModel

    private var expandedFoldersBinding: Binding<Set<UUID>> {
        Binding(
            get: { appModel.expandedFolders },
            set: { appModel.expandedFolders = $0 }
        )
    }

    init(
        items: [SidebarItem],
        selectedConnectionID: Binding<UUID?>,
        selectedFolderID: Binding<UUID?> = .constant(nil),
        showHeader: Bool = false,
        isCompactMode: Bool = false,
        maxHeight: CGFloat? = nil,
        onAddConnection: ((SavedFolder?) -> Void)? = nil,
        onAddFolder: ((SavedFolder?) -> Void)? = nil,
        onEditItem: ((SidebarItem) -> Void)? = nil,
        onDeleteItem: ((SidebarItem) -> Void)? = nil,
        onDuplicateItem: ((SidebarItem) -> Void)? = nil,
        onConnectToConnection: ((SavedConnection) -> Void)? = nil,
        onMoveConnection: ((UUID, SavedFolder?) -> Void)? = nil
    ) {
        self.items = items
        self._selectedConnectionID = selectedConnectionID
        self._selectedFolderID = selectedFolderID
        self.showHeader = showHeader
        self.isCompactMode = isCompactMode
        self.maxHeight = maxHeight
        self.onAddConnection = onAddConnection
        self.onAddFolder = onAddFolder
        self.onEditItem = onEditItem
        self.onDeleteItem = onDeleteItem
        self.onDuplicateItem = onDuplicateItem
        self.onConnectToConnection = onConnectToConnection
        self.onMoveConnection = onMoveConnection
    }

    var body: some View {
        VStack(spacing: 0) {
            // Optional header
            if showHeader {
                HStack {
                    Text("Connections")
                        .font(isCompactMode ? .subheadline : .headline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Spacer()
                    if let onAddConnection = onAddConnection, let onAddFolder = onAddFolder {
                        Menu {
                            Button {
                                onAddConnection(nil)
                            } label: {
                                Label("New Connection", systemImage: "externaldrive.badge.plus")
                            }
                            Button {
                                onAddFolder(nil)
                            } label: {
                                Label("New Folder", systemImage: "folder.badge.plus")
                            }
                        } label: {
                            Image(systemName: "plus.circle")
                                .font(.system(size: isCompactMode ? 12 : 14, weight: .medium))
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .frame(width: isCompactMode ? 20 : 24, height: isCompactMode ? 20 : 24)
                        .help("Add Connection or Folder")
                    }
                }
                .padding(.horizontal, isCompactMode ? 8 : 12)
                .padding(.vertical, isCompactMode ? 4 : 8)
            }

            // Connections list
            ScrollView {
                LazyVStack(spacing: isCompactMode ? 0 : 1) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        VStack(spacing: 0) {
                            // Drop zone before item (only if drag/drop is enabled)
                            if index == 0 && onMoveConnection != nil {
                                DropZoneView(position: .beforeItem(item.id)) { draggedId in
                                    handleDrop(draggedId, position: .beforeItem(item.id))
                                }
                            }

                            // The actual item
                            FinderStyleListItemView(
                                item: item,
                                level: 0,
                                selectedConnectionID: $selectedConnectionID,
                                selectedFolderID: $selectedFolderID,
                                expandedFolders: expandedFoldersBinding,
                                isCompactMode: isCompactMode,
                                onAddConnection: onAddConnection,
                                onAddFolder: onAddFolder,
                                onEditItem: onEditItem,
                                onDeleteItem: onDeleteItem,
                                onDuplicateItem: onDuplicateItem,
                                onConnectToConnection: onConnectToConnection,
                                onMoveConnection: onMoveConnection
                            )

                            // Drop zone after item (only if drag/drop is enabled)
                            if onMoveConnection != nil {
                                DropZoneView(position: .afterItem(item.id)) { draggedId in
                                    handleDrop(draggedId, position: .afterItem(item.id))
                                }
                            }
                        }
                    }

                    // Final drop zone at the end (only if drag/drop is enabled)
                    if onMoveConnection != nil {
                        DropZoneView(position: .atRootEnd) { draggedId in
                            handleDrop(draggedId, position: .atRootEnd)
                        }
                        .frame(minHeight: isCompactMode ? 30 : 40)
                    }
                }
            }
            .frame(maxHeight: maxHeight)
        }
        .onReceive(dragManager.$expandedFoldersOnDrag) { expandedOnDrag in
            // Merge drag-expanded folders with manually expanded ones
            for folderId in expandedOnDrag {
                if !appModel.expandedFolders.contains(folderId) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        appModel.expandedFolders.insert(folderId)
                    }
                }
            }
        }
    }

    private func handleDrop(_ draggedIdString: String, position: DropPosition) -> Bool {
        guard let connectionId = UUID(uuidString: draggedIdString),
              let onMoveConnection = onMoveConnection else { return false }

        switch position {
        case .beforeItem(let itemId), .afterItem(let itemId):
            // For now, just move to root - could implement precise positioning later
            onMoveConnection(connectionId, nil)
        case .intoFolder(let folderId):
            let folder = extractFolders(from: items).first { $0.id == folderId }
            onMoveConnection(connectionId, folder)
        case .atRootEnd:
            onMoveConnection(connectionId, nil)
        }

        return true
    }

    private func extractFolders(from items: [SidebarItem]) -> [SavedFolder] {
        return items.compactMap { item in
            if case .folder(let folder) = item {
                return folder
            }
            return nil
        }
    }
}

// MARK: - Finder-Style List Item View

struct FinderStyleListItemView: View {
    let item: SidebarItem
    let level: Int
    @Binding var selectedConnectionID: UUID?
    @Binding var selectedFolderID: UUID?
    @Binding var expandedFolders: Set<UUID>
    let isCompactMode: Bool

    // Callbacks (all optional)
    let onAddConnection: ((SavedFolder?) -> Void)?
    let onAddFolder: ((SavedFolder?) -> Void)?
    let onEditItem: ((SidebarItem) -> Void)?
    let onDeleteItem: ((SidebarItem) -> Void)?
    let onDuplicateItem: ((SidebarItem) -> Void)?
    let onConnectToConnection: ((SavedConnection) -> Void)?
    let onMoveConnection: ((UUID, SavedFolder?) -> Void)?

    private var indentPerLevel: CGFloat { isCompactMode ? 16 : 20 }
    private var iconSize: CGFloat { isCompactMode ? 12 : 14 }

    var body: some View {
        switch item {
        case .connection(let connection):
            FinderStyleCompactConnectionView(
                connection: connection,
                level: level,
                isSelected: selectedConnectionID == connection.id,
                isCompactMode: isCompactMode,
                onTap: {
                    selectedConnectionID = connection.id
                    selectedFolderID = nil
                },
                onConnect: {
                    onConnectToConnection?(connection)
                },
                onEdit: {
                    onEditItem?(.connection(connection))
                },
                onDuplicate: {
                    onDuplicateItem?(.connection(connection))
                },
                onDelete: {
                    onDeleteItem?(.connection(connection))
                },
                enableDragDrop: onMoveConnection != nil
            )

        case .folder(let folder):
            FinderStyleCompactFolderView(
                folder: folder,
                level: level,
                isSelected: selectedFolderID == folder.id,
                isExpanded: expandedFolders.contains(folder.id),
                isCompactMode: isCompactMode,
                selectedConnectionID: $selectedConnectionID,
                selectedFolderID: $selectedFolderID,
                expandedFolders: $expandedFolders,
                onFolderTap: {
                    selectedFolderID = folder.id
                    selectedConnectionID = nil
                },
                onToggleExpansion: {
                    withAnimation(.easeInOut(duration: 0.08)) {
                        if expandedFolders.contains(folder.id) {
                            expandedFolders.remove(folder.id)
                        } else {
                            expandedFolders.insert(folder.id)
                        }
                    }
                },
                onAddConnection: onAddConnection,
                onAddFolder: onAddFolder,
                onEditItem: onEditItem,
                onDeleteItem: onDeleteItem,
                onDuplicateItem: onDuplicateItem,
                onConnectToConnection: onConnectToConnection,
                onMoveConnection: onMoveConnection
            )
        }
    }
}

// MARK: - Compact Connection View

struct FinderStyleCompactConnectionView: View {
    let connection: SavedConnection
    let level: Int
    let isSelected: Bool
    let isCompactMode: Bool
    let onTap: () -> Void
    let onConnect: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    let enableDragDrop: Bool

    @State private var isHovering = false
    @EnvironmentObject var appModel: AppModel

    private var isConnected: Bool {
        appModel.connectionStates[connection.id]?.isConnected == true
    }

    private var indentPerLevel: CGFloat { isCompactMode ? 16 : 20 }
    private var iconSize: CGFloat { isCompactMode ? 12 : 14 }

    var body: some View {
        HStack(spacing: 0) {
            // Indentation
            if level > 0 {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: CGFloat(level) * indentPerLevel, height: 1)
            }

            HStack(spacing: isCompactMode ? 6 : 8) {
                Image(systemName: connection.databaseType.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconSize + 2, height: iconSize + 2)
                    .foregroundStyle(connection.color)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 4) {
                        Text(connection.connectionName)
                            .font(.system(size: isCompactMode ? 12 : 13, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if isConnected {
                            Circle()
                                .fill(Color.green)
                                .frame(width: isCompactMode ? 4 : 5, height: isCompactMode ? 4 : 5)
                                .shadow(color: .green.opacity(0.6), radius: 2)
                        }
                    }

                    if !isCompactMode {
                        Text("\(connection.username)@\(connection.host)")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                #if os(macOS)
                if isHovering || isSelected {
                    HStack(spacing: 4) {
                        Button(action: {
                            if isConnected {
                                Task { await appModel.disconnect(from: connection) }
                            } else {
                                onConnect()
                            }
                        }) {
                            Image(systemName: isConnected ? "stop.fill" : "play.fill")
                                .font(.system(size: isCompactMode ? 11 : 12))
                        }
                        .buttonStyle(.plain)
                        .help(isConnected ? "Disconnect" : "Connect")

                        Button(action: onEdit) {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: isCompactMode ? 11 : 12))
                        }
                        .buttonStyle(.plain)
                        .help("Edit Connection")

                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: isCompactMode ? 11 : 12))
                        }
                        .buttonStyle(.plain)
                        .help("Delete Connection")
                    }
                    .foregroundStyle(.secondary)
                    .transition(.opacity.animation(.easeInOut(duration: 0.08)))
                }
                #endif
            }
            .padding(.vertical, isCompactMode ? 2 : 3)
            .padding(.horizontal, isCompactMode ? 4 : 6)
            .padding(.leading, level == 0 ? 4 : 0)
            .sidebarSelectionStyle(isSelected: isSelected)
        }
        #if os(macOS)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.08)) {
                isHovering = hovering
            }
        }
        #endif
        .if(enableDragDrop) { view in
            view.draggable(connection.id.uuidString) {
                HStack(spacing: 4) {
                    Image(connection.databaseType.imageName)
                        .frame(width: 10, height: 10)
                    Text(connection.connectionName)
                        .font(.system(size: 10))
                }
                .padding(2)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 2))
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture()
                .onEnded { _ in onTap() }
        )
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded { _ in
                    onTap()
                    onConnect()
                }
        )
        .contextMenu {
            Button(isConnected ? "Disconnect" : "Connect") {
                if isConnected {
                    Task { await appModel.disconnect(from: connection) }
                } else {
                    onConnect()
                }
            }
            Divider()
            Button("Edit...", action: onEdit)
            Button("Duplicate", action: onDuplicate)
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        } preview: {
            EmptyView()
                .onAppear { onTap() }
        }
    }
}

// MARK: - Compact Folder View

struct FinderStyleCompactFolderView: View {
    let folder: SavedFolder
    let level: Int
    let isSelected: Bool
    let isExpanded: Bool
    let isCompactMode: Bool
    @Binding var selectedConnectionID: UUID?
    @Binding var selectedFolderID: UUID?
    @Binding var expandedFolders: Set<UUID>
    @ObservedObject private var dragManager = DragDropManager.shared

    let onFolderTap: () -> Void
    let onToggleExpansion: () -> Void

    // Callbacks (all optional)
    let onAddConnection: ((SavedFolder?) -> Void)?
    let onAddFolder: ((SavedFolder?) -> Void)?
    let onEditItem: ((SidebarItem) -> Void)?
    let onDeleteItem: ((SidebarItem) -> Void)?
    let onDuplicateItem: ((SidebarItem) -> Void)?
    let onConnectToConnection: ((SavedConnection) -> Void)?
    let onMoveConnection: ((UUID, SavedFolder?) -> Void)?

    @State private var isHovering = false
    @State private var isDropTargeted = false

    private var indentPerLevel: CGFloat { isCompactMode ? 16 : 20 }
    private var iconSize: CGFloat { isCompactMode ? 12 : 14 }

    private func connectAllInFolder(_ folder: SavedFolder) {
        func connectAllConnections(in items: [SidebarItem]) {
            for item in items {
                switch item {
                case .connection(let connection):
                    onConnectToConnection?(connection)
                case .folder(let subfolder):
                    connectAllConnections(in: subfolder.children)
                }
            }
        }
        connectAllConnections(in: folder.children)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompactMode ? 0 : 1) {
            // Folder header
            HStack(spacing: 0) {
                // Indentation
                if level > 0 {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: CGFloat(level) * indentPerLevel, height: 1)
                }

                HStack(spacing: 1) {
                    // Disclosure triangle with padding
                    Button(action: onToggleExpansion) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: isCompactMode ? 8 : 9, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .frame(width: isCompactMode ? 8 : 10, height: isCompactMode ? 8 : 10)
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.06), value: isExpanded)
                    .padding(.leading, level == 0 ? 4 : 0)

                    HStack(spacing: isCompactMode ? 4 : 6) {
                        // Folder icon
                        Image(systemName: "folder.fill")
                            .font(.system(size: iconSize - 1))
                            .foregroundStyle(folder.color)
                            .frame(width: iconSize, height: iconSize)

                        VStack(alignment: .leading, spacing: 0) {
                            Text(folder.name)
                                .font(.system(size: isCompactMode ? 12 : 13, weight: .medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            if !isCompactMode {
                                Text(folder.connectionCount == 1 ? "1 connection" : "\(folder.connectionCount) connections")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 0)

                        #if os(macOS)
                        if (isHovering || isSelected) && onEditItem != nil {
                            HStack(spacing: 4) {
                                Button(action: {
                                    connectAllInFolder(folder)
                                }) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: isCompactMode ? 11 : 12))
                                }
                                .buttonStyle(.plain)
                                .help("Connect All in Folder")

                                Button(action: { onEditItem?(.folder(folder)) }) {
                                    Image(systemName: "ellipsis.circle")
                                        .font(.system(size: isCompactMode ? 11 : 12))
                                }
                                .buttonStyle(.plain)
                                .help("Edit Folder")

                                Button(action: { onDeleteItem?(.folder(folder)) }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: isCompactMode ? 11 : 12))
                                }
                                .buttonStyle(.plain)
                                .help("Delete Folder")
                            }
                            .foregroundStyle(.secondary)
                            .transition(.opacity.animation(.easeInOut(duration: 0.08)))
                        }
                        #endif
                    }
                    .padding(.vertical, isCompactMode ? 2 : 3)
                    .padding(.horizontal, isCompactMode ? 4 : 6)
                    .sidebarSelectionStyle(isSelected: isSelected)
                    .background {
                        if isDropTargeted {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(Color.accentColor.opacity(0.15))
                        }
                    }
                }
            }
            #if os(macOS)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.08)) {
                    isHovering = hovering
                }
            }
            #endif
            .contentShape(Rectangle())
            .onTapGesture {
                onFolderTap()
            }
            .onTapGesture(count: 2) {
                onToggleExpansion()
            }
            .if(onEditItem != nil) { view in
                view.contextMenu {
                    Button("Connect All in Folder") {
                        connectAllInFolder(folder)
                    }
                    Divider()
                    Button("Edit Folder...") { onEditItem?(.folder(folder)) }
                    Button("Duplicate Folder") { onDuplicateItem?(.folder(folder)) }
                    if onAddConnection != nil {
                        Divider()
                        Button("New Connection in Folder...") { onAddConnection?(folder) }
                        Button("New Subfolder...") { onAddFolder?(folder) }
                        Divider()
                        Button("Delete Folder", role: .destructive) { onDeleteItem?(.folder(folder)) }
                    }
                } preview: {
                    EmptyView()
                        .onAppear { onFolderTap() }
                }
            }
            .if(onMoveConnection != nil) { view in
                view.dropDestination(for: String.self) { items, location in
                    guard let connectionIdString = items.first,
                          let connectionId = UUID(uuidString: connectionIdString) else {
                        return false
                    }
                    onMoveConnection?(connectionId, folder)
                    return true
                } isTargeted: { targeted in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isDropTargeted = targeted
                    }

                    if targeted && !isExpanded {
                        dragManager.startDragHover(over: folder.id, expandedFolders: expandedFolders)
                    } else {
                        dragManager.endDragHover()
                    }
                }
            }

            // Folder children
            if isExpanded {
                ForEach(Array(folder.children.enumerated()), id: \.element.id) { index, child in
                    VStack(spacing: 0) {
                        // Drop zone before child (only if drag/drop is enabled)
                        if index == 0 && onMoveConnection != nil {
                            DropZoneView(position: .beforeItem(child.id)) { draggedId in
                                handleChildDrop(draggedId, position: .beforeItem(child.id))
                            }
                        }

                        // Child item with increased indentation level
                        FinderStyleListItemView(
                            item: child,
                            level: level + 1,
                            selectedConnectionID: $selectedConnectionID,
                            selectedFolderID: $selectedFolderID,
                            expandedFolders: $expandedFolders,
                            isCompactMode: isCompactMode,
                            onAddConnection: onAddConnection,
                            onAddFolder: onAddFolder,
                            onEditItem: onEditItem,
                            onDeleteItem: onDeleteItem,
                            onDuplicateItem: onDuplicateItem,
                            onConnectToConnection: onConnectToConnection,
                            onMoveConnection: onMoveConnection
                        )

                        // Drop zone after child (only if drag/drop is enabled)
                        if onMoveConnection != nil {
                            DropZoneView(position: .afterItem(child.id)) { draggedId in
                                handleChildDrop(draggedId, position: .afterItem(child.id))
                            }
                        }
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(y: -1))
                        .animation(.easeOut(duration: 0.12)),
                    removal: .opacity.combined(with: .offset(y: -1))
                        .animation(.easeIn(duration: 0.08))
                ))
            }
        }
    }

    private func handleChildDrop(_ draggedIdString: String, position: DropPosition) -> Bool {
        guard let connectionId = UUID(uuidString: draggedIdString) else { return false }
        onMoveConnection?(connectionId, folder)
        return true
    }
}

