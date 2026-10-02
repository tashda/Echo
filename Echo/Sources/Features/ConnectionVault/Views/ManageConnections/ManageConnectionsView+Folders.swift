import SwiftUI

/// Round MC, round 2: folders organise connections and identities (FS1 + FS2, IF2). The sidebar
/// lists them like mailboxes; the list and table group what a scope shows by folder. A folder
/// never holds a login: a connection signs in with its own password or an identity.
extension ManageConnectionsView {
    /// A folder and its subfolders, for the sidebar's outline.
    struct FolderNode: Identifiable {
        let folder: SavedFolder
        let children: [FolderNode]?
        var id: UUID { folder.id }
    }

    func folderTree(_ kind: FolderKind, parentID: UUID? = nil) -> [FolderNode] {
        connectionStore.folders(kind: kind, projectID: selectedProjectID, parentID: parentID).map { folder in
            let children = folderTree(kind, parentID: folder.id)
            return FolderNode(folder: folder, children: children.isEmpty ? nil : children)
        }
    }

    /// Every folder under `parentID`, depth first, with its depth, for menus and grouping.
    func flatFolders(_ kind: FolderKind, parentID: UUID? = nil, depth: Int = 0) -> [(folder: SavedFolder, depth: Int)] {
        connectionStore.folders(kind: kind, projectID: selectedProjectID, parentID: parentID).flatMap { folder in
            [(folder: folder, depth: depth)] + flatFolders(kind, parentID: folder.id, depth: depth + 1)
        }
    }

    /// The folder the sidebar shows, if it shows one.
    var currentFolderID: UUID? { activeScope.folderID }

    /// The kind of folder New Folder makes from here.
    var currentFolderKind: FolderKind { activeScope.isConnections ? .connections : .identities }

    var scopeTitle: String {
        if let id = currentFolderID, let folder = connectionStore.folder(id: id) { return folder.name }
        return activeScope.title
    }

    func connectionCount(inFolder folderID: UUID) -> Int {
        projectConnections.filter { connectionStore.effectiveFolderID(of: $0) == folderID }.count
    }

    func identityCount(inFolder folderID: UUID) -> Int {
        projectIdentities.filter { connectionStore.effectiveFolderID(of: $0) == folderID }.count
    }

    // MARK: Grouping (FS2 inside the scope)

    /// The groups a scope shows: the rows filed directly in it, then one group per folder inside
    /// it (depth first), titled with the path from the scope. Empty groups are left out.
    func groups<Item: Identifiable>(
        of items: [Item],
        kind: FolderKind,
        under rootID: UUID?,
        folderOf: (Item) -> UUID?
    ) -> [ManageGroup<Item>] where Item.ID == UUID {
        var byFolder: [UUID?: [Item]] = [:]
        for item in items { byFolder[folderOf(item), default: []].append(item) }

        var result: [ManageGroup<Item>] = []
        if let loose = byFolder[rootID], !loose.isEmpty {
            result.append(ManageGroup(folder: nil, title: nil, items: loose))
        }
        var path: [String] = []
        func walk(parentID: UUID?) {
            for folder in connectionStore.folders(kind: kind, projectID: selectedProjectID, parentID: parentID) {
                path.append(folder.name)
                if let rows = byFolder[folder.id], !rows.isEmpty {
                    result.append(ManageGroup(folder: folder, title: path.joined(separator: " / "), items: rows))
                }
                walk(parentID: folder.id)
                path.removeLast()
            }
        }
        walk(parentID: rootID)
        return result
    }

    /// The connections of the current scope, grouped. Recently Used is one group in time order.
    var connectionGroups: [ManageGroup<SavedConnection>] {
        let rows = scopedConnections
        if activeScope == .recentConnections {
            return rows.isEmpty ? [] : [ManageGroup(folder: nil, title: nil, items: rows)]
        }
        return groups(of: rows, kind: .connections, under: currentFolderID) { connectionStore.effectiveFolderID(of: $0) }
    }

    var identityGroups: [ManageGroup<SavedIdentity>] {
        groups(of: scopedIdentities, kind: .identities, under: currentFolderID) { connectionStore.effectiveFolderID(of: $0) }
    }

    func isGroupExpanded(_ id: UUID) -> Binding<Bool> {
        Binding(
            get: { !collapsedGroupIDs.contains(id) },
            set: { expanded in
                if expanded { collapsedGroupIDs.remove(id) } else { collapsedGroupIDs.insert(id) }
            }
        )
    }

    // MARK: Sidebar rows

    @ViewBuilder
    func folderRows(_ kind: FolderKind) -> some View {
        let tree = folderTree(kind)
        if !tree.isEmpty {
            OutlineGroup(tree, children: \.children) { node in
                Label(node.folder.name, systemImage: node.folder.icon)
                    .badge(kind == .connections ? connectionCount(inFolder: node.folder.id) : identityCount(inFolder: node.folder.id))
                    .tag(kind == .connections ? ManageScope.folder(node.folder.id) : ManageScope.identityFolder(node.folder.id))
                    .dropDestination(for: String.self) { items, _ in
                        drop(items, kind: kind, intoFolder: node.folder.id)
                    }
                    .contextMenu { folderContextMenu(node.folder) }
            }
        }
    }

    @ViewBuilder
    private func folderContextMenu(_ folder: SavedFolder) -> some View {
        Button("New Folder Inside…") { beginNewFolder(kind: folder.kind, parentID: folder.id) }
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

    /// The Move to Folder submenu for connections or identities.
    @ViewBuilder
    func moveToFolderMenu(_ ids: Set<UUID>, kind: FolderKind) -> some View {
        let current: Set<UUID?> = kind == .connections
            ? Set(connectionStore.connections.filter { ids.contains($0.id) }.map { connectionStore.effectiveFolderID(of: $0) })
            : Set(connectionStore.identities.filter { ids.contains($0.id) }.map { connectionStore.effectiveFolderID(of: $0) })
        Menu {
            Button("No Folder") { move(ids, kind: kind, toFolder: nil) }
                .disabled(current == [nil])
            let folders = flatFolders(kind)
            if !folders.isEmpty { Divider() }
            ForEach(folders, id: \.folder.id) { entry in
                Button(String(repeating: "    ", count: entry.depth) + entry.folder.name) {
                    move(ids, kind: kind, toFolder: entry.folder.id)
                }
                .disabled(current == [entry.folder.id])
            }
            Divider()
            Button("New Folder…") { beginNewFolder(kind: kind, parentID: nil, moving: ids) }
        } label: {
            Label("Move to Folder", systemImage: "folder")
        }
    }

    func move(_ ids: Set<UUID>, kind: FolderKind, toFolder folderID: UUID?) {
        Task {
            if kind == .connections {
                await connectionStore.moveConnections(ids, toFolder: folderID)
            } else {
                await connectionStore.moveIdentities(ids, toFolder: folderID)
            }
        }
    }

    /// Rows dragged onto a folder, or onto All Connections / All Identities (no folder).
    func drop(_ items: [String], kind: FolderKind, intoFolder folderID: UUID?) -> Bool {
        let ids = Set(items.compactMap(UUID.init(uuidString:)))
        let known = Set(kind == .connections ? projectConnections.map(\.id) : projectIdentities.map(\.id))
        let moving = ids.intersection(known)
        guard !moving.isEmpty else { return false }
        move(moving, kind: kind, toFolder: folderID)
        return true
    }

    // MARK: Create, rename, delete

    func beginNewFolder(kind: FolderKind, parentID: UUID?, moving: Set<UUID> = []) {
        folderNameDraft = ""
        folderNameRequest = .create(kind: kind, parentID: parentID, moving: moving)
    }

    func commitFolderName() {
        guard let request = folderNameRequest else { return }
        let name = folderNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        folderNameRequest = nil
        guard !name.isEmpty else { return }
        Task {
            switch request {
            case .create(let kind, let parentID, let moving):
                guard let folder = try? await connectionStore.createFolder(
                    name: name, kind: kind, projectID: selectedProjectID, parentFolderID: parentID
                ) else { return }
                if !moving.isEmpty {
                    if kind == .connections {
                        await connectionStore.moveConnections(moving, toFolder: folder.id)
                    } else {
                        await connectionStore.moveIdentities(moving, toFolder: folder.id)
                    }
                }
            case .rename(let folder):
                try? await connectionStore.renameFolder(folder.id, to: name)
            }
        }
    }

    /// "Its 3 connections will move to “Production”. No connection is deleted."
    func folderDeletionMessage(_ folder: SavedFolder) -> String {
        let isConnections = folder.kind == .connections
        let count = isConnections ? connectionCount(inFolder: folder.id) : identityCount(inFolder: folder.id)
        let noun = isConnections ? "connection" : "identity"
        let nouns = isConnections ? "connections" : "identities"
        let destination = connectionStore.folder(id: folder.parentFolderID).map { "move to “\($0.name)”" } ?? "move out of folders"
        let subfolders = connectionStore.folders(kind: folder.kind, projectID: folder.projectID, parentID: folder.id).count
        var parts: [String] = []
        if count > 0 { parts.append(count == 1 ? "Its \(noun) will \(destination)." : "Its \(count) \(nouns) will \(destination).") }
        if subfolders > 0 { parts.append(subfolders == 1 ? "Its folder moves up a level." : "Its \(subfolders) folders move up a level.") }
        if parts.isEmpty { return "The folder is empty." }
        return parts.joined(separator: " ") + " Nothing else is deleted."
    }

    func deleteFolder(_ folder: SavedFolder) {
        pendingFolderDeletion = nil
        if currentFolderID == folder.id {
            apply(.scope(folder.kind == .connections ? .allConnections : .identities))
        }
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
        case .create(_, let parentID, _)?:
            view.connectionStore.folder(id: parentID).map { "New Folder in “\($0.name)”" } ?? "New Folder"
        case nil: "New Folder"
        }
    }
}
