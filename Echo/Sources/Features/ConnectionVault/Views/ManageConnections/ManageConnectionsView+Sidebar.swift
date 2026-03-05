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
                sidebarSection(
                    section,
                    nodes: section == .connections ? connectionFolderNodes : identityFolderNodes,
                    totalCount: totalCount(for: section)
                )
            }
        }
        .listStyle(.sidebar)
#if os(macOS)
        .scrollContentBackground(.hidden)
        .background(ColorTokens.Background.secondary)
#endif
    }

    @ViewBuilder
    func sidebarSection(
        _ section: ManageSection,
        nodes: [FolderNode],
        totalCount: Int
    ) -> some View {
         DisclosureGroup(isExpanded: sectionBinding(for: section)) {
            OutlineGroup(nodes, children: \.childNodes) { node in
                sidebarFolderLink(node: node, section: section)
            }
        } label: {
            NavigationLink(value: SidebarSelection.section(section)) {
                HStack(spacing: 6) {
                    Image(systemName: section.icon)
                    Text(section.title)
                }
            }
            .tag(SidebarSelection.section(section))
            .contextMenu {
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
        }
    }

    @ViewBuilder
    func sidebarFolderLink(node: FolderNode, section: ManageSection) -> some View {
        NavigationLink(value: SidebarSelection.folder(node.folder.id, section)) {
            HStack(spacing: 6) {
                Image(systemName: "folder")
                Text(node.folder.displayName)
            }
        }
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
        .dropDestination(for: String.self) { items, location in
            if section == .connections {
                return handleConnectionDrop(items: items, folder: node.folder)
            } else {
                return handleIdentityDrop(items: items, folder: node.folder)
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
                if isExpanded {
                    expandedSections.insert(section)
                } else {
                    expandedSections.remove(section)
                }
            }
        )
    }
}
