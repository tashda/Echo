import SwiftUI

/// Round MC, round 2 (FS1): connection folders in the sidebar, like mailboxes. Folders organise
/// only; a connection signs in with its own password or an identity wherever it is filed.
extension ManageConnectionsView {
    /// A folder and its subfolders, for the sidebar's outline.
    struct FolderNode: Identifiable {
        let folder: SavedFolder
        let children: [FolderNode]?
        var id: UUID { folder.id }
    }

    func folderTree(parentID: UUID? = nil) -> [FolderNode] {
        connectionStore.folders(kind: .connections, projectID: selectedProjectID, parentID: parentID).map { folder in
            let children = folderTree(parentID: folder.id)
            return FolderNode(folder: folder, children: children.isEmpty ? nil : children)
        }
    }

    /// Every folder, top level first, with its depth, for the Move to Folder menu.
    func flatFolders(parentID: UUID? = nil, depth: Int = 0) -> [(folder: SavedFolder, depth: Int)] {
        connectionStore.folders(kind: .connections, projectID: selectedProjectID, parentID: parentID).flatMap { folder in
            [(folder: folder, depth: depth)] + flatFolders(parentID: folder.id, depth: depth + 1)
        }
    }

    /// The folder the sidebar shows, if it shows one.
    var currentFolderID: UUID? {
        if case .folder(let id) = activeScope { return id }
        return nil
    }

    var scopeTitle: String {
        if let id = currentFolderID, let folder = connectionStore.folder(id: id) { return folder.name }
        return activeScope.title
    }

    func connectionCount(inFolder folderID: UUID) -> Int {
        projectConnections.filter { connectionStore.effectiveFolderID(of: $0) == folderID }.count
    }

    // MARK: Sidebar rows

    @ViewBuilder
    var folderRows: some View {
        let tree = folderTree()
        if !tree.isEmpty {
            OutlineGroup(tree, children: \.children) { node in
                Label(node.folder.name, systemImage: node.folder.icon)
                    .badge(connectionCount(inFolder: node.folder.id))
                    .tag(ManageScope.folder(node.folder.id))
                    .dropDestination(for: String.self) { items, _ in
                        dropConnections(items, intoFolder: node.folder.id)
                    }
                    .contextMenu { folderContextMenu(node.folder) }
            }
        }
    }

    @ViewBuilder
    private func folderContextMenu(_ folder: SavedFolder) -> some View {
        Button("New Folder Inside…") { beginNewFolder(parentID: folder.id) }
        Button("Rename…") {
            folderNameDraft = folder.name
            folderNameRequest = .rename(folder)
        }
        if connectionStore.folder(id: folder.parentFolderID) != nil {
            Button("Move to Top Level") {
                Task { await connectionStore.moveFolder(folder.id, toParent: nil) }
            }
        }
        Divider()
        Button("Delete Folder…", role: .destructive) { pendingFolderDeletion = folder }
    }

    // MARK: Move to Folder

    /// The connection menu's Move to Folder submenu.
    @ViewBuilder
    func moveToFolderMenu(_ ids: Set<UUID>) -> some View {
        let current = Set(connectionStore.connections.filter { ids.contains($0.id) }.map { connectionStore.effectiveFolderID(of: $0) })
        Menu {
            Button("No Folder") { Task { await connectionStore.moveConnections(ids, toFolder: nil) } }
                .disabled(current == [nil])
            let folders = flatFolders()
            if !folders.isEmpty { Divider() }
            ForEach(folders, id: \.folder.id) { entry in
                Button(String(repeating: "    ", count: entry.depth) + entry.folder.name) {
                    Task { await connectionStore.moveConnections(ids, toFolder: entry.folder.id) }
                }
                .disabled(current == [entry.folder.id])
            }
            Divider()
            Button("New Folder…") { beginNewFolder(parentID: nil, moving: ids) }
        } label: {
            Label("Move to Folder", systemImage: "folder")
        }
    }

    /// Rows dragged onto a folder (or onto All Connections, which means no folder).
    func dropConnections(_ items: [String], intoFolder folderID: UUID?) -> Bool {
        let ids = Set(items.compactMap(UUID.init(uuidString:)))
        let known = Set(projectConnections.map(\.id))
        let moving = ids.intersection(known)
        guard !moving.isEmpty else { return false }
        Task { await connectionStore.moveConnections(moving, toFolder: folderID) }
        return true
    }

    // MARK: Create, rename, delete

    func beginNewFolder(parentID: UUID?, moving: Set<UUID> = []) {
        folderNameDraft = ""
        folderNameRequest = .create(parentID: parentID, moving: moving)
    }

    func commitFolderName() {
        guard let request = folderNameRequest else { return }
        let name = folderNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        folderNameRequest = nil
        guard !name.isEmpty else { return }
        Task {
            switch request {
            case .create(let parentID, let moving):
                guard let folder = try? await connectionStore.createFolder(
                    name: name, kind: .connections, projectID: selectedProjectID, parentFolderID: parentID
                ) else { return }
                if !moving.isEmpty {
                    await connectionStore.moveConnections(moving, toFolder: folder.id)
                }
            case .rename(let folder):
                try? await connectionStore.renameFolder(folder.id, to: name)
            }
        }
    }

    /// "Its 3 connections move to Production." / "… move out of folders."
    func folderDeletionMessage(_ folder: SavedFolder) -> String {
        let count = connectionCount(inFolder: folder.id)
        let destination = connectionStore.folder(id: folder.parentFolderID).map { "move to “\($0.name)”" } ?? "move out of folders"
        let subfolders = connectionStore.folders(kind: .connections, projectID: folder.projectID, parentID: folder.id).count
        var parts: [String] = []
        if count > 0 { parts.append(count == 1 ? "Its connection will \(destination)." : "Its \(count) connections will \(destination).") }
        if subfolders > 0 { parts.append(subfolders == 1 ? "Its folder moves up a level." : "Its \(subfolders) folders move up a level.") }
        if parts.isEmpty { return "The folder is empty." }
        return parts.joined(separator: " ") + " No connection is deleted."
    }

    func deleteFolder(_ folder: SavedFolder) {
        pendingFolderDeletion = nil
        if currentFolderID == folder.id { apply(.scope(.allConnections)) }
        Task { try? await connectionStore.deleteFolder(folder, reparentContents: true) }
    }
}

/// The folder name and folder deletion alerts.
struct ManageConnectionsFolderAlerts: ViewModifier {
    let view: ManageConnectionsView

    func body(content: Content) -> some View {
        content
            .alert(
                folderAlertTitle,
                isPresented: Binding(
                    get: { view.folderNameRequest != nil },
                    set: { if !$0 { view.folderNameRequest = nil } }
                )
            ) {
                TextField("Name", text: view.$folderNameDraft)
                Button(isRename ? "Rename" : "Create") { view.commitFolderName() }
                    .keyboardShortcut(.defaultAction)
                Button("Cancel", role: .cancel) { view.folderNameRequest = nil }
            }
            .alert(
                view.pendingFolderDeletion.map { "Delete “\($0.name)”?" } ?? "Delete Folder?",
                isPresented: Binding(
                    get: { view.pendingFolderDeletion != nil },
                    set: { if !$0 { view.pendingFolderDeletion = nil } }
                ),
                presenting: view.pendingFolderDeletion
            ) { folder in
                Button("Delete Folder", role: .destructive) { view.deleteFolder(folder) }
                Button("Cancel", role: .cancel) { view.pendingFolderDeletion = nil }
            } message: { folder in
                Text(view.folderDeletionMessage(folder))
            }
    }

    private var isRename: Bool {
        if case .rename? = view.folderNameRequest { return true }
        return false
    }

    private var folderAlertTitle: String {
        switch view.folderNameRequest {
        case .rename(let folder)?: "Rename “\(folder.name)”"
        case .create(let parentID, _)?:
            view.connectionStore.folder(id: parentID).map { "New Folder in “\($0.name)”" } ?? "New Folder"
        case nil: "New Folder"
        }
    }
}
