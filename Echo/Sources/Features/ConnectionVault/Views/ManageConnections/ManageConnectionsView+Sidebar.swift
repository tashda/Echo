import SwiftUI

extension ManageConnectionsView {
    @ViewBuilder
    var sidebar: some View {
        sidebarList
    }

    @ViewBuilder
    private var sidebarList: some View {
        List(selection: Binding(
            get: { sidebarSelection },
            set: { newValue in
                handleSidebarSelectionChange(newValue)
            }
        )) {
            ForEach(ManageSection.allCases) { section in
                Section(isExpanded: sectionBinding(for: section)) {
                    sidebarSectionContent(section)
                } header: {
                    Text(section.title)
                        .contextMenu {
                            sectionContextMenu(for: section)
                        }
                }
            }
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private func sidebarSectionContent(
        _ section: ManageSection
    ) -> some View {
        Label {
            Text("All \(section.title)")
        } icon: {
            Image(systemName: section.icon)
        }
        .tag(SidebarSelection.section(section))
        .contextMenu {
            sectionContextMenu(for: section)
        }

        let nodes = section == .connections ? connectionFolderNodes : identityFolderNodes
        OutlineGroup(nodes, children: \.childNodes) { node in
            sidebarFolderLink(node: node, section: section)
        }
    }

    @ViewBuilder
    func sidebarFolderLink(node: FolderNode, section: ManageSection) -> some View {
        Label(node.folder.displayName, systemImage: node.folder.icon)
            .tag(SidebarSelection.folder(node.folder.id, section))
            .contextMenu {
                Button {
                    createNewFolder(for: section, parent: node.folder)
                } label: {
                    Text("New Subfolder")
                }

                Button {
                    editFolder(node.folder)
                } label: {
                    Text("Edit")
                }

                Divider()

                Button("Delete", role: .destructive) {
                    handleDeletion(.folder(node.folder))
                }
            }
            .dropDestination(for: String.self) { items, _ in
                if section == .connections {
                    return handleConnectionDrop(items: items, folder: node.folder)
                } else {
                    return handleIdentityDrop(items: items, folder: node.folder)
                }
            }
    }

    @ViewBuilder
    private func sectionContextMenu(for section: ManageSection) -> some View {
        switch section {
        case .connections:
            Button {
                handlePrimaryAdd(for: .connections)
            } label: {
                Label("New Connection", systemImage: "externaldrive.badge.plus")
            }
            Button {
                presentCreateFolder(for: .connections)
            } label: {
                Label("New Folder", systemImage: "folder.badge.plus")
            }
        case .identities:
            Button {
                handlePrimaryAdd(for: .identities)
            } label: {
                Label("New Identity", systemImage: "person.crop.circle.badge.plus")
            }
            Button {
                presentCreateFolder(for: .identities)
            } label: {
                Label("New Folder", systemImage: "folder.badge.plus")
            }
        }
    }

    func totalCount(for section: ManageSection) -> Int {
        switch section {
        case .connections: return projectConnections.count
        case .identities: return projectIdentities.count
        }
    }

    func sectionBinding(for section: ManageSection) -> Binding<Bool> {
        Binding(
            get: { expandedSections.contains(section) },
            set: { isExpanded in
                withAnimation {
                    if isExpanded {
                        expandedSections.insert(section)
                    } else {
                        expandedSections.remove(section)
                    }
                }
            }
        )
    }
}
