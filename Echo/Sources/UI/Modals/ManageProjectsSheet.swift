import SwiftUI
import UniformTypeIdentifiers

struct ManageProjectsSheet: View {
    @Environment(ProjectStore.self) internal var projectStore
    @Environment(ConnectionStore.self) internal var connectionStore
    @Environment(NavigationStore.self) internal var navigationStore
    
    @EnvironmentObject internal var environmentState: EnvironmentState
    @EnvironmentObject internal var clipboardHistory: ClipboardHistoryStore
    @Environment(\.dismiss) internal var dismiss

    @State internal var selectedProjectID: UUID?
    @State internal var showDeleteConfirmation = false
    @State internal var projectToDelete: Project?
    @State internal var showExportSheet = false
    @State internal var showImportSheet = false
    @State internal var exportPassword = ""
    @State internal var importPassword = ""
    @State internal var includeGlobalSettings = false
    @State internal var includeClipboardHistory = false
    @State internal var includeAutocompleteHistory = false
    @State internal var exportError: String?
    @State internal var importError: String?
    @State internal var isExporting = false
    @State internal var isImporting = false
    @State internal var columnVisibility: NavigationSplitViewVisibility = .all
    @State internal var isPresentingNewProjectSheet = false
    @State internal var trackedProjectCount = 0

    internal let primaryProjectExtension = "echoproject"

    internal var projectFileTypes: [UTType] {
        ["echoproject", "fuzeeproject"].compactMap { UTType(filenameExtension: $0) }
    }

    internal var selectedProject: Project? {
        guard let id = selectedProjectID else { return nil }
        return projectStore.projects.first { $0.id == id }
    }

    var body: some View {
        baseLayout
            .sheet(isPresented: $showExportSheet) { exportSheet }
            .sheet(isPresented: $showImportSheet) { importSheet }
            .sheet(isPresented: $isPresentingNewProjectSheet) {
                NewProjectSheet()
                    .environment(projectStore)
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
            .task { await runInitialSetup() }
            .onChange(of: projectStore.projects) { _, projects in updateSelectionForProjects(projects) }
            .onChange(of: projectStore.selectedProject?.id) { _, newID in updateSelectedProjectID(newID) }
    }

    private var baseLayout: some View {
        splitView
            .frame(width: 820, height: 600)
            .toolbar { toolbarContent }
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

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text("Manage Projects").font(.system(size: 15, weight: .semibold))
        }
        ToolbarItem(placement: .cancellationAction) {
            Button("Close") { dismiss() }
        }
    }

    private var splitView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            projectsList
                .frame(minWidth: 260)
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 320)
        } detail: {
            detailPane
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        Group {
            if let project = selectedProject {
                projectDetails(project)
            } else {
                emptySelection
            }
        }
        .frame(minWidth: 440)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var emptySelection: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.gearshape").font(.system(size: 48)).foregroundStyle(.tertiary)
            Text("Select a Project").font(TypographyTokens.display.weight(.semibold)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
