import SwiftUI

struct ConnectionFolderView: View {
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
    @Environment(ConnectionStore.self) private var connectionStore

    private var isExpanded: Bool { isSearching || expandedFolders.contains(group.folder.id) }
    private var isSelected: Bool { connectionStore.selectedFolderID == group.folder.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            folderRow
            if isExpanded {
                ForEach(group.connections, id: \.id) { connection in
                    ConnectionListRow(connection: connection, isSelected: selectedConnectionID == connection.id, indent: CGFloat(group.depth + 1) * 16, onTap: { onSelectConnection(connection) }, onConnect: { onSelectConnection(connection); onConnect(connection) }, onEdit: { onSelectConnection(connection); onEditConnection(connection) }, onDuplicate: { onDuplicate(connection) }, onDelete: { onDelete(.connection(connection)) })
                }
                ForEach(group.children) { child in
                    ConnectionFolderView(group: child, expandedFolders: $expandedFolders, isSearching: isSearching, selectedConnectionID: $selectedConnectionID, onSelectFolder: onSelectFolder, onSelectConnection: onSelectConnection, onConnect: onConnect, onEditConnection: onEditConnection, onDuplicate: onDuplicate, onDelete: onDelete, onCreateConnection: onCreateConnection, onCreateFolder: onCreateFolder, onEditFolder: onEditFolder, onMoveConnection: onMoveConnection, onMoveFolder: onMoveFolder)
                }
                if group.connections.isEmpty && group.children.isEmpty { EmptyFolderPlaceholder(indent: CGFloat(group.depth + 1) * 16) }
            }
        }
    }

    private var folderRow: some View {
        let indent = CGFloat(group.depth) * SpacingTokens.md
        return HStack(spacing: SpacingTokens.xxs2) {
            Spacer().frame(width: indent)
            HStack(spacing: SpacingTokens.xs) {
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .font(TypographyTokens.label.weight(.semibold))
                    .foregroundStyle(ColorTokens.Text.secondary)
                Image(systemName: "folder.fill")
                    .font(TypographyTokens.prominent)
                    .foregroundStyle(group.folder.color)
                Text(group.folder.name)
                    .font(TypographyTokens.caption2)
                    .foregroundStyle(ColorTokens.Text.primary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text("\(group.totalConnectionCount)")
                    .font(TypographyTokens.label.weight(.semibold))
                    .foregroundStyle(ColorTokens.Text.secondary.opacity(0.8))
            }
            .padding(.horizontal, SpacingTokens.xs)
            .padding(.vertical, 5)
            .background(folderHighlight)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onTapGesture { toggleExpansion() }
            .onHover { h in withAnimation(.easeInOut(duration: 0.12)) { isHovering = h } }
            .contextMenu {
                // Group 2: New
                Button { onCreateConnection(group.folder) } label: {
                    Label("New Connection", systemImage: "network")
                }
                Button { onCreateFolder(group.folder) } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }

                Divider()

                // Group 4: Edit
                Button { onEditFolder(group.folder) } label: {
                    Label("Rename Folder", systemImage: "character.cursor.ibeam")
                }

                Divider()

                // Group 10: Destructive
                Button(role: .destructive) { onDelete(.folder(group.folder)) } label: {
                    Label("Delete Folder", systemImage: "trash")
                }
            }
        }.padding(.horizontal, SpacingTokens.xxs)
    }

    private var folderHighlight: some View {
        let base = RoundedRectangle(cornerRadius: 8, style: .continuous)
        if isSelected { return AnyView(base.fill(ColorTokens.accent.opacity(0.2)).overlay(base.stroke(ColorTokens.accent.opacity(0.4), lineWidth: 0.9))) }
        if isHovering { return AnyView(base.fill(ColorTokens.accent.opacity(0.12)).overlay(base.stroke(ColorTokens.accent.opacity(0.35), lineWidth: 0.8))) }
        return AnyView(Color.clear)
    }

    private func toggleExpansion() {
        onSelectFolder(group.folder)
        guard !isSearching else { return }
        if expandedFolders.contains(group.folder.id) { expandedFolders.remove(group.folder.id) }
        else { expandedFolders.insert(group.folder.id) }
    }
}

struct ConnectionListRow: View {
    let connection: SavedConnection
    let isSelected: Bool
    let indent: CGFloat
    let onTap: () -> Void
    let onConnect: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    @Environment(ProjectStore.self) private var projectStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    private var accentColor: Color { projectStore.globalSettings.accentColorSource == .connection ? connection.color : ColorTokens.accent }
    private var displayName: String { let t = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines); return t.isEmpty ? connection.host : t }

    var body: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: indent + 12)
            HStack(spacing: SpacingTokens.xs) {
                connectionIcon.frame(width: 14, height: 14)
                Text(displayName).font(TypographyTokens.caption2).foregroundStyle(ColorTokens.Text.primary).lineLimit(1)
                Spacer(minLength: 4)
                if isHovering { Button(action: onConnect) { connectIcon.frame(width: 12, height: 12) }.buttonStyle(.plain).foregroundStyle(connectGlyphColor) }
            }
            .padding(.horizontal, SpacingTokens.xs).padding(.vertical, SpacingTokens.xxs).frame(maxWidth: .infinity, alignment: .leading).background(highlightBackground).contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onTapGesture(perform: onTap)
            .onHover { h in withAnimation(.easeInOut(duration: 0.12)) { isHovering = h } }
            .contextMenu {
                Button(action: onConnect) { Label { Text("Connect") } icon: { connectIcon.frame(width: 12, height: 12).foregroundStyle(connectGlyphColor) } }
                Divider()
                Button(action: onEdit) { Label("Edit", systemImage: "pencil") }
                Button(action: onDuplicate) { Label("Duplicate", systemImage: "plus.square.on.square") }
                Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
            }
            .highPriorityGesture(TapGesture(count: 2).onEnded { onTap(); onConnect() })
        }.padding(.trailing, SpacingTokens.xxs)
    }

    @ViewBuilder
    private var connectionIcon: some View {
#if os(macOS)
        if let data = connection.logo, let img = NSImage(data: data) { Image(nsImage: img).resizable().aspectRatio(contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous)) }
        else { Image(connection.databaseType.iconName).resizable().renderingMode(.template).aspectRatio(contentMode: .fit).foregroundStyle(accentColor) }
#else
        Image(connection.databaseType.iconName).resizable().renderingMode(.template).aspectRatio(contentMode: .fit).foregroundStyle(accentColor)
#endif
    }

    @ViewBuilder
    private var highlightBackground: some View {
        let base = RoundedRectangle(cornerRadius: 8, style: .continuous)
        if isSelected { base.fill(accentColor.opacity(0.2)).overlay(base.stroke(accentColor.opacity(0.4), lineWidth: 1)) }
        else if isHovering { base.fill(accentColor.opacity(0.12)).overlay(base.stroke(accentColor.opacity(0.35), lineWidth: 0.8)) }
        else { Color.clear }
    }

    private var connectIcon: some View { Image("connect.cables").resizable().renderingMode(.template).aspectRatio(contentMode: .fit) }
    private var connectGlyphColor: Color { colorScheme == .dark ? .white : .black }
}

struct EmptyFolderPlaceholder: View {
    let indent: CGFloat
    var body: some View { Text("No connections in this folder").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary).padding(.horizontal, SpacingTokens.sm).padding(.vertical, SpacingTokens.xxs2).padding(.leading, indent) }
}

struct ConnectionsEmptyState: View {
    let query: String
    let isSearching: Bool
    var body: some View {
        ContentUnavailableView {
            Label(isSearching ? "No matches for \(query.isEmpty ? "your search" : "'\(query)'")" : "No Connections", systemImage: isSearching ? "magnifyingglass" : "externaldrive")
        } description: {
            Text(isSearching ? "Try adjusting your search." : "Use the plus button to add your first connection or organize folders.")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpacingTokens.xl2)
    }
}
