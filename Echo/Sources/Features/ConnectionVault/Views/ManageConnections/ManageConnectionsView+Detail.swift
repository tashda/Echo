@preconcurrency import SwiftUI
import AppKit

extension ManageConnectionsView {
    var detailContent: some View {
        detailBody
            .accentColor(appearanceStore.accentColor)
            .navigationTitle(navigationTitleText)
            .navigationSubtitle(navigationSubtitleText)
            .navigationHistoryToolbar($sidebarSelection, history: navHistory)
            .searchable(text: $searchText, placement: .toolbar, prompt: "Search")
            .toolbar {
                if activeSection == .projects {
                    ToolbarItemGroup(placement: .primaryAction) {
                        projectToolbarActions
                    }
                } else {
                    ToolbarItem(placement: .primaryAction) {
                        addToolbarMenu
                    }
                }
            }
    }

    var navigationTitleText: String {
        if case .folder(let folderID, _) = sidebarSelection,
           let folder = folder(withID: folderID) {
            return folder.displayName
        }
        if case .project(let projectID) = sidebarSelection,
           let project = projectStore.projects.first(where: { $0.id == projectID }) {
            return project.name
        }
        return activeSection.title
    }

    var navigationSubtitleText: String {
        if case .folder(let folderID, _) = sidebarSelection,
           let folder = folder(withID: folderID) {
            if let desc = folder.folderDescription, !desc.isEmpty {
                return desc
            }
            return activeSection.title
        }
        if case .project = sidebarSelection {
            return "Project Details"
        }
        return ""
    }

    @ViewBuilder
    var addToolbarMenu: some View {
        Menu {
            Button {
                handlePrimaryAdd(for: .connections)
            } label: {
                Label("New Connection", systemImage: "externaldrive.badge.plus")
            }
            Button {
                createNewIdentity()
            } label: {
                Label("New Identity", systemImage: "person.crop.circle.badge.plus")
            }
            Divider()
            Button {
                presentCreateFolder(for: activeSection)
            } label: {
                Label("New Folder", systemImage: "folder.badge.plus")
            }
        } label: {
            Label("Add", systemImage: "plus")
        }
        .menuIndicator(.hidden)
        .help("Add connection, identity, or folder")
    }

    @ViewBuilder
    private var projectToolbarActions: some View {
        Button {
            if case .project(let id) = sidebarSelection {
                exportProjectID = id
            } else {
                exportProjectID = projectStore.selectedProject?.id
            }
            showExportSheet = true
        } label: {
            Label("Export Project", systemImage: "square.and.arrow.up")
        }
        .help("Export Project")

        Button {
            isPresentingNewProjectSheet = true
        } label: {
            Label("New Project", systemImage: "plus")
        }
        .help("New Project")

        projectMoreMenu
    }

    @ViewBuilder
    private var projectMoreMenu: some View {
        if let project = displayedProject {
            Menu {
                Button {
                    importSettingsSourceProject = nil
                    showImportSettingsPopup = true
                } label: {
                    Label("Import from Project…", systemImage: "arrow.triangle.2.circlepath.circle")
                }

                Divider()

                Button(role: .destructive) {
                    showResetSettingsConfirmation = true
                } label: {
                    Label("Reset Project", systemImage: "arrow.counterclockwise")
                }

                if !project.isDefault {
                    Button(role: .destructive) {
                        projectToDelete = project
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Project", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuIndicator(.hidden)
            .help("More Actions")
        }
    }

    private func prepareGranularImport(from source: Project) {
        importSettingsSourceProject = source
        importSelectedConnectionIDs = Set(connectionStore.connections.filter { $0.projectID == source.id }.map(\.id))
        importSelectedIdentityIDs = Set(connectionStore.identities.filter { $0.projectID == source.id }.map(\.id))
        importIncludeSettings = true
        showImportSettingsPopup = true
    }
}
