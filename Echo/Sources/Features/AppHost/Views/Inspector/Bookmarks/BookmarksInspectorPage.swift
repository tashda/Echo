import SwiftUI
#if os(macOS)
import AppKit
#endif

/// The inspector's Bookmarks page (round IC): every server of the project, in folders you order
/// (one level, No Folder last), each folder's bookmarks in a grouped box in your order. A row is
/// the name with when it was last used, then the server's dot, server and database; its glyph says
/// what the statement does. A click opens the row in place (the SQL, the note, Open or Connect and
/// Open, Insert, Copy, ⋯); double-click or Return opens a tab whose home is the bookmark.
/// Folders: New Folder, rename inline (double-click), drag to reorder, ⌥⌘↑↓, delete asking what
/// happens to the bookmarks inside. Bookmarks drag between folders, and into the editor as SQL.
struct BookmarksInspectorPage: View {
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(AppState.self) private var appState
    @Environment(\.echoMotion) private var motion
    @Environment(\.undoManager) private var undoManager
    @AppStorage("inspector.bookmarks.folded") private var foldedStorage = ""

    @State private var search = ""
    @State private var scopeConnectionID: UUID?
    @State private var selectedID: UUID?
    @State private var renamingFolder: String?
    @State private var folderDraft = ""
    @State private var folderError: String?
    @State private var renamingBookmarkID: UUID?
    @State private var titleDraft = ""
    @State private var noteBookmark: Bookmark?
    @State private var noteDraft = ""
    @State private var deletion: FolderDeletionRequest?
    @State private var dropTarget: String?
    /// Show in Bookmarks: the row to scroll to once it is in the list.
    @State private var scrollTarget: UUID?
    @FocusState private var focus: Field?

    private enum Field: Hashable { case list, folderName, bookmarkTitle }

    private var repository: BookmarkRepository { environmentState.bookmarkRepository }
    private var project: Project? { environmentState.bookmarkProject }

    var body: some View {
        let groups = folderGroups()
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            InspectorPageHeader(summary: summary) {
                Button {
                    newFolder()
                } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
                .help("New Folder")
                .disabled(project == nil)
                menu
            }
            InspectorSearchField(text: $search, prompt: "Search bookmarks",
                                 token: scopeName, onRemoveToken: { scopeConnectionID = nil })
            if groups.isEmpty {
                emptyState
            } else {
                list(groups)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(motion.standard, value: selectedID)
        .onChange(of: appState.revealedBookmarkID, initial: true) { _, id in
            if let id { reveal(id) }
        }
        .sheet(item: $deletion) { request in
            FolderDeletionSheet(request: request,
                                otherFolders: (project?.bookmarkFolders ?? []).filter { $0 != request.name },
                                onKeep: { destination in deleteFolder(request.name, .keepBookmarks(movedTo: destination)) },
                                onDeleteAll: { deleteFolder(request.name, .deleteBookmarks) })
        }
        .alert(noteBookmark.map { "Note for “\($0.primaryLine)”" } ?? "Note", isPresented: Binding(
            get: { noteBookmark != nil },
            set: { if !$0 { noteBookmark = nil } }
        )) {
            TextField("Note", text: $noteDraft)
            Button("Save") { saveNote() }
            Button("Cancel", role: .cancel) { noteBookmark = nil }
        } message: {
            Text("Shown when the bookmark is opened in the list.")
        }
    }

    // MARK: - List

    private func list(_ groups: [BookmarkFolderGroup]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: SpacingTokens.none) {
                    ForEach(groups) { group in
                        heading(group)
                        if !isFolded(group) {
                            InspectorGroupBox {
                                if group.bookmarks.isEmpty {
                                    Text("Drag bookmarks here")
                                        .font(TypographyTokens.detail)
                                        .foregroundStyle(ColorTokens.Text.tertiary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, SpacingTokens.sm)
                                }
                                ForEach(Array(group.bookmarks.enumerated()), id: \.element.id) { index, bookmark in
                                    row(bookmark, showsSeparator: index > 0)
                                        .id(bookmark.id)
                                }
                            }
                            .overlay {
                                if dropTarget == "box:\(group.id)" {
                                    RoundedRectangle(cornerRadius: LayoutTokens.FloatingSurface.rowCornerRadius, style: .continuous)
                                        .strokeBorder(ColorTokens.accent.opacity(LayoutTokens.InspectorList.focusRingOpacity),
                                                      lineWidth: LayoutTokens.InspectorList.focusRingWidth)
                                        .padding(.horizontal, LayoutTokens.InspectorList.boxInset)
                                        .padding(.bottom, LayoutTokens.InspectorList.boxInset)
                                        .allowsHitTesting(false)
                                }
                            }
                            .dropDestination(for: BookmarkDragItem.self) { items, _ in
                                drop(items, onFolder: group.folder, before: nil)
                            } isTargeted: { setDropTarget("box:\(group.id)", $0) }
                        }
                    }
                }
                .padding(.bottom, SpacingTokens.xs)
            }
            .focusable()
            .focused($focus, equals: .list)
            .focusEffectDisabled()
            .onKeyPress(.downArrow) { move(by: 1, in: groups, proxy: proxy) }
            .onKeyPress(.upArrow) { move(by: -1, in: groups, proxy: proxy) }
            .onKeyPress(.return) { activateSelection(in: groups) }
            .onKeyPress(.delete) {
                guard let bookmark = selectedBookmark(in: groups) else { return .ignored }
                delete(bookmark)
                return .handled
            }
            .onKeyPress(.escape) {
                guard selectedID != nil else { return .ignored }
                selectedID = nil
                return .handled
            }
            .onChange(of: scrollTarget, initial: true) { _, id in
                guard let id else { return }
                withAnimation(motion.standard) { proxy.scrollTo(id, anchor: .center) }
                scrollTarget = nil
            }
        }
    }

    /// A tab's Show in Bookmarks: clears the search and the server filter, opens the folder, and
    /// selects the bookmark.
    private func reveal(_ id: UUID) {
        appState.revealedBookmarkID = nil
        guard let bookmark = project?.bookmarks.first(where: { $0.id == id }) else { return }
        search = ""
        scopeConnectionID = nil
        unfold(bookmark.folder)
        selectedID = id
        scrollTarget = id
        focus = .list
    }

    @ViewBuilder
    private func heading(_ group: BookmarkFolderGroup) -> some View {
        if let folder = group.folder, renamingFolder == folder {
            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                TextField("Folder name", text: $folderDraft)
                    .textFieldStyle(.roundedBorder)
                    .font(TypographyTokens.detail.weight(.semibold))
                    .focused($focus, equals: .folderName)
                    .onSubmit { commitFolderRename() }
                    .onExitCommand { cancelFolderRename() }
                if let folderError {
                    Text(folderError)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Status.error)
                }
            }
            .padding(.leading, LayoutTokens.InspectorList.headingLeading - SpacingTokens.xxs)
            .padding(.trailing, LayoutTokens.InspectorList.headingTrailing)
            .padding(.vertical, SpacingTokens.xxs)
        } else {
            let base = InspectorGroupHeading(title: group.title, count: group.bookmarks.count,
                                             isFolded: isFolded(group), onToggle: { toggleFold(group) },
                                             onDoubleClick: group.folder.map { folder in { startFolderRename(folder) } })
                .overlay(alignment: .top) {
                    // A folder dropped here lands before this one; a bookmark goes into it.
                    if dropTarget == headingDropKey(for: group) {
                        Rectangle()
                            .fill(ColorTokens.accent)
                            .frame(height: LayoutTokens.InspectorList.focusRingWidth)
                            .padding(.horizontal, LayoutTokens.InspectorList.boxInset)
                    }
                }
                .contextMenu { folderMenu(group.folder) }
                .dropDestination(for: BookmarkDragItem.self) { items, _ in
                    drop(items, onFolder: group.folder, before: nil, headingOf: group.folder)
                } isTargeted: { isTargeted in
                    setDropTarget(headingDropKey(for: group), isTargeted)
                }
            if let folder = group.folder {
                base
                    .draggable(BookmarkDragItem.folder(folder)) {
                        Label(folder, systemImage: "folder").padding(SpacingTokens.xxs2)
                    }
            } else {
                base
            }
        }
    }

    private func row(_ bookmark: Bookmark, showsSeparator: Bool) -> some View {
        let server = serverInfo(for: bookmark)
        let isSelected = selectedID == bookmark.id
        return InspectorListRow(isSelected: isSelected, showsSeparator: showsSeparator,
                                quickOpen: server.isKnown && renamingBookmarkID != bookmark.id
                                    ? (title: server.isConnected ? "Open in New Tab" : "Connect and Open",
                                       action: { environmentState.openBookmark(bookmark) })
                                    : nil) {
            glyph(for: bookmark)
        } title: {
            if renamingBookmarkID == bookmark.id {
                TextField("Name", text: $titleDraft)
                    .textFieldStyle(.roundedBorder)
                    .font(TypographyTokens.standard)
                    .focused($focus, equals: .bookmarkTitle)
                    .onSubmit { commitBookmarkRename(bookmark) }
                    .onExitCommand { renamingBookmarkID = nil }
            } else {
                Text(bookmark.primaryLine)
                    .font(TypographyTokens.standard)
                    .foregroundStyle(ColorTokens.Text.primary)
            }
        } trailing: {
            HStack(spacing: SpacingTokens.xxs) {
                if bookmark.note?.isEmpty == false {
                    Image(systemName: "note.text").help(bookmark.note ?? "")
                }
                Text(InspectorListFormat.shortDay(bookmark.lastOpenedAt ?? bookmark.updatedAt ?? bookmark.createdAt))
            }
        } detail: {
            InspectorRowDetail(serverColor: server.color, isConnected: server.isConnected,
                               text: Text([server.name, bookmark.databaseName].compactMap { $0 }.joined(separator: " · ")))
        } opened: {
            opened(bookmark, server: server)
        }
        .onTapGesture(count: 2) { environmentState.openBookmark(bookmark) }
        .onTapGesture {
            focus = .list
            #if os(macOS)
            if NSEvent.modifierFlags.contains(.option) {
                selectedID = bookmark.id
                insert(bookmark)
                return
            }
            #endif
            selectedID = isSelected ? nil : bookmark.id
        }
        .contextMenu { bookmarkMenu(bookmark, server: server) }
        // An opened row isn't draggable, so its SQL can be selected.
        .modifier(BookmarkRowDrag(item: isSelected ? nil : .bookmark(bookmark), title: bookmark.primaryLine))
        .dropDestination(for: BookmarkDragItem.self) { items, _ in
            drop(items, onFolder: bookmark.folder, before: bookmark.id)
        } isTargeted: { setDropTarget("row:\(bookmark.id)", $0) }
        .overlay(alignment: .top) {
            if dropTarget == "row:\(bookmark.id)" {
                Rectangle().fill(ColorTokens.accent).frame(height: LayoutTokens.InspectorList.focusRingWidth)
            }
        }
    }

    @ViewBuilder
    private func opened(_ bookmark: Bookmark, server: ServerInfo) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
            InspectorSQLText(sql: bookmark.query)
            if let note = bookmark.note, !note.isEmpty {
                InspectorOpenedNote(text: note, systemImage: "note.text")
            }
            if !server.isConnected, let name = server.name {
                InspectorOpenedNote(text: "\(name) isn’t connected.")
            }
            InspectorRowActions {
                Button(server.isConnected ? "Open" : "Connect and Open") { environmentState.openBookmark(bookmark) }
                    .buttonStyle(.borderedProminent)
                    .disabled(!server.isKnown)
                Button("Insert") { insert(bookmark) }
                    .disabled(!environmentState.canInsertIntoActiveEditor)
                    .help("Insert at the cursor (⌥↩)")
                Button("Copy") { copyToGeneralPasteboard(bookmark.query) }
                Menu {
                    bookmarkMenuItems(bookmark, server: server, includeOpen: false)
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuIndicator(.hidden)
                .fixedSize()
                .help("More")
            }
        }
    }

    @ViewBuilder
    private func bookmarkMenu(_ bookmark: Bookmark, server: ServerInfo) -> some View {
        bookmarkMenuItems(bookmark, server: server, includeOpen: true)
    }

    @ViewBuilder
    private func bookmarkMenuItems(_ bookmark: Bookmark, server: ServerInfo, includeOpen: Bool) -> some View {
        if includeOpen {
            Button(server.isConnected ? "Open in New Tab" : "Connect and Open", systemImage: "arrow.up.right.square") {
                environmentState.openBookmark(bookmark)
            }
            .disabled(!server.isKnown)
            Button("Insert at Cursor", systemImage: "text.insert") { insert(bookmark) }
                .disabled(!environmentState.canInsertIntoActiveEditor)
            Divider()
        }
        Button("Rename", systemImage: "character.cursor.ibeam") { startBookmarkRename(bookmark) }
        Button("Edit Note…", systemImage: "note.text") {
            noteDraft = bookmark.note ?? ""
            noteBookmark = bookmark
        }
        Menu("Move to Folder") {
            Button(BookmarkRepository.noFolderTitle) { move(bookmark, to: nil) }
                .disabled(bookmark.folder == nil)
            Divider()
            ForEach(project?.bookmarkFolders ?? [], id: \.self) { folder in
                Button(folder) { move(bookmark, to: folder) }
                    .disabled(bookmark.folder == folder)
            }
            Divider()
            Button("New Folder…") { moveToNewFolder(bookmark) }
        }
        Divider()
        Button("Copy SQL", systemImage: "doc.on.doc") { copyToGeneralPasteboard(bookmark.query) }
        Button("Duplicate", systemImage: "plus.square.on.square") { duplicate(bookmark) }
        Divider()
        Button("Delete Bookmark", systemImage: "trash", role: .destructive) { delete(bookmark) }
    }

    @ViewBuilder
    private func folderMenu(_ folder: String?) -> some View {
        if let folder {
            Button("Rename Folder", systemImage: "character.cursor.ibeam") { startFolderRename(folder) }
        }
        Button("New Folder", systemImage: "folder.badge.plus") { newFolder() }
        Button("Sort Folders by Name", systemImage: "arrow.up.arrow.down") {
            environmentState.editBookmarks("Sort Folders", undoManager: undoManager) { repository.sortFoldersByName(in: &$0) }
        }
        if let folder {
            Divider()
            Button("Delete Folder…", systemImage: "trash", role: .destructive) { requestFolderDeletion(folder) }
        }
    }

    private var menu: some View {
        Menu {
            Section("Show") {
                Picker("Show", selection: $scopeConnectionID) {
                    Text("All Servers").tag(UUID?.none)
                    if let front = frontConnection {
                        Text("\(front.name) Only").tag(UUID?.some(front.id))
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            Section("Sort Once By") {
                Button("Name") { sortOnce(.name) }
                Button("Last Used") { sortOnce(.lastUsed) }
                Button("Date Added") { sortOnce(.dateAdded) }
            }
            Divider()
            Button("Sort Folders by Name") {
                environmentState.editBookmarks("Sort Folders", undoManager: undoManager) { repository.sortFoldersByName(in: &$0) }
            }
        } label: {
            Label("Show and sort", systemImage: "ellipsis.circle")
        }
        .help("Show and sort")
    }

    // MARK: - Pieces

    private func glyph(for bookmark: Bookmark) -> some View {
        let kind = bookmark.statementKind
        return Image(systemName: kind.systemImage)
            .foregroundStyle(kind == .change ? ColorTokens.Status.warning : ColorTokens.Text.secondary)
            .help(kind == .change ? "Changes data" : kind == .procedure ? "Runs a procedure" : "Reads data")
    }

    private var emptyState: some View {
        Group {
            if project == nil {
                InspectorEmptyState(systemImage: "bookmark", title: "No Project", message: "Choose a project to see its bookmarks.")
            } else if !search.isEmpty || scopeConnectionID != nil {
                InspectorEmptyState(systemImage: "magnifyingglass",
                                    title: search.isEmpty ? "No Bookmarks Here" : "No Results for “\(search)”",
                                    message: scopeConnectionID != nil ? "Only \(scopeName ?? "one server") is searched." : "Try another name, server or database.") {
                    if scopeConnectionID != nil {
                        Button("Search All Servers") { scopeConnectionID = nil }
                    }
                }
            } else {
                InspectorEmptyState(systemImage: "bookmark", title: "No Bookmarks",
                                    message: "Press ⌘S in a query tab to keep its SQL here.")
            }
        }
    }

    private var summary: String {
        guard let project else { return "No bookmarks" }
        let count = project.bookmarks.count
        let folders = project.bookmarkFolders.count
        if count == 0 && folders == 0 { return "No bookmarks" }
        let bookmarks = "\(count) \(count == 1 ? "bookmark" : "bookmarks")"
        return folders == 0 ? bookmarks : "\(bookmarks) in \(folders) \(folders == 1 ? "folder" : "folders")"
    }

    // MARK: - Data

    private struct ServerInfo {
        let name: String?
        let color: Color
        let isConnected: Bool
        let isKnown: Bool
    }

    private func serverInfo(for bookmark: Bookmark) -> ServerInfo {
        let saved = connectionStore.connections.first { $0.id == bookmark.connectionID }
        let isConnected = environmentState.sessionGroup.activeSessions.contains { $0.connection.id == bookmark.connectionID }
        let name = saved.map { $0.connectionName.isEmpty ? $0.host : $0.connectionName }
        return ServerInfo(name: name, color: saved?.color ?? ColorTokens.Text.tertiary, isConnected: isConnected, isKnown: saved != nil)
    }

    private var frontConnection: (id: UUID, name: String)? {
        guard let connection = environmentState.tabStore.activeTab?.connection else { return nil }
        return (connection.id, connection.connectionName.isEmpty ? connection.host : connection.connectionName)
    }

    private var scopeName: String? {
        guard let scopeConnectionID else { return nil }
        let connection = connectionStore.connections.first { $0.id == scopeConnectionID }
        return connection.map { $0.connectionName.isEmpty ? $0.host : $0.connectionName } ?? "One server"
    }

    private func folderGroups() -> [BookmarkFolderGroup] {
        guard let project else { return [] }
        let term = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let isFiltering = !term.isEmpty || scopeConnectionID != nil
        let names = Dictionary(connectionStore.connections.map { ($0.id, $0.connectionName.isEmpty ? $0.host : $0.connectionName) },
                               uniquingKeysWith: { first, _ in first })
        let folders: [String?] = project.bookmarkFolders.map { Optional($0) } + [nil]
        return folders.compactMap { folder in
            let shown = repository.bookmarks(inFolder: folder, of: project).filter { bookmark in
                if let scopeConnectionID, bookmark.connectionID != scopeConnectionID { return false }
                guard !term.isEmpty else { return true }
                return [bookmark.primaryLine, bookmark.query, bookmark.databaseName ?? "", bookmark.note ?? "",
                        folder ?? "", names[bookmark.connectionID] ?? ""]
                    .contains { $0.localizedCaseInsensitiveContains(term) }
            }
            // Empty folders show (so you can drag into them) unless a search or filter is on;
            // No Folder shows only when it holds something.
            if shown.isEmpty && (isFiltering || folder == nil) { return nil }
            return BookmarkFolderGroup(folder: folder, bookmarks: shown)
        }
    }

    private var foldedFolders: Set<String> {
        Set(foldedStorage.split(separator: "\n").map(String.init))
    }

    private func isFolded(_ group: BookmarkFolderGroup) -> Bool {
        search.isEmpty && foldedFolders.contains(group.id)
    }

    private func toggleFold(_ group: BookmarkFolderGroup) {
        var folded = foldedFolders
        if folded.contains(group.id) { folded.remove(group.id) } else { folded.insert(group.id) }
        foldedStorage = folded.sorted().joined(separator: "\n")
    }

    private func unfold(_ folder: String?) {
        var folded = foldedFolders
        folded.remove(folder ?? BookmarkRepository.noFolderTitle)
        foldedStorage = folded.sorted().joined(separator: "\n")
    }

    // MARK: - Folders

    private func newFolder() {
        guard let project else { return }
        let name = repository.uniqueFolderName(in: project)
        environmentState.editBookmarks("New Folder", undoManager: undoManager) { repository.addFolder(name, to: &$0) }
        search = ""
        scopeConnectionID = nil
        startFolderRename(name)
    }

    private func startFolderRename(_ folder: String) {
        folderDraft = folder
        folderError = nil
        renamingFolder = folder
        focus = .folderName
    }

    private func commitFolderRename() {
        guard let old = renamingFolder, let project else { return }
        let new = folderDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if new.isEmpty || new == old {
            cancelFolderRename()
            return
        }
        guard repository.isFree(new, in: project) else {
            folderError = "There’s already a folder called “\(new)”."
            return
        }
        environmentState.editBookmarks("Rename Folder", undoManager: undoManager) { repository.renameFolder(old, to: new, in: &$0) }
        if foldedFolders.contains(old) {
            var folded = foldedFolders
            folded.remove(old)
            folded.insert(new)
            foldedStorage = folded.sorted().joined(separator: "\n")
        }
        renamingFolder = nil
        folderError = nil
        focus = .list
    }

    private func cancelFolderRename() {
        renamingFolder = nil
        folderError = nil
        focus = .list
    }

    private func requestFolderDeletion(_ folder: String) {
        guard let project else { return }
        let count = project.bookmarks.filter { $0.folder == folder }.count
        if count == 0 {
            deleteFolder(folder, .deleteBookmarks)
        } else {
            deletion = FolderDeletionRequest(name: folder, count: count)
        }
    }

    private func deleteFolder(_ folder: String, _ deletion: BookmarkRepository.FolderDeletion) {
        environmentState.editBookmarks("Delete Folder", undoManager: undoManager) { repository.deleteFolder(folder, deletion, in: &$0) }
        if case .keepBookmarks(let destination) = deletion { unfold(destination) }
    }

    private func sortOnce(_ key: BookmarkRepository.SortKey) {
        environmentState.editBookmarks("Sort Bookmarks", undoManager: undoManager) { repository.sortOnce(by: key, in: &$0) }
    }

    // MARK: - Bookmarks

    private func insert(_ bookmark: Bookmark) {
        guard environmentState.canInsertIntoActiveEditor else { return }
        environmentState.insertIntoActiveEditor(bookmark.query)
    }

    private func move(_ bookmark: Bookmark, to folder: String?) {
        environmentState.editBookmarks("Move Bookmark", undoManager: undoManager) {
            repository.moveBookmark(bookmark.id, toFolder: folder, in: &$0)
        }
        unfold(folder)
    }

    private func moveToNewFolder(_ bookmark: Bookmark) {
        guard let project else { return }
        let name = repository.uniqueFolderName(in: project)
        environmentState.editBookmarks("Move to New Folder", undoManager: undoManager) {
            repository.addFolder(name, to: &$0)
            repository.moveBookmark(bookmark.id, toFolder: name, in: &$0)
        }
        startFolderRename(name)
    }

    private func duplicate(_ bookmark: Bookmark) {
        environmentState.editBookmarks("Duplicate Bookmark", undoManager: undoManager) { project in
            var copy = bookmark
            copy.id = UUID()
            copy.title = "\(bookmark.primaryLine) copy"
            copy.createdAt = Date()
            copy.updatedAt = nil
            copy.lastOpenedAt = nil
            project.bookmarks.append(copy)
            let order = repository.bookmarks(inFolder: bookmark.folder, of: project).map(\.id).filter { $0 != copy.id }
            let next = order.firstIndex(of: bookmark.id).flatMap { order.indices.contains($0 + 1) ? order[$0 + 1] : nil }
            repository.moveBookmark(copy.id, toFolder: bookmark.folder, before: next, in: &project)
        }
    }

    private func delete(_ bookmark: Bookmark) {
        environmentState.editBookmarks("Delete Bookmark", undoManager: undoManager) {
            repository.removeBookmark(bookmark.id, from: &$0)
        }
        if selectedID == bookmark.id { selectedID = nil }
    }

    private func startBookmarkRename(_ bookmark: Bookmark) {
        titleDraft = bookmark.primaryLine
        selectedID = bookmark.id
        renamingBookmarkID = bookmark.id
        focus = .bookmarkTitle
    }

    private func commitBookmarkRename(_ bookmark: Bookmark) {
        let title = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        environmentState.editBookmark(bookmark.id, actionName: "Rename Bookmark", undoManager: undoManager) {
            $0.title = title.isEmpty ? nil : title
            $0.updatedAt = Date()
        }
        renamingBookmarkID = nil
        focus = .list
    }

    private func saveNote() {
        guard let bookmark = noteBookmark else { return }
        let note = noteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        environmentState.editBookmark(bookmark.id, actionName: "Edit Note", undoManager: undoManager) {
            $0.note = note.isEmpty ? nil : note
        }
        noteBookmark = nil
    }

    // MARK: - Drag and drop

    private func headingDropKey(for group: BookmarkFolderGroup) -> String {
        // A folder dropped on a heading lands before it; a bookmark goes into that folder.
        "heading:\(group.id)"
    }

    private func setDropTarget(_ key: String, _ isTargeted: Bool) {
        if isTargeted {
            dropTarget = key
        } else if dropTarget == key {
            dropTarget = nil
        }
    }

    /// A drop on a folder's box or heading, or on a bookmark (before it).
    private func drop(_ items: [BookmarkDragItem], onFolder folder: String?, before targetID: UUID?, headingOf heading: String?? = nil) -> Bool {
        dropTarget = nil
        guard let item = items.first else { return false }
        switch item.kind {
        case .folder:
            // Folders reorder by their headings only.
            guard let moved = item.folder, case .some(let target) = heading, moved != target else { return false }
            environmentState.editBookmarks("Move Folder", undoManager: undoManager) {
                repository.moveFolder(moved, before: target, in: &$0)
            }
            return true
        case .bookmark:
            guard let id = item.bookmarkID, id != targetID else { return false }
            environmentState.editBookmarks("Move Bookmark", undoManager: undoManager) {
                repository.moveBookmark(id, toFolder: folder, before: targetID, in: &$0)
            }
            unfold(folder)
            return true
        }
    }

    // MARK: - Keys

    private func flat(_ groups: [BookmarkFolderGroup]) -> [Bookmark] {
        groups.filter { !isFolded($0) }.flatMap(\.bookmarks)
    }

    private func selectedBookmark(in groups: [BookmarkFolderGroup]) -> Bookmark? {
        flat(groups).first { $0.id == selectedID }
    }

    private func move(by step: Int, in groups: [BookmarkFolderGroup], proxy: ScrollViewProxy) -> KeyPress.Result {
        #if os(macOS)
        if NSEvent.modifierFlags.contains([.command, .option]), let bookmark = selectedBookmark(in: groups) {
            environmentState.editBookmarks("Move Bookmark", undoManager: undoManager) {
                repository.moveBookmark(bookmark.id, by: step, in: &$0)
            }
            return .handled
        }
        #endif
        let rows = flat(groups)
        guard !rows.isEmpty else { return .ignored }
        let current = rows.firstIndex { $0.id == selectedID }
        let next = current.map { min(max($0 + step, 0), rows.count - 1) } ?? (step > 0 ? 0 : rows.count - 1)
        selectedID = rows[next].id
        proxy.scrollTo(rows[next].id)
        return .handled
    }

    private func activateSelection(in groups: [BookmarkFolderGroup]) -> KeyPress.Result {
        guard let bookmark = selectedBookmark(in: groups) else { return .ignored }
        #if os(macOS)
        if NSEvent.modifierFlags.contains(.option) {
            insert(bookmark)
            return .handled
        }
        #endif
        environmentState.openBookmark(bookmark)
        return .handled
    }
}

/// Makes a row draggable (to another folder, or into the editor as SQL) when it carries an item.
private struct BookmarkRowDrag: ViewModifier {
    let item: BookmarkDragItem?
    let title: String

    func body(content: Content) -> some View {
        if let item {
            content.draggable(item) {
                Label(title, systemImage: "bookmark").padding(SpacingTokens.xxs2)
            }
        } else {
            content
        }
    }
}

/// One folder of the Bookmarks page (nil is No Folder).
struct BookmarkFolderGroup: Identifiable {
    let folder: String?
    var bookmarks: [Bookmark]
    var id: String { folder ?? BookmarkRepository.noFolderTitle }
    var title: String { folder ?? BookmarkRepository.noFolderTitle }
}

struct FolderDeletionRequest: Identifiable {
    let name: String
    let count: Int
    var id: String { name }
}

/// Deleting a folder that holds bookmarks (round IC): keep them in another folder (No Folder by
/// default), or delete them with it. Both can be undone.
struct FolderDeletionSheet: View {
    let request: FolderDeletionRequest
    let otherFolders: [String]
    let onKeep: (String?) -> Void
    let onDeleteAll: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var destination = BookmarkRepository.noFolderTitle

    private var plural: Bool { request.count != 1 }

    var body: some View {
        VStack(spacing: SpacingTokens.sm) {
            Image(systemName: "folder")
                .font(TypographyTokens.title2)
                .foregroundStyle(ColorTokens.Text.secondary)
            Text("Delete the folder “\(request.name)”?")
                .font(TypographyTokens.headline)
                .multilineTextAlignment(.center)
            Text("It holds \(request.count) \(plural ? "bookmarks" : "bookmark"). Keep \(plural ? "them" : "it") in another folder, or delete \(plural ? "them" : "it") with the folder.")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Picker("Move to", selection: $destination) {
                Text(BookmarkRepository.noFolderTitle).tag(BookmarkRepository.noFolderTitle)
                ForEach(otherFolders, id: \.self) { Text($0).tag($0) }
            }
            .fixedSize()
            VStack(spacing: SpacingTokens.xxs2) {
                Button {
                    onKeep(destination == BookmarkRepository.noFolderTitle ? nil : destination)
                    dismiss()
                } label: {
                    Text("Delete Folder, Keep Bookmarks").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                Button(role: .destructive) {
                    onDeleteAll()
                    dismiss()
                } label: {
                    Text("Delete Folder and \(request.count) \(plural ? "Bookmarks" : "Bookmark")").frame(maxWidth: .infinity)
                }
                Button(role: .cancel) {
                    dismiss()
                } label: {
                    Text("Cancel").frame(maxWidth: .infinity)
                }
                .keyboardShortcut(.cancelAction)
            }
            .controlSize(.large)
        }
        .padding(SpacingTokens.md2)
        .frame(width: LayoutTokens.InspectorList.deletionSheetWidth)
    }
}

extension LayoutTokens.InspectorList {
    static let deletionSheetWidth: CGFloat = 300
}
