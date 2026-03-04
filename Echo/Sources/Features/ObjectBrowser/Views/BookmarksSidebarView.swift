import SwiftUI

struct BookmarksSidebarView: View {
    @Environment(ProjectStore.self) private var projectStore
    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(NavigationStore.self) private var navigationStore
    
    @EnvironmentObject private var environmentState: EnvironmentState
    @AppStorage("BookmarksSidebarGroupByDatabase") private var groupByDatabase = true

    @State private var selectedConnectionID: UUID?
    @State private var activePopoverBookmarkID: UUID?
    @State private var recentlyOpenedBookmarkID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 12)

            Divider()
                .opacity(availableConnections.isEmpty ? 0 : 1)
                .padding(.vertical, availableConnections.isEmpty ? 0 : 8)

            content
        }
        .onAppear(perform: initializeSelection)
        .onChange(of: connectionStore.selectedConnectionID) { _, newValue in
            guard selectedConnectionID == nil else { return }
            if let newValue, connectionExists(newValue) {
                selectedConnectionID = newValue
            }
        }
        .onChange(of: availableConnections.map(\.id)) { _, _ in
            guard let currentID = selectedConnectionID else {
                initializeSelection()
                return
            }
            if !connectionExists(currentID) {
                selectedConnectionID = nil
                initializeSelection()
            }
        }
        .onChange(of: selectedConnectionID) { _, _ in
            activePopoverBookmarkID = nil
            recentlyOpenedBookmarkID = nil
        }
    }

    @ViewBuilder
    private var content: some View {
        if availableConnections.isEmpty {
            emptyConnectionsPlaceholder
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(32)
        } else if let connection = currentConnection {
            let bookmarks = connectionBookmarks
            if bookmarks.isEmpty {
                emptyBookmarksPlaceholder(for: connection)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(32)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        if groupByDatabase {
                            ForEach(bookmarks.groupedByDatabase()) { group in
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(group.databaseName ?? "No Database")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .textCase(.uppercase)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 12)
                                    LazyVStack(spacing: 12) {
                                        ForEach(group.bookmarks) { bookmark in
                                            BookmarkRow(
                                                bookmark: bookmark,
                                                connection: connection,
                                                activePopoverID: $activePopoverBookmarkID,
                                                isRecentlyOpened: recentlyOpenedBookmarkID == bookmark.id,
                                                onOpen: { open(bookmark: bookmark) },
                                                onCopy: { copy(bookmark: bookmark) },
                                                onRename: { title in rename(bookmark: bookmark, title: title) },
                                                onDelete: { delete(bookmark: bookmark) }
                                            )
                                            .id(bookmark.id)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.top, 4)
                        } else {
                            ForEach(bookmarks) { bookmark in
                                BookmarkRow(
                                    bookmark: bookmark,
                                    connection: connection,
                                    activePopoverID: $activePopoverBookmarkID,
                                    isRecentlyOpened: recentlyOpenedBookmarkID == bookmark.id,
                                    onOpen: { open(bookmark: bookmark) },
                                    onCopy: { copy(bookmark: bookmark) },
                                    onRename: { title in rename(bookmark: bookmark, title: title) },
                                    onDelete: { delete(bookmark: bookmark) }
                                )
                                .id(bookmark.id)
                                .padding(.horizontal, 12)
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
        } else {
            emptyConnectionsPlaceholder
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(32)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Bookmarks")
                    .font(.headline)
                Text(headerSubtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            if !availableConnections.isEmpty {
                connectionPicker
            }

            groupingMenu
        }
    }

    private var connectionPicker: some View {
        Menu {
            ForEach(availableConnections) { connection in
                Button {
                    selectedConnectionID = connection.id
                } label: {
                    if connection.id == currentConnection?.id {
                        Label(connectionDisplayName(connection), systemImage: "checkmark")
                    } else {
                        Text(connectionDisplayName(connection))
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "server.rack")
                Text(connectionDisplayName(currentConnection))
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.primary.opacity(0.05))
            )
        }
        .menuIndicator(.hidden)
    }

    private var groupingMenu: some View {
        Menu {
            Button {
                groupByDatabase = true
            } label: {
                if groupByDatabase {
                    Label("Group by Database", systemImage: "checkmark")
                } else {
                    Text("Group by Database")
                }
            }

            Button {
                groupByDatabase = false
            } label: {
                if !groupByDatabase {
                    Label("Show All", systemImage: "checkmark")
                } else {
                    Text("Show All")
                }
            }
        } label: {
            Label(groupByDatabase ? "Grouped" : "All", systemImage: groupByDatabase ? "square.grid.2x2" : "list.bullet")
                .font(.footnote)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.primary.opacity(0.05))
                )
        }
        .menuIndicator(.hidden)
    }

    private var headerSubtitle: String {
        guard let connection = currentConnection else {
            return "Select a server to view saved bookmarks"
        }
        return "Saved queries for \(connectionDisplayName(connection))"
    }

    private var availableConnections: [SavedConnection] {
        let projectID = projectStore.selectedProject?.id
        return connectionStore.connections
            .filter { $0.projectID == projectID }
            .sorted { connectionDisplayName($0).localizedCaseInsensitiveCompare(connectionDisplayName($1)) == .orderedAscending }
    }

    private var currentConnection: SavedConnection? {
        if let id = selectedConnectionID, let connection = availableConnections.first(where: { $0.id == id }) {
            return connection
        }
        if let selectedID = connectionStore.selectedConnectionID, let connection = availableConnections.first(where: { $0.id == selectedID }) {
            return connection
        }
        return availableConnections.first
    }

    private var connectionBookmarks: [Bookmark] {
        guard let connection = currentConnection else { return [] }
        return environmentState.bookmarks(for: connection.id)
    }

    private func initializeSelection() {
        if let currentID = selectedConnectionID, connectionExists(currentID) { return }
        if let appSelected = connectionStore.selectedConnectionID, connectionExists(appSelected) {
            selectedConnectionID = appSelected
            return
        }
        if let first = availableConnections.first?.id {
            selectedConnectionID = first
        }
    }

    private func connectionExists(_ id: UUID) -> Bool {
        availableConnections.contains { $0.id == id }
    }

    private func connectionDisplayName(_ connection: SavedConnection?) -> String {
        guard let connection else { return "Select Server" }
        let name = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            return name
        }
        let host = connection.host.trimmingCharacters(in: .whitespacesAndNewlines)
        return host.isEmpty ? "Server" : host
    }

    private func connectionDisplayName(_ connection: SavedConnection) -> String {
        connectionDisplayName(Optional(connection))
    }

    private func open(bookmark: Bookmark) {
        recentlyOpenedBookmarkID = bookmark.id
        // recentlyOpenedBookmarkID logic preservation
        if let connection = connectionStore.connections.first(where: { $0.id == bookmark.connectionID }) {
            environmentState.openQueryTab(presetQuery: bookmark.query)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if recentlyOpenedBookmarkID == bookmark.id {
                withAnimation(.easeInOut(duration: 0.2)) {
                    recentlyOpenedBookmarkID = nil
                }
            }
        }
    }

    private func copy(bookmark: Bookmark) {
        environmentState.copyBookmark(bookmark)
    }

    private func delete(bookmark: Bookmark) {
        Task {
            await environmentState.removeBookmark(bookmark)
        }
    }

    private func rename(bookmark: Bookmark, title: String?) {
        Task {
            await environmentState.renameBookmark(bookmark, to: title)
        }
    }

    private var emptyConnectionsPlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(.tertiary)
            VStack(spacing: 6) {
                Text("No Servers")
                    .font(.title3.weight(.semibold))
                Text("Add or select a server to start saving bookmarks.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func emptyBookmarksPlaceholder(for connection: SavedConnection) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(connection.color)
            VStack(spacing: 8) {
                Text("No Bookmarks Yet")
                    .font(.title3.weight(.semibold))
                Text("Highlight a query or right-click a tab to save it for \(connectionDisplayName(connection)).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

private struct BookmarkRow: View {
    let bookmark: Bookmark
    let connection: SavedConnection
    @Binding var activePopoverID: UUID?
    let isRecentlyOpened: Bool
    let onOpen: () -> Void
    let onCopy: () -> Void
    let onRename: (String?) -> Void
    let onDelete: () -> Void

    @State private var isHovering = false
    @State private var isRenaming = false
    @State private var renameText = ""
    @FocusState private var renameFieldFocused: Bool

    private var isInfoPresented: Bool {
        activePopoverID == bookmark.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                icon

                VStack(alignment: .leading, spacing: 8) {
                    headerRow

                    Text(bookmark.preview)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    metadataSection
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
        }
        .background(backgroundShape)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isRecentlyOpened ? Color.accentColor.opacity(0.6) : .clear, lineWidth: 1.2)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture(perform: onOpen)
        .contextMenu {
            Button(action: onOpen) {
                Label("Open in New Tab", systemImage: "arrow.up.right.square")
            }
            Button(action: onCopy) {
                Label("Copy", systemImage: "doc.on.doc")
            }
            Button(action: beginRenaming) {
                Label("Rename", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("Delete Bookmark", systemImage: "trash")
            }
        }
#if os(macOS)
        .onHover { hovering in
            isHovering = hovering
        }
#endif
        .popover(
            isPresented: Binding(
                get: { isInfoPresented },
                set: { newValue in
                    activePopoverID = newValue ? bookmark.id : nil
                }
            ),
            arrowEdge: .leading
        ) {
            popoverContent
                .frame(width: 420)
        }
        .onChange(of: bookmark.id) { _, _ in
            cancelRenaming()
        }
        .onChange(of: bookmark.title) { _, _ in
            if !isRenaming {
                renameText = currentTitleSeed
            }
        }
    }

    private var icon: some View {
        Image(systemName: sourceIconName)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(sourceTint)
            .frame(width: 32, height: 32)
            .background(sourceTint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 8) {
            if isRenaming {
                TextField("Bookmark title", text: $renameText, onCommit: commitRename)
                    .textFieldStyle(.plain)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .focused($renameFieldFocused)
#if os(macOS)
                    .onExitCommand {
                        cancelRenaming()
                    }
#endif
                    .onAppear {
                        renameText = currentTitleSeed
                        DispatchQueue.main.async {
                            renameFieldFocused = true
                        }
                    }
                    .onChange(of: renameFieldFocused) { _, focused in
                        if !focused {
                            commitRename()
                        }
                    }
            } else {
                Text(bookmark.primaryLine)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text(bookmark.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .opacity(isRenaming ? 0 : 1)

            if !isRenaming {
                Button {
                    toggleInfoPopover()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var metadataSection: some View {
        HStack(spacing: 8) {
            metadataBadge(icon: "server.rack", text: connectionDisplayName, tint: connectionTint)
            if let database = bookmark.databaseName?.trimmingCharacters(in: .whitespacesAndNewlines), !database.isEmpty {
                metadataBadge(icon: "cylinder", text: database, tint: connectionTint)
            }
        }
    }

    private var popoverContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Bookmark Details")
                .font(.headline)

            ScrollView {
                Text(bookmark.query)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 260)

            HStack(spacing: 12) {
                Button(action: onOpen) {
                    Label("Open in New Tab", systemImage: "arrow.up.right.square")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)

                Button(action: onCopy) {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
    }

    private var currentTitleSeed: String {
        if let title = bookmark.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return title
        }
        return bookmark.primaryLine
    }

    private func beginRenaming() {
        renameText = currentTitleSeed
        isRenaming = true
        activePopoverID = nil
        DispatchQueue.main.async {
            renameFieldFocused = true
        }
    }

    private func commitRename() {
        guard isRenaming else { return }
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        let newTitle = trimmed.isEmpty ? nil : trimmed
        let normalizedExisting: String?
        if let existing = bookmark.title?.trimmingCharacters(in: .whitespacesAndNewlines), !existing.isEmpty {
            normalizedExisting = existing
        } else {
            normalizedExisting = nil
        }
        if newTitle != normalizedExisting {
            onRename(newTitle)
        }
        finishRenaming()
    }

    private func cancelRenaming() {
        guard isRenaming else { return }
        finishRenaming()
    }

    private func finishRenaming() {
        isRenaming = false
        renameFieldFocused = false
    }

    private func toggleInfoPopover() {
        activePopoverID = isInfoPresented ? nil : bookmark.id
    }

    private var backgroundShape: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(isHovering ? Color.primary.opacity(0.06) : Color.primary.opacity(0.02))
    }

    private func metadataBadge(icon: String, text: String, tint: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.caption)
            .foregroundStyle(tint)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(tint.opacity(0.18), in: Capsule())
    }

    private var connectionTint: Color {
        if let hex = connection.metadataColorHex, let color = Color(hex: hex) {
            return color
        }
        return connection.color
    }

    private var connectionDisplayName: String {
        let name = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return name }
        let host = connection.host.trimmingCharacters(in: .whitespacesAndNewlines)
        return host.isEmpty ? "Server" : host
    }

    private var sourceIconName: String {
        switch bookmark.source {
        case .queryEditorSelection: return "text.cursor"
        case .savedQuery: return "bookmark"
        case .tab: return "doc.text"
        }
    }

    private var sourceTint: Color {
        switch bookmark.source {
        case .queryEditorSelection: return .accentColor
        case .savedQuery: return .orange
        case .tab: return .blue
        }
    }
}
