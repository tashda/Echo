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
            header.padding(.horizontal, SpacingTokens.md).padding(.top, SpacingTokens.sm)
            Divider().opacity(availableConnections.isEmpty ? 0 : 1).padding(.vertical, availableConnections.isEmpty ? 0 : SpacingTokens.xs)
            content
        }
        .onAppear(perform: initializeSelection)
        .onChange(of: connectionStore.selectedConnectionID) { _, n in if selectedConnectionID == nil, let n, connectionExists(n) { selectedConnectionID = n } }
        .onChange(of: availableConnections.map(\.id)) { _, _ in if let curr = selectedConnectionID { if !connectionExists(curr) { selectedConnectionID = nil; initializeSelection() } } else { initializeSelection() } }
        .onChange(of: selectedConnectionID) { _, _ in activePopoverBookmarkID = nil; recentlyOpenedBookmarkID = nil }
    }

    @ViewBuilder
    private var content: some View {
        if availableConnections.isEmpty { emptyConnectionsPlaceholder.frame(maxWidth: .infinity, maxHeight: .infinity).padding(SpacingTokens.xl) }
        else if let conn = currentConnection {
            let bookmarks = connectionBookmarks
            if bookmarks.isEmpty { emptyBookmarksPlaceholder(for: conn).frame(maxWidth: .infinity, maxHeight: .infinity).padding(SpacingTokens.xl) }
            else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: SpacingTokens.md) {
                        if groupByDatabase {
                            ForEach(bookmarks.groupedByDatabase()) { group in
                                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                                    Text(group.databaseName ?? "No Database").font(TypographyTokens.caption).fontWeight(.semibold).textCase(.uppercase).foregroundStyle(ColorTokens.Text.secondary).padding(.horizontal, SpacingTokens.sm)
                                    LazyVStack(spacing: SpacingTokens.sm) { ForEach(group.bookmarks) { b in BookmarkRow(bookmark: b, connection: conn, activePopoverID: $activePopoverBookmarkID, isRecentlyOpened: recentlyOpenedBookmarkID == b.id, onOpen: { open(bookmark: b) }, onCopy: { copy(bookmark: b) }, onRename: { rename(bookmark: b, title: $0) }, onDelete: { delete(bookmark: b) }).id(b.id) } }
                                }
                            }.padding(.horizontal, SpacingTokens.sm).padding(.top, SpacingTokens.xxs)
                        } else {
                            ForEach(bookmarks) { b in BookmarkRow(bookmark: b, connection: conn, activePopoverID: $activePopoverBookmarkID, isRecentlyOpened: recentlyOpenedBookmarkID == b.id, onOpen: { open(bookmark: b) }, onCopy: { copy(bookmark: b) }, onRename: { rename(bookmark: b, title: $0) }, onDelete: { delete(bookmark: b) }).id(b.id).padding(.horizontal, SpacingTokens.sm) }.padding(.top, SpacingTokens.xs)
                        }
                    }.padding(.bottom, SpacingTokens.lg)
                }
            }
        } else { emptyConnectionsPlaceholder.frame(maxWidth: .infinity, maxHeight: .infinity).padding(SpacingTokens.xl) }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: SpacingTokens.sm) {
            VStack(alignment: .leading, spacing: SpacingTokens.xxs) { Text("Bookmarks").font(TypographyTokens.headline); Text(headerSubtitle).font(TypographyTokens.footnote).foregroundStyle(ColorTokens.Text.secondary).lineLimit(2) }
            Spacer(minLength: 0); if !availableConnections.isEmpty { connectionPicker }; groupingMenu
        }
    }

    private var connectionPicker: some View {
        Menu {
            ForEach(availableConnections) { conn in
                Button { selectedConnectionID = conn.id } label: { if conn.id == currentConnection?.id { Label(connectionDisplayName(conn), systemImage: "checkmark") } else { Text(connectionDisplayName(conn)) } }
            }
        } label: {
            HStack(spacing: SpacingTokens.xxs2) { Image(systemName: "server.rack"); Text(connectionDisplayName(currentConnection)) }.font(TypographyTokens.footnote).foregroundStyle(ColorTokens.Text.secondary).padding(.horizontal, SpacingTokens.xs2).padding(.vertical, SpacingTokens.xxs2).background(Capsule().fill(ColorTokens.Text.primary.opacity(0.05)))
        }.menuIndicator(.hidden)
    }

    private var groupingMenu: some View {
        Menu {
            Button { groupByDatabase = true } label: { if groupByDatabase { Label("Group by Database", systemImage: "checkmark") } else { Text("Group by Database") } }
            Button { groupByDatabase = false } label: { if !groupByDatabase { Label("Show All", systemImage: "checkmark") } else { Text("Show All") } }
        } label: {
            Label(groupByDatabase ? "Grouped" : "All", systemImage: groupByDatabase ? "square.grid.2x2" : "list.bullet").font(TypographyTokens.footnote).padding(.horizontal, SpacingTokens.xs2).padding(.vertical, SpacingTokens.xxs2).background(Capsule().fill(ColorTokens.Text.primary.opacity(0.05)))
        }.menuIndicator(.hidden)
    }

    private var headerSubtitle: String { currentConnection.map { "Saved queries for \(connectionDisplayName($0))" } ?? "Select a server to view saved bookmarks" }
    private var availableConnections: [SavedConnection] { let pID = projectStore.selectedProject?.id; return connectionStore.connections.filter { $0.projectID == pID }.sorted { connectionDisplayName($0).localizedCaseInsensitiveCompare(connectionDisplayName($1)) == .orderedAscending } }
    private var currentConnection: SavedConnection? { if let id = selectedConnectionID, let c = availableConnections.first(where: { $0.id == id }) { return c }; if let sID = connectionStore.selectedConnectionID, let c = availableConnections.first(where: { $0.id == sID }) { return c }; return availableConnections.first }
    private var connectionBookmarks: [Bookmark] { currentConnection.map { environmentState.bookmarks(for: $0.id) } ?? [] }
    private func initializeSelection() { if let cID = selectedConnectionID, connectionExists(cID) { return }; if let appS = connectionStore.selectedConnectionID, connectionExists(appS) { selectedConnectionID = appS; return }; selectedConnectionID = availableConnections.first?.id }
    private func connectionExists(_ id: UUID) -> Bool { availableConnections.contains { $0.id == id } }
    private func connectionDisplayName(_ connection: SavedConnection?) -> String { guard let c = connection else { return "Select Server" }; let n = c.connectionName.trimmingCharacters(in: .whitespacesAndNewlines); if !n.isEmpty { return n }; let h = c.host.trimmingCharacters(in: .whitespacesAndNewlines); return h.isEmpty ? "Server" : h }
    private func open(bookmark: Bookmark) { recentlyOpenedBookmarkID = bookmark.id; if connectionStore.connections.contains(where: { $0.id == bookmark.connectionID }) { environmentState.openQueryTab(presetQuery: bookmark.query) }; DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { if recentlyOpenedBookmarkID == bookmark.id { withAnimation { recentlyOpenedBookmarkID = nil } } } }
    private func copy(bookmark: Bookmark) { environmentState.copyBookmark(bookmark) }
    private func delete(bookmark: Bookmark) { Task { await environmentState.removeBookmark(bookmark) } }
    private func rename(bookmark: Bookmark, title: String?) { Task { await environmentState.renameBookmark(bookmark, to: title) } }

    private var emptyConnectionsPlaceholder: some View {
        EmptyStatePlaceholder(icon: "bookmark", title: "No Servers", subtitle: "Add or select a server to start saving bookmarks.")
    }

    private func emptyBookmarksPlaceholder(for connection: SavedConnection) -> some View {
        EmptyStatePlaceholder(icon: "bookmark", title: "No Bookmarks Yet", subtitle: "Highlight a query or right-click a tab to save it for \(connectionDisplayName(connection)).")
    }
}
