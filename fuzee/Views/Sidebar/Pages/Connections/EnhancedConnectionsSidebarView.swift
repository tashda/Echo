import SwiftUI
#if os(macOS)
import AppKit
#endif

struct EnhancedConnectionsSidebarView: View {
    @Binding var selectedConnectionID: UUID?
    @Binding var selectedFolderID: UUID?
    let connections: [SavedConnection]
    let folders: [SavedFolder]

    // Callbacks
    let onAddConnection: (SavedFolder?) -> Void
    let onAddFolder: (SavedFolder?) -> Void
    let onEditItem: (SidebarItem) -> Void
    let onDeleteItem: (SidebarItem) -> Void
    let onDuplicateItem: (SidebarItem) -> Void
    let onConnectToConnection: (SavedConnection) -> Void
    let onMoveConnection: (UUID, SavedFolder?) -> Void

    @State private var expandedFolders: Set<UUID> = []
    @ObservedObject private var dragManager = DragDropManager.shared

    private var items: [SidebarItem] {
        let folderItems = folders.map { SidebarItem.folder($0) }
        let connectionItems = connections.map { SidebarItem.connection($0) }
        return folderItems + connectionItems
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 1) { // Reduced spacing for tighter layout
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    VStack(spacing: 0) {
                        // Drop zone before item
                        if index == 0 {
                            DropZoneView(position: .beforeItem(item.id)) { draggedId in
                                handleDrop(draggedId, position: .beforeItem(item.id))
                            }
                        }

                        // The actual item
                        FinderStyleSidebarItemView(
                            item: item,
                            level: 0,
                            selectedConnectionID: $selectedConnectionID,
                            selectedFolderID: $selectedFolderID,
                            expandedFolders: $expandedFolders,
                            onAddConnection: onAddConnection,
                            onAddFolder: onAddFolder,
                            onEditItem: onEditItem,
                            onDeleteItem: onDeleteItem,
                            onDuplicateItem: onDuplicateItem,
                            onConnectToConnection: onConnectToConnection,
                            onMoveConnection: onMoveConnection
                        )

                        // Drop zone after item
                        DropZoneView(position: .afterItem(item.id)) { draggedId in
                            handleDrop(draggedId, position: .afterItem(item.id))
                        }
                    }
                }

                // Final drop zone at the end
                DropZoneView(position: .atRootEnd) { draggedId in
                    handleDrop(draggedId, position: .atRootEnd)
                }
                .frame(minHeight: 40) // Reduced height for cleaner look
            }
        }
        .onReceive(dragManager.$expandedFoldersOnDrag) { expandedOnDrag in
            // Merge drag-expanded folders with manually expanded ones
            for folderId in expandedOnDrag {
                if !expandedFolders.contains(folderId) {
                    _ = withAnimation(.easeInOut(duration: 0.25)) {
                        expandedFolders.insert(folderId)
                    }
                }
            }
        }
    }

    private func handleDrop(_ draggedIdString: String, position: DropPosition) -> Bool {
        guard let connectionId = UUID(uuidString: draggedIdString) else { return false }

        switch position {
        case .beforeItem(_), .afterItem(_):
            // For now, just move to root - could implement precise positioning later
            onMoveConnection(connectionId, nil)
        case .intoFolder(let folderId):
            let folder = folders.first { $0.id == folderId }
            onMoveConnection(connectionId, folder)
        case .atRootEnd:
            onMoveConnection(connectionId, nil)
        }

        return true
    }
}

// MARK: - Finder-Style Sidebar Item View

struct FinderStyleSidebarItemView: View {
    let item: SidebarItem
    let level: Int
    @Binding var selectedConnectionID: UUID?
    @Binding var selectedFolderID: UUID?
    @Binding var expandedFolders: Set<UUID>

    // Callbacks
    let onAddConnection: (SavedFolder?) -> Void
    let onAddFolder: (SavedFolder?) -> Void
    let onEditItem: (SidebarItem) -> Void
    let onDeleteItem: (SidebarItem) -> Void
    let onDuplicateItem: (SidebarItem) -> Void
    let onConnectToConnection: (SavedConnection) -> Void
    let onMoveConnection: (UUID, SavedFolder?) -> Void

    private let indentPerLevel: CGFloat = 12
    private let iconSize: CGFloat = 14

    var body: some View {
        switch item {
        case .connection(let connection):
            FinderStyleConnectionRowView(
                connection: connection,
                level: level,
                isSelected: selectedConnectionID == connection.id,
                onTap: {
                    selectedConnectionID = connection.id
                    selectedFolderID = nil
                },
                onConnect: { onConnectToConnection(connection) },
                onEdit: { onEditItem(.connection(connection)) },
                onDuplicate: { onDuplicateItem(.connection(connection)) },
                onDelete: { onDeleteItem(.connection(connection)) }
            )

        case .folder(let folder):
            FinderStyleFolderView(
                folder: folder,
                level: level,
                isSelected: selectedFolderID == folder.id,
                isExpanded: expandedFolders.contains(folder.id),
                selectedConnectionID: $selectedConnectionID,
                selectedFolderID: $selectedFolderID,
                expandedFolders: $expandedFolders,
                onFolderTap: {
                    selectedFolderID = folder.id
                    selectedConnectionID = nil
                },
                onToggleExpansion: {
                    withAnimation(.easeInOut(duration: 0.15)) {
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

// MARK: - Finder-Style Connection Row View

struct FinderStyleConnectionRowView: View {
    let connection: SavedConnection
    let level: Int
    let isSelected: Bool
    let onTap: () -> Void
    let onConnect: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    private let indentPerLevel: CGFloat = 12
    private let iconSize: CGFloat = 14

    var body: some View {
        HStack(spacing: 0) {
            // Indentation
            Rectangle()
                .fill(Color.clear)
                .frame(width: CGFloat(level) * indentPerLevel, height: 1)

            HStack(spacing: 8) {
                Image(systemName: connection.databaseType.iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconSize + 4, height: iconSize + 4)
                    .foregroundStyle(connection.color)

                VStack(alignment: .leading, spacing: 1) {
                    Text(connection.connectionName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .lineLimit(1)

                    Text("\(connection.username)@\(connection.host)")
                        .font(.system(size: 11))
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                #if os(macOS)
                if isHovering && !isSelected {
                    HStack(spacing: 4) {
                        Button(action: onConnect) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 9))
                        }
                        .buttonStyle(.plain)
                        .help("Connect")

                        Button(action: onEdit) {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 9))
                        }
                        .buttonStyle(.plain)
                        .help("Edit Connection")
                    }
                    .foregroundStyle(.secondary)
                    .transition(.opacity.animation(.easeInOut(duration: 0.08)))
                }
                #endif
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.accentColor)
                } else if isHovering {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
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
        .draggable(connection.id.uuidString) {
            HStack(spacing: 4) {
                Image(connection.databaseType.iconName)
                    .frame(width: 12, height: 12)
                Text(connection.connectionName)
                    .font(.system(size: 11))
            }
            .padding(3)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 3))
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
            Button("Connect", action: onConnect)
            Divider()
            Button("Edit...", action: onEdit)
            Button("Duplicate", action: onDuplicate)
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        } preview: {
            let _ = onTap()
        }
    }
}

// MARK: - Finder-Style Folder View

struct FinderStyleFolderView: View {
    let folder: SavedFolder
    let level: Int
    let isSelected: Bool
    let isExpanded: Bool
    @Binding var selectedConnectionID: UUID?
    @Binding var selectedFolderID: UUID?
    @Binding var expandedFolders: Set<UUID>
    @ObservedObject private var dragManager = DragDropManager.shared

    let onFolderTap: () -> Void
    let onToggleExpansion: () -> Void

    // Callbacks
    let onAddConnection: (SavedFolder?) -> Void
    let onAddFolder: (SavedFolder?) -> Void
    let onEditItem: (SidebarItem) -> Void
    let onDeleteItem: (SidebarItem) -> Void
    let onDuplicateItem: (SidebarItem) -> Void
    let onConnectToConnection: (SavedConnection) -> Void
    let onMoveConnection: (UUID, SavedFolder?) -> Void

    @State private var isHovering = false
    @State private var isDropTargeted = false

    private let indentPerLevel: CGFloat = 12
    private let iconSize: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            // Folder header
            HStack(spacing: 0) {
                // Indentation
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: CGFloat(level) * indentPerLevel, height: 1)

                HStack(spacing: 2) {
                    // Disclosure triangle
                    Button(action: onToggleExpansion) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .frame(width: 10, height: 10)
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.12), value: isExpanded)

                    HStack(spacing: 6) {
                        // Folder icon
                        Image(systemName: isExpanded ? "folder.fill" : "folder.fill")
                            .font(.system(size: iconSize - 1))
                            .foregroundStyle(isSelected ? .white : .secondary)
                            .frame(width: iconSize, height: iconSize)

                        VStack(alignment: .leading, spacing: 0) {
                            Text(folder.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(isSelected ? .white : .primary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)

                        #if os(macOS)
                        if isHovering && !isSelected {
                            HStack(spacing: 4) {
                                Button(action: { onEditItem(.folder(folder)) }) {
                                    Image(systemName: "ellipsis.circle")
                                        .font(.system(size: 9))
                                }
                                .buttonStyle(.plain)
                                .help("Edit Folder")

                                Button(action: { onDeleteItem(.folder(folder)) }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 9))
                                }
                                .buttonStyle(.plain)
                                .help("Delete Folder")
                            }
                            .foregroundStyle(.secondary)
                            .transition(.opacity.animation(.easeInOut(duration: 0.08)))
                        }
                        #endif
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 6)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.accentColor)
                        } else if isHovering {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        } else if isDropTargeted {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
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
            .contextMenu {
                Button("Edit Folder...") { onEditItem(.folder(folder)) }
                Button("Duplicate Folder") { onDuplicateItem(.folder(folder)) }
                Divider()
                Button("New Connection in Folder...") { onAddConnection(folder) }
                Button("New Subfolder...") { onAddFolder(folder) }
                Divider()
                Button("Delete Folder", role: .destructive) { onDeleteItem(.folder(folder)) }
            }
            .dropDestination(for: String.self) { items, location in
                guard let connectionIdString = items.first,
                      let connectionId = UUID(uuidString: connectionIdString) else {
                    return false
                }
                onMoveConnection(connectionId, folder)
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

            // Folder children
            if isExpanded {
                ForEach(Array(folder.children.enumerated()), id: \.element.id) { index, child in
                    VStack(spacing: 0) {
                        // Drop zone before child
                        if index == 0 {
                            DropZoneView(position: .beforeItem(child.id)) { draggedId in
                                handleChildDrop(draggedId, position: .beforeItem(child.id))
                            }
                        }

                        // Child item with increased indentation level
                        FinderStyleSidebarItemView(
                            item: child,
                            level: level + 1,
                            selectedConnectionID: $selectedConnectionID,
                            selectedFolderID: $selectedFolderID,
                            expandedFolders: $expandedFolders,
                            onAddConnection: onAddConnection,
                            onAddFolder: onAddFolder,
                            onEditItem: onEditItem,
                            onDeleteItem: onDeleteItem,
                            onDuplicateItem: onDuplicateItem,
                            onConnectToConnection: onConnectToConnection,
                            onMoveConnection: onMoveConnection
                        )

                        // Drop zone after child
                        DropZoneView(position: .afterItem(child.id)) { draggedId in
                            handleChildDrop(draggedId, position: .afterItem(child.id))
                        }
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(y: -2))
                        .animation(.easeOut(duration: 0.15)),
                    removal: .opacity.combined(with: .offset(y: -1))
                        .animation(.easeIn(duration: 0.1))
                ))
            }
        }
    }

    private func handleChildDrop(_ draggedIdString: String, position: DropPosition) -> Bool {
        guard let connectionId = UUID(uuidString: draggedIdString) else { return false }
        onMoveConnection(connectionId, folder)
        return true
    }
}
