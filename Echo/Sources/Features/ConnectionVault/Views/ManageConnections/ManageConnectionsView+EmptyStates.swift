import SwiftUI

// MARK: - ManageConnectionsView Empty States

extension ManageConnectionsView {

    @ViewBuilder
    func emptyState(for section: ManageSection) -> some View {
        let isInFolder = activeFolderID(for: section) != nil

        if isInFolder {
            folderEmptyState(for: section)
        } else {
            globalEmptyState(for: section)
        }
    }

    /// Empty state for a folder -- offers to move unassigned items into it,
    /// or create a new one if none are unassigned.
    @ViewBuilder
    private func folderEmptyState(for section: ManageSection) -> some View {
        ContentUnavailableView {
            Label(
                section == .connections ? "No Connections" : "No Identities",
                systemImage: section == .connections ? "externaldrive" : "person.crop.circle"
            )
        } description: {
            Text("This folder is empty.")
        } actions: {
            emptyFolderActionMenu(for: section)
        }
    }

    /// Empty state when the project has no items at all for this section.
    @ViewBuilder
    private func globalEmptyState(for section: ManageSection) -> some View {
        ContentUnavailableView {
            Label(section.emptyTitle, systemImage: section == .connections
                  ? "externaldrive"
                  : "person.crop.circle")
        } description: {
            Text(section.emptyMessage)
        } actions: {
            Button {
                handlePrimaryAdd(for: section)
            } label: {
                Text(section.emptyActionTitle)
            }
        }
    }

    /// Menu button for empty folders: lists unassigned items that can be moved
    /// into this folder, with a "New..." option at the bottom. If no unassigned
    /// items exist, tapping creates a new item directly.
    @ViewBuilder
    private func emptyFolderActionMenu(for section: ManageSection) -> some View {
        let folderID = activeFolderID(for: section)

        switch section {
        case .connections:
            let unassigned = projectConnections.filter { $0.folderID == nil }

            if unassigned.isEmpty {
                Button {
                    createNewConnection()
                } label: {
                    Text("New Connection")
                }
            } else {
                Menu("Add to Folder") {
                    ForEach(unassigned) { connection in
                        Button {
                            if let folderID, let folder = folder(withID: folderID) {
                                moveConnectionToFolder(connection, folder)
                            }
                        } label: {
                            Text(connection.connectionName)
                        }
                    }
                    Divider()
                    Button {
                        createNewConnection()
                    } label: {
                        Label("New Connection", systemImage: "plus")
                    }
                }
            }

        case .identities:
            let unassigned = projectIdentities.filter { $0.folderID == nil }

            if unassigned.isEmpty {
                Button {
                    createNewIdentity()
                } label: {
                    Text("New Identity")
                }
            } else {
                Menu("Add to Folder") {
                    ForEach(unassigned) { identity in
                        Button {
                            if let folderID, let folder = folder(withID: folderID) {
                                moveIdentityToFolder(identity, folder)
                            }
                        } label: {
                            Text(identity.name)
                        }
                    }
                    Divider()
                    Button {
                        createNewIdentity()
                    } label: {
                        Label("New Identity", systemImage: "plus")
                    }
                }
            }
        case .projects:
            Button {
                isPresentingNewProjectSheet = true
            } label: {
                Text("New Project")
            }
        }
    }
}
