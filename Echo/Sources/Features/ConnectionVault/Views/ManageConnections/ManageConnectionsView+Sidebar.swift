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
                        .font(TypographyTokens.caption.weight(.bold))
                        .foregroundStyle(ColorTokens.Text.secondary)
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
        Group {
            if section == .projects {
                ForEach(projectStore.projects) { project in
                    sidebarProjectLink(project: project)
                }
            } else {
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
        }
        .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity))
    }

    @ViewBuilder
    func sidebarProjectLink(project: Project) -> some View {
        HStack {
            Label {
                Text(project.name)
            } icon: {
                Image(systemName: project.iconName ?? "folder.fill")
            }

            Spacer()

            if projectStore.selectedProject?.id == project.id {
                Image(systemName: "checkmark")
                    .font(TypographyTokens.compact.weight(.bold))
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }
        .tag(SidebarSelection.project(project.id))
        .contextMenu {
            Button {
                environmentState.requestProjectSwitch(to: project)
            } label: {
                let isSelected = projectStore.selectedProject?.id == project.id
                Label("Select Project", systemImage: isSelected ? "checkmark" : "circle")
            }

            Divider()

            Button {
                exportProjectID = project.id
                showExportSheet = true
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }

            if !project.isDefault {
                Divider()

                Button(role: .destructive) {
                    projectToDelete = project
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
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
                    Label("New Subfolder", systemImage: "folder.badge.plus")
                }

                Button {
                    editFolder(node.folder)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Divider()

                Button(role: .destructive) {
                    handleDeletion(.folder(node.folder))
                } label: {
                    Label("Delete", systemImage: "trash")
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
        case .projects:
            Button {
                isPresentingNewProjectSheet = true
            } label: {
                Label("New Project", systemImage: "folder.badge.plus")
            }
            Divider()
            Button {
                showImportSheet = true
            } label: {
                Label("Import Project from file", systemImage: "square.and.arrow.down")
            }
        }
    }

    func totalCount(for section: ManageSection) -> Int {
        switch section {
        case .connections: return projectConnections.count
        case .identities: return projectIdentities.count
        case .projects: return projectStore.projects.count
        }
    }

    func sectionBinding(for section: ManageSection) -> Binding<Bool> {
        Binding(
            get: { expandedSections.contains(section) },
            set: { isExpanded in
                withAnimation(.snappy(duration: 0.2, extraBounce: 0)) {
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
