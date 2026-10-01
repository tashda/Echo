import AppKit
import UniformTypeIdentifiers

/// Asking before a query tab's unsaved changes are lost (owner, 2026-10-01): a standard alert with
/// Save (to a bookmark: the tab's own, or a new one), Save As (a .sql file), Don't Save and Cancel.
/// Closing several tabs at once asks once: Review Each, Close Without Saving, Cancel.
extension EnvironmentState {
    enum UnsavedChoice: Equatable { case save, saveAs, dontSave, cancel }
    enum SeveralUnsavedChoice: Equatable { case reviewEach, closeWithoutSaving, cancel }

    /// Tabs whose unsaved changes were dealt with, so their close goes ahead without asking again.
    @MainActor private static var confirmedUnsavedCloses: Set<UUID> = []

    func hasUnsavedChanges(_ tab: WorkspaceTab) -> Bool {
        tab.query?.hasUnsavedChanges ?? false
    }

    /// The tab store's close check: holds back a tab with unsaved changes, asks, and closes it once
    /// it is saved or you chose Don't Save. Returns true when it held the close back.
    func holdCloseForUnsavedChanges(_ tab: WorkspaceTab) -> Bool {
        if Self.confirmedUnsavedCloses.remove(tab.id) != nil { return false }
        guard hasUnsavedChanges(tab) else { return false }
        Task { @MainActor [weak self] in
            guard let self, await self.confirmUnsavedChanges(in: tab) else { return }
            Self.confirmedUnsavedCloses.insert(tab.id)
            self.tabStore.closeTab(id: tab.id)
        }
        return true
    }

    /// Closing several tabs: with two or more unsaved, asks once and runs `close` when allowed.
    /// With one or none, returns false and each tab's own check asks.
    func holdSeveralClosesForUnsavedChanges(_ tabs: [WorkspaceTab], close: @escaping @MainActor () -> Void) -> Bool {
        let unsaved = tabs.filter { hasUnsavedChanges($0) && !Self.confirmedUnsavedCloses.contains($0.id) }
        guard unsaved.count > 1 else { return false }
        Task { @MainActor [weak self] in
            guard let self, await self.confirmUnsavedChanges(in: unsaved) else { return }
            Self.confirmedUnsavedCloses.formUnion(unsaved.map(\.id))
            close()
        }
        return true
    }

    /// Asks about one tab; true when it may close (saved, or Don't Save).
    func confirmUnsavedChanges(in tab: WorkspaceTab) async -> Bool {
        switch await UnsavedChangesAlert.ask(tab: tab.title, bookmark: tab.bookmarkContext?.displayName) {
        case .save: return await saveToBookmark(tab)
        case .saveAs: return await saveAsFile(tab)
        case .dontSave: return true
        case .cancel: return false
        }
    }

    /// Asks once about several tabs; Review Each brings each to the front and asks about it.
    func confirmUnsavedChanges(in tabs: [WorkspaceTab]) async -> Bool {
        switch await UnsavedChangesAlert.askForSeveral(tabs.map(\.title)) {
        case .cancel:
            return false
        case .closeWithoutSaving:
            return true
        case .reviewEach:
            for tab in tabs {
                tabStore.activeTabId = tab.id
                guard await confirmUnsavedChanges(in: tab) else { return false }
            }
            return true
        }
    }

    // MARK: - Saving

    /// Save: back to the tab's bookmark, or a new bookmark named after the tab.
    @discardableResult
    func saveToBookmark(_ tab: WorkspaceTab) async -> Bool {
        guard let query = tab.query else { return false }
        let connection = tab.connection
        guard var project = projectStore.projects.first(where: { $0.id == (connection.projectID ?? projectStore.selectedProject?.id) }) else {
            return false
        }
        let sql = query.sql
        if let context = tab.bookmarkContext {
            bookmarkRepository.updateBookmark(context.bookmarkID, in: &project) { $0.query = sql }
        } else {
            let bookmark = Bookmark(connectionID: connection.id, databaseName: tab.activeDatabaseName ?? connection.database,
                                    title: tab.title, query: sql, source: .tab)
            bookmarkRepository.addBookmark(bookmark, to: &project)
            tab.bookmarkContext = WorkspaceTab.BookmarkTabContext(bookmark: bookmark)
        }
        await projectStore.saveProject(project)
        query.markSaved()
        return true
    }

    /// Save As: a .sql file you choose; the tab takes the file's name.
    @discardableResult
    func saveAsFile(_ tab: WorkspaceTab) async -> Bool {
        guard let query = tab.query else { return false }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "sql") ?? .plainText]
        panel.nameFieldStringValue = "\(tab.title).sql"
        panel.canCreateDirectories = true
        let response: NSApplication.ModalResponse
        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            response = await panel.beginSheetModal(for: window)
        } else {
            response = panel.runModal()
        }
        guard response == .OK, let url = panel.url else { return false }
        do {
            try query.sql.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            _ = await WindowAlert.present(title: "\(tab.title) was not saved", message: error.localizedDescription, buttons: [.init(title: "OK")])
            return false
        }
        tab.title = url.deletingPathExtension().lastPathComponent
        query.markSaved()
        return true
    }
}

/// The alerts' words.
@MainActor
enum UnsavedChangesAlert {
    static func ask(tab: String, bookmark: String?) async -> EnvironmentState.UnsavedChoice {
        let choices: [(WindowAlert.Button, EnvironmentState.UnsavedChoice)] = [
            (.init(title: "Save"), .save),
            (.init(title: "Save As"), .saveAs),
            (.init(title: "Don't Save", isDestructive: true), .dontSave),
            (.init(title: "Cancel"), .cancel),
        ]
        let index = await WindowAlert.present(title: texts(tab: tab, bookmark: bookmark).title,
                                              message: texts(tab: tab, bookmark: bookmark).message,
                                              buttons: choices.map(\.0))
        return choices[index].1
    }

    static func askForSeveral(_ tabs: [String]) async -> EnvironmentState.SeveralUnsavedChoice {
        let choices: [(WindowAlert.Button, EnvironmentState.SeveralUnsavedChoice)] = [
            (.init(title: "Review Each"), .reviewEach),
            (.init(title: "Close Without Saving", isDestructive: true), .closeWithoutSaving),
            (.init(title: "Cancel"), .cancel),
        ]
        let text = severalTexts(tabs)
        let index = await WindowAlert.present(title: text.title, message: text.message, buttons: choices.map(\.0))
        return choices[index].1
    }

    static func texts(tab: String, bookmark: String?) -> (title: String, message: String) {
        let save = bookmark.map { "Save updates the bookmark \u{201C}\($0)\u{201D}" } ?? "Save keeps it as a bookmark in the project"
        return ("Do you want to save the changes to \u{201C}\(tab)\u{201D}?",
                "Your changes will be lost if you don't save them. \(save); Save As writes a .sql file.")
    }

    static func severalTexts(_ tabs: [String]) -> (title: String, message: String) {
        ("\(tabs.count) tabs have unsaved changes",
         tabs.joined(separator: "\n") + "\n\nReview Each goes to each tab so you can save it.")
    }
}
