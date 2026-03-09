import SwiftUI
import UniformTypeIdentifiers

struct ManageProjectsView: View {
    @Environment(ProjectStore.self) internal var projectStore
    @Environment(ConnectionStore.self) internal var connectionStore
    @Environment(NavigationStore.self) internal var navigationStore

    @EnvironmentObject internal var environmentState: EnvironmentState
    @EnvironmentObject internal var clipboardHistory: ClipboardHistoryStore

    @State internal var selectedProjectID: UUID?
    @State internal var showDeleteConfirmation = false
    @State internal var projectToDelete: Project?
    @State internal var showExportSheet = false
    @State internal var showImportSheet = false
    @State internal var exportPassword = ""
    @State internal var importPassword = ""
    @State internal var includeGlobalSettings = true
    @State internal var includeClipboardHistory = true
    @State internal var includeAutocompleteHistory = true
    @State internal var exportError: String?
    @State internal var importError: String?
    @State internal var isExporting = false
    @State internal var isImporting = false
    @State internal var isPresentingNewProjectSheet = false
    @State internal var trackedProjectCount = 0
    @State internal var showResetSettingsConfirmation = false
    @State internal var exportProjectID: UUID?
    @State internal var isImportingSettings = false
    @State internal var lastImportedFrom: (name: String, date: Date)?
    @State internal var showIconPicker = false

    internal let primaryProjectExtension = "echoproject"

    internal var projectFileTypes: [UTType] {
        ["echoproject", "fuzeeproject"].compactMap { UTType(filenameExtension: $0) }
    }

    internal var selectedProject: Project? {
        guard let id = selectedProjectID else { return nil }
        return projectStore.projects.first { $0.id == id }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedProjectID) {
                ForEach(projectStore.projects) { project in
                    Label {
                        Text(project.name)
                    } icon: {
                        Image(systemName: project.iconName ?? "folder.fill")
                    }
                    .tag(project.id)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 240)
        } detail: {
            Group {
                if let project = selectedProject {
                    projectDetails(project)
                        .id(project.id)
                } else {
                    ContentUnavailableView {
                        Label("Select a Project", systemImage: "folder.badge.gearshape")
                    } description: {
                        Text("Choose a project to view its details.")
                    }
                }
            }
            .navigationTitle(selectedProject?.name ?? "Manage Projects")
            .toolbarTitleDisplayMode(.automatic)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    if let project = selectedProject, !project.isDefault {
                        Button {
                            projectToDelete = project
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .help("Delete Project")
                    }

                    Button {
                        showImportSheet = true
                    } label: {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                    .help("Import Project")

                    Button {
                        exportProjectID = selectedProjectID
                        showExportSheet = true
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .help("Export Project")

                    Button {
                        isPresentingNewProjectSheet = true
                    } label: {
                        Label("New Project", systemImage: "plus")
                    }
                    .help("New Project")
                }
            }
        }
        .sheet(isPresented: $showExportSheet) { exportSheet }
        .sheet(isPresented: $showImportSheet) { importSheet }
        .sheet(isPresented: $isPresentingNewProjectSheet) {
            NewProjectSheet()
                .environment(projectStore)
                .environment(navigationStore)
                .environmentObject(environmentState)
        }
        .alert("Delete Project?", isPresented: $showDeleteConfirmation, presenting: projectToDelete) { project in
            Button("Delete", role: .destructive) {
                Task {
                    try? await projectStore.deleteProject(project)
                    selectedProjectID = nil
                    projectToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { projectToDelete = nil }
        } message: { project in
            Text("Are you sure you want to delete '\(project.name)'? This will permanently delete all connections, identities, and folders in this project.")
        }
        .sheet(isPresented: $showIconPicker) {
            if let project = selectedProject {
                ProjectIconPickerSheet(project: project) { newIcon in
                    Task {
                        var updated = project
                        updated.iconName = newIcon
                        updated.updatedAt = Date()
                        try? await projectStore.updateProject(updated)
                    }
                }
                .environment(projectStore)
            }
        }
        .alert("Reset Settings?", isPresented: $showResetSettingsConfirmation) {
            Button("Reset", role: .destructive) {
                guard let id = selectedProjectID else { return }
                Task { try? await projectStore.resetSettingsToDefault(for: id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reset all settings for this project to factory defaults. This cannot be undone.")
        }
        .task { await runInitialSetup() }
        .onChange(of: projectStore.projects) { _, projects in updateSelectionForProjects(projects) }
        .onChange(of: projectStore.selectedProject?.id) { _, newID in updateSelectedProjectID(newID) }
    }

    private func runInitialSetup() async {
        trackedProjectCount = projectStore.projects.count
        if selectedProjectID == nil {
            selectedProjectID = projectStore.selectedProject?.id ?? projectStore.projects.first?.id
        }
    }

    private func updateSelectionForProjects(_ projects: [Project]) {
        if projects.isEmpty {
            selectedProjectID = nil
        } else {
            if projects.count > trackedProjectCount {
                selectedProjectID = projectStore.selectedProject?.id ?? projects.last?.id
            } else if let currentSelection = selectedProjectID,
                      !projects.contains(where: { $0.id == currentSelection }) {
                selectedProjectID = projectStore.selectedProject?.id ?? projects.first?.id
            }
        }
        trackedProjectCount = projects.count
    }

    private func updateSelectedProjectID(_ newID: UUID?) {
        guard let newID else { return }
        selectedProjectID = newID
    }
}
