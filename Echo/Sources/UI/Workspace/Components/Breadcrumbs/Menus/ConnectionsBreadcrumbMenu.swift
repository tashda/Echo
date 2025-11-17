import SwiftUI

struct ConnectionsBreadcrumbMenu: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var searchText = ""
    @State private var expandedFolderIDs: Set<UUID> = []

    private var filteredConnections: [SavedConnection] {
        if searchText.isEmpty {
            return appModel.connections
        }
        return appModel.connections.filter { connection in
            connection.connectionName.localizedCaseInsensitiveContains(searchText) ||
            connection.host.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredFolders: [SavedFolder] {
        if searchText.isEmpty {
            return appModel.folders.filter { $0.kind == .connections }
        }
        return appModel.folders.filter { folder in
            folder.kind == .connections &&
            folder.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with search
            VStack(alignment: .leading, spacing: 8) {
                Text("Connections")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                MenuSearchField(text: $searchText, placeholder: "Search connections...")
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Menu items
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    // Quick Connect
                    MenuSectionView(title: "Quick Connect") {
                        MenuItemView(
                            title: "New Connection...",
                            icon: "plus",
                            iconColor: .blue
                        ) {
                            // Handle new connection
                            // This will need to be handled through AppState
                            // For now, we'll just print a message
                            print("Show connection editor")
                        }
                    }

                    MenuSeparator()

                    // Folders and connections
                    if !filteredFolders.isEmpty || !filteredConnections.isEmpty {
                        MenuSectionView {
                            // Folders
                            ForEach(filteredFolders.filter { $0.parentFolderID == nil }, id: \.id) { folder in
                                FolderMenuItem(
                                    folder: folder,
                                    searchText: searchText,
                                    expandedFolderIDs: $expandedFolderIDs
                                )
                            }

                            // Root-level connections
                            ForEach(filteredConnections.filter { $0.folderID == nil }, id: \.id) { connection in
                                ConnectionMenuItem(connection: connection)
                            }
                        }
                    }

                    // No results
                    if filteredFolders.isEmpty && filteredConnections.isEmpty && !searchText.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 20))
                                .foregroundStyle(.secondary)
                            Text("No connections found")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    }

                    MenuSeparator()

                    // Management actions
                    MenuSectionView {
                        MenuItemView(
                            title: "Manage Connections...",
                            icon: "gearshape",
                            iconColor: .secondary
                        ) {
                            // Handle manage connections
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            .frame(maxHeight: 300)
        }
        .frame(width: 280)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Folder Menu Item

struct FolderMenuItem: View {
    let folder: SavedFolder
    let searchText: String
    @Binding var expandedFolderIDs: Set<UUID>

    @EnvironmentObject private var appModel: AppModel
    @State private var isHovered = false

    private var isExpanded: Bool {
        expandedFolderIDs.contains(folder.id)
    }

    private var childFolders: [SavedFolder] {
        appModel.folders.filter { $0.parentFolderID == folder.id && $0.kind == .connections }
    }

    private var childConnections: [SavedConnection] {
        appModel.connections.filter { $0.folderID == folder.id }
    }

    private var hasVisibleChildren: Bool {
        !childFolders.isEmpty || !childConnections.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Folder item
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded {
                        expandedFolderIDs.remove(folder.id)
                    } else {
                        expandedFolderIDs.insert(folder.id)
                    }
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "folder.fill" : "folder")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.blue)

                    Text(folder.name)
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)

                    Spacer()

                    if hasVisibleChildren {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isHovered ? Color.accentColor.opacity(0.08) : Color.clear)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }

            // Child items (when expanded)
            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(childFolders, id: \.id) { childFolder in
                        FolderMenuItem(
                            folder: childFolder,
                            searchText: searchText,
                            expandedFolderIDs: $expandedFolderIDs
                        )
                        .padding(.leading, 16)
                    }

                    ForEach(childConnections, id: \.id) { connection in
                        ConnectionMenuItem(connection: connection)
                            .padding(.leading, 16)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Connection Menu Item

struct ConnectionMenuItem: View {
    let connection: SavedConnection

    @EnvironmentObject private var appModel: AppModel
    @State private var isHovered = false

    private var isConnected: Bool {
        appModel.sessionManager.sessions.contains { $0.connection.id == connection.id }
    }

    private var connectionIcon: String {
        connection.databaseType.iconName
    }

    var body: some View {
        Button(action: {
            // Handle connection selection
            Task {
                await appModel.connect(to: connection)
            }
        }) {
            HStack(spacing: 10) {
                // Connection icon
                ZStack {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(connection.color.opacity(0.15))
                        .frame(width: 20, height: 20)
                    Image(connectionIcon)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(connection.color)
                }

                // Connection info
                VStack(alignment: .leading, spacing: 2) {
                    Text(connection.connectionName.isEmpty ? connection.host : connection.connectionName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text("\(connection.username)@\(connection.host)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Status indicator
                if isConnected {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isHovered ? Color.accentColor.opacity(0.08) : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}