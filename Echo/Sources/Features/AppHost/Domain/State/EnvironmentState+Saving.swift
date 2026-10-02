import AppKit
import UniformTypeIdentifiers

/// Saving queries (round IC, H1). A query tab has a home: nothing yet, a bookmark, or a .sql file.
/// Save writes to the home without asking; the first Save asks where with the Save card. Save As…,
/// Save to Bookmarks… and Save to File… always ask. Opening a bookmark or a .sql file makes it the
/// tab's home.
extension EnvironmentState {
    private static let lastDestinationKey = "saveCard.lastDestination"
    private static let lastFolderKeyPrefix = "saveCard.lastFolder."
    private static let lastDirectoryKey = "saveCard.lastDirectory"

    /// File › Save (⌘S).
    func saveTab(_ tab: WorkspaceTab) {
        if tab.bookmarkContext != nil || tab.fileURL != nil {
            Task { await saveToHome(tab) }
        } else {
            presentSaveCard(for: tab, destination: nil)
        }
    }

    /// Writes the tab to its bookmark or file; false when it has neither or writing failed.
    @discardableResult
    func saveToHome(_ tab: WorkspaceTab) async -> Bool {
        if tab.bookmarkContext != nil { return await saveToBookmark(tab) }
        if let url = tab.fileURL, let query = tab.query {
            guard await write(query.sql, to: url, tabTitle: tab.title) else { return false }
            query.markSaved()
            return true
        }
        return false
    }

    /// File › Revert to Saved: only for a tab with a home and changes since it was saved.
    func canRevertToSaved(_ tab: WorkspaceTab) -> Bool {
        (tab.bookmarkContext != nil || tab.fileURL != nil) && tab.query?.hasUnsavedChanges == true
    }

    /// File › Revert to Saved (round IC): after asking, the editor goes back to the file on disk or
    /// the bookmark as it is stored now (falling back to what was last saved from this tab).
    func revertToSaved(_ tab: WorkspaceTab) async {
        guard canRevertToSaved(tab), let query = tab.query else { return }
        let choice = await WindowAlert.present(
            title: "Revert \u{201C}\(tab.title)\u{201D} to the saved version?",
            message: "Your changes since it was last saved will be lost.",
            buttons: [.init(title: "Revert", isDestructive: true), .init(title: "Cancel")]
        )
        guard choice == 0 else { return }
        var saved = query.savedSQL
        if let url = tab.fileURL, let onDisk = try? String(contentsOf: url, encoding: .utf8) {
            saved = onDisk
        } else if let context = tab.bookmarkContext,
                  let bookmark = projectStore.projects.lazy.flatMap(\.bookmarks).first(where: { $0.id == context.bookmarkID }) {
            saved = bookmark.query
        }
        query.sql = saved
        query.errorMark = nil
        query.runNote = nil
        query.markSaved()
    }

    /// File › Save As…, Save to Bookmarks…, Save to File…: the Save card. A tab without a home takes
    /// what you pick as its home; a tab with one keeps it and the card saves a copy.
    func presentSaveCard(for tab: WorkspaceTab, destination: SaveDestination?, movesHome: Bool = false) {
        guard let query = tab.query else { return }
        let sql = query.sql
        guard !sql.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let hasHome = tab.bookmarkContext != nil || tab.fileURL != nil
        AppDirector.shared.appState.saveCardRequest = SaveCardRequest(
            origin: hasHome && !movesHome ? .statement : .tab(tab.id),
            sql: sql,
            connectionID: tab.connection.id,
            databaseName: tab.activeDatabaseName ?? tab.connection.database,
            suggestedName: tab.bookmarkContext?.displayName ?? tab.title,
            destination: destination ?? lastSaveDestination
        )
    }

    /// Add to Bookmarks from History or a selection: the Save card on Bookmarks.
    func requestBookmark(sql: String, connectionID: UUID?, database: String?, suggestedName: String?) {
        guard let connectionID else { return }
        let firstLine = sql.split(whereSeparator: \.isNewline).first.map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        AppDirector.shared.appState.saveCardRequest = SaveCardRequest(
            origin: .statement,
            sql: sql,
            connectionID: connectionID,
            databaseName: database,
            suggestedName: suggestedName ?? firstLine,
            destination: .bookmarks
        )
    }

    var lastSaveDestination: SaveDestination {
        UserDefaults.standard.string(forKey: Self.lastDestinationKey).flatMap(SaveDestination.init(rawValue:)) ?? .bookmarks
    }

    /// The folder last used for this server's bookmarks, if it still exists.
    func lastBookmarkFolder(for connectionID: UUID) -> String? {
        guard let folder = UserDefaults.standard.string(forKey: Self.lastFolderKeyPrefix + connectionID.uuidString),
              bookmarkProject?.bookmarkFolders.contains(folder) == true else { return nil }
        return folder
    }

    /// The card's Save on Bookmarks: makes the folder if it is new, adds the bookmark at its top,
    /// and, for a tab, makes the bookmark its home.
    func completeSaveToBookmarks(_ request: SaveCardRequest, name: String, folder: String?, newFolder: Bool, note: String) async {
        guard let connection = connectionStore.connections.first(where: { $0.id == request.connectionID }) else { return }
        if newFolder, let folder {
            editBookmarks("New Folder") { project in bookmarkRepository.addFolder(folder, to: &project) }
        }
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let source: Bookmark.Source = request.origin == .statement ? .savedQuery : .tab
        guard let bookmark = await addBookmark(for: connection, databaseName: request.databaseName,
                                               title: title.isEmpty ? nil : title, query: request.sql,
                                               source: source, folder: folder, note: note) else { return }
        UserDefaults.standard.set(SaveDestination.bookmarks.rawValue, forKey: Self.lastDestinationKey)
        if let folder {
            UserDefaults.standard.set(folder, forKey: Self.lastFolderKeyPrefix + connection.id.uuidString)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.lastFolderKeyPrefix + connection.id.uuidString)
        }
        if case .tab(let id) = request.origin, let tab = tabStore.tabs.first(where: { $0.id == id }) {
            tab.bookmarkContext = WorkspaceTab.BookmarkTabContext(bookmark: bookmark)
            tab.fileURL = nil
            if !title.isEmpty { tab.title = title }
            tab.query?.markSaved()
        }
    }

    /// The card's Save on File: the system save panel, at the last folder used, then the file.
    func completeSaveToFile(_ request: SaveCardRequest, name: String) async {
        let base = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let fileName = base.isEmpty ? "Query.sql" : (base.lowercased().hasSuffix(".sql") ? base : "\(base).sql")
        guard let url = await chooseSQLFileLocation(suggestedName: fileName) else { return }
        guard await write(request.sql, to: url, tabTitle: base) else { return }
        UserDefaults.standard.set(SaveDestination.file.rawValue, forKey: Self.lastDestinationKey)
        if case .tab(let id) = request.origin, let tab = tabStore.tabs.first(where: { $0.id == id }) {
            tab.fileURL = url
            tab.bookmarkContext = nil
            tab.title = url.deletingPathExtension().lastPathComponent
            tab.query?.markSaved()
        }
    }

    private func chooseSQLFileLocation(suggestedName: String) async -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "sql") ?? .plainText]
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        if let path = UserDefaults.standard.string(forKey: Self.lastDirectoryKey) {
            panel.directoryURL = URL(fileURLWithPath: path, isDirectory: true)
        }
        let response: NSApplication.ModalResponse
        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            response = await panel.beginSheetModal(for: window)
        } else {
            response = panel.runModal()
        }
        guard response == .OK, let url = panel.url else { return nil }
        UserDefaults.standard.set(url.deletingLastPathComponent().path, forKey: Self.lastDirectoryKey)
        return url
    }

    private func write(_ sql: String, to url: URL, tabTitle: String) async -> Bool {
        do {
            try sql.write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            _ = await WindowAlert.present(title: "\u{201C}\(tabTitle)\u{201D} was not saved",
                                          message: error.localizedDescription, buttons: [.init(title: "OK")])
            return false
        }
    }

    /// File › Open SQL File… (⌘O): opens a .sql file in a new query tab on the front server; the
    /// file is the tab's home.
    func openSQLFile() async {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "sql") ?? .plainText, .plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if let path = UserDefaults.standard.string(forKey: Self.lastDirectoryKey) {
            panel.directoryURL = URL(fileURLWithPath: path, isDirectory: true)
        }
        let response: NSApplication.ModalResponse
        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            response = await panel.beginSheetModal(for: window)
        } else {
            response = panel.runModal()
        }
        guard response == .OK, let url = panel.url else { return }
        let sql: String
        do {
            sql = try String(contentsOf: url, encoding: .utf8)
        } catch {
            _ = await WindowAlert.present(title: "\u{201C}\(url.lastPathComponent)\u{201D} couldn't be opened",
                                          message: error.localizedDescription, buttons: [.init(title: "OK")])
            return
        }
        guard let session = sessionGroup.activeSession ?? sessionGroup.activeSessions.first else {
            _ = await WindowAlert.present(title: "Connect to a server first",
                                          message: "A query tab needs a server. Connect to one, then open the file again.",
                                          buttons: [.init(title: "OK")])
            return
        }
        UserDefaults.standard.set(url.deletingLastPathComponent().path, forKey: Self.lastDirectoryKey)
        let before = tabStore.activeTab?.id
        openQueryTab(for: session, presetQuery: sql, autoExecute: false)
        if let tab = tabStore.activeTab, tab.id != before {
            tab.fileURL = url
            tab.title = url.deletingPathExtension().lastPathComponent
            tab.query?.markSaved()
        }
    }
}
