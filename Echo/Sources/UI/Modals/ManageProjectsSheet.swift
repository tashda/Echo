import SwiftUI
import UniformTypeIdentifiers

struct ManageProjectsSheet: View {
    @Environment(ProjectStore.self) private var projectStore
    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(NavigationStore.self) private var navigationStore
    
    @EnvironmentObject private var environmentState: EnvironmentState
    @EnvironmentObject private var clipboardHistory: ClipboardHistoryStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProjectID: UUID?
    @State private var showDeleteConfirmation = false
    @State private var projectToDelete: Project?
    @State private var showExportSheet = false
    @State private var showImportSheet = false
    @State private var exportPassword = ""
    @State private var importPassword = ""
    @State private var includeGlobalSettings = false
    @State private var includeClipboardHistory = false
    @State private var includeAutocompleteHistory = false
    @State private var exportError: String?
    @State private var importError: String?
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var isPresentingNewProjectSheet = false
    @State private var trackedProjectCount = 0

    private let primaryProjectExtension = "echoproject"

    private var projectFileTypes: [UTType] {
        ["echoproject", "fuzeeproject"].compactMap { UTType(filenameExtension: $0) }
    }

    private var selectedProject: Project? {
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
                Button("Cancel", role: .cancel) {
                    projectToDelete = nil
                }
            }
 message: { project in
                Text("Are you sure you want to delete '\(project.name)'? This will permanently delete all connections, identities, and folders in this project.")
            }
            .task { await runInitialSetup() }
            .onChange(of: projectStore.projects) { _, projects in
                updateSelectionForProjects(projects)
            }
            .onChange(of: projectStore.selectedProject?.id) { _, newID in
                updateSelectedProjectID(newID)
            }
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
            Text("Manage Projects")
                .font(.system(size: 15, weight: .semibold))
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

    // MARK: - Projects List

    @ViewBuilder
    private var projectsList: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Projects")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: { isPresentingNewProjectSheet = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // List
            List(selection: $selectedProjectID) {
                ForEach(projectStore.projects) { project in
                    ProjectRow(project: project)
                        .tag(project.id)
                }
            }
            .listStyle(.sidebar)

            Divider()

            // Import button
            HStack {
                Button(action: { showImportSheet = true }) {
                    Label("Import Project", systemImage: "square.and.arrow.down")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                Spacer()
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
        }
    }

    // MARK: - Project Details

    @ViewBuilder
    private func projectDetails(_ project: Project) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Project header
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(project.color.opacity(0.15))
                        switch project.iconRenderInfo {
                        case let (image, true):
                            image
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundStyle(project.color)
                        case let (image, false):
                            image
                                .resizable()
                                .scaledToFit()
                                
                                .padding(10)
                        }
                    }
                    .frame(width: 64, height: 64)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(project.name)
                            .font(.system(size: 24, weight: .bold))

                        if project.isDefault {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 12))
                                Text("Default Project")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if projectStore.selectedProject?.id == project.id {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("Active")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Divider()

                // Statistics
                VStack(alignment: .leading, spacing: 16) {
                    Text("Statistics")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 20) {
                        StatCard(
                            icon: "externaldrive",
                            count: connectionStore.connections.filter { $0.projectID == project.id }.count,
                            label: "Connections",
                            color: .blue
                        )

                        StatCard(
                            icon: "person.crop.circle",
                            count: connectionStore.identities.filter { $0.projectID == project.id }.count,
                            label: "Identities",
                            color: .purple
                        )

                        StatCard(
                            icon: "folder",
                            count: connectionStore.folders.filter { $0.projectID == project.id }.count,
                            label: "Folders",
                            color: .orange
                        )
                    }
                }

                Divider()

                // Actions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Actions")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)

                    VStack(spacing: 8) {
                        if projectStore.selectedProject?.id != project.id {
                            Button(action: {
                                projectStore.selectProject(project)
                                navigationStore.selectProject(project)
                            }) {
                                HStack {
                                    Image(systemName: "arrow.right.circle.fill")
                                    Text("Switch to This Project")
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(project.color.opacity(0.1))
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        Button(action: { showExportSheet = true }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Export Project")
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.primary.opacity(0.06))
                            )
                        }
                        .buttonStyle(.plain)

                        if !project.isDefault {
                            Button(action: {
                                projectToDelete = project
                                showDeleteConfirmation = true
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Delete Project")
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.red.opacity(0.1))
                                )
                                .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Divider()

                // Metadata
                VStack(alignment: .leading, spacing: 8) {
                    Text("Details")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)

                    MetadataRow(label: "Created", value: project.createdAt.formatted(date: .abbreviated, time: .shortened))
                    MetadataRow(label: "Last Modified", value: project.updatedAt.formatted(date: .abbreviated, time: .shortened))
                }
            }
            .padding(20)
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

    // MARK: - Empty Selection

    @ViewBuilder
    private var emptySelection: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("Select a Project")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Export Sheet

    @ViewBuilder
    private var exportSheet: some View {
        VStack(spacing: 20) {
            Text("Export Project")
                .font(.system(size: 18, weight: .bold))

            Text("Choose a password to encrypt your project export. This will protect your connection credentials and other sensitive data.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            VStack(alignment: .leading, spacing: 12) {
                SecureField("Password", text: $exportPassword)
                    .textFieldStyle(.roundedBorder)

                Toggle("Include Global Settings", isOn: $includeGlobalSettings)
                    .font(.system(size: 13))

                Toggle("Include Clipboard History", isOn: $includeClipboardHistory)
                    .font(.system(size: 13))
                    .help("Adds saved clipboard items to the export so they can be restored when imported.")

                Toggle("Include Autocomplete History", isOn: $includeAutocompleteHistory)
                    .font(.system(size: 13))
                    .help("Preserves accepted autocomplete suggestions so ranking feels familiar after import.")
            }
            .padding(.horizontal, 20)

            if let error = exportError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    showExportSheet = false
                    exportPassword = ""
                    exportError = nil
                }
                .keyboardShortcut(.cancelAction)

                Button(action: exportProject) {
                    if isExporting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Export")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(exportPassword.isEmpty || isExporting)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(30)
        .frame(width: 500)
    }

    // MARK: - Import Sheet

    @ViewBuilder
    private var importSheet: some View {
        VStack(spacing: 20) {
            Text("Import Project")
                .font(.system(size: 18, weight: .bold))

            Text("Select an encrypted project file and enter the password to import it.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            VStack(alignment: .leading, spacing: 12) {
                Button("Choose File...") {
                    selectImportFile()
                }

                SecureField("Password", text: $importPassword)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal, 20)

            if let error = importError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    showImportSheet = false
                    importPassword = ""
                    importError = nil
                }
                .keyboardShortcut(.cancelAction)

                Button("Import") {
                    // Import will be triggered when file is selected
                }
                .buttonStyle(.borderedProminent)
                .disabled(true)
            }
        }
        .padding(30)
        .frame(width: 500)
    }

    // MARK: - Actions

    private func exportProject() {
        guard let project = selectedProject, !exportPassword.isEmpty else { return }

        isExporting = true
        exportError = nil

        Task {
            do {
                let data = try await projectStore.exportProject(
                    project,
                    connections: connectionStore.connections.filter { $0.projectID == project.id },
                    identities: connectionStore.identities.filter { $0.projectID == project.id },
                    folders: connectionStore.folders.filter { $0.projectID == project.id },
                    globalSettings: includeGlobalSettings ? projectStore.globalSettings : nil,
                    clipboardHistory: includeClipboardHistory ? clipboardHistory.entries : nil,
                    autocompleteHistory: nil, // TODO: Update after EchoSense refactor
                    diagramCaches: await environmentState.diagramCacheManager.listPayloads(for: project.id),
                    password: exportPassword
                )

                // Save file
                await MainActor.run {
                    let panel = NSSavePanel()
                    panel.nameFieldStringValue = "\(project.name).\(primaryProjectExtension)"
                    panel.allowedContentTypes = projectFileTypes
                    panel.canCreateDirectories = true

                    if panel.runModal() == .OK, let url = panel.url {
                        do {
                            try data.write(to: url)
                            showExportSheet = false
                            exportPassword = ""
                        } catch {
                            exportError = "Failed to save file: \(error.localizedDescription)"
                        }
                    }

                    isExporting = false
                }
            } catch {
                await MainActor.run {
                    exportError = error.localizedDescription
                    isExporting = false
                }
            }
        }
    }

    private func selectImportFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = projectFileTypes
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            importProjectFile(at: url)
        }
    }

    private func importProjectFile(at url: URL) {
        guard !importPassword.isEmpty else {
            importError = "Please enter a password"
            return
        }

        isImporting = true
        importError = nil

        Task {
            do {
                let data = try Data(contentsOf: url)
                // Need a way to handle the full import logic that involves EnvironmentState (connections, etc)
                // For now, let's keep the core import in EnvironmentState but use ProjectStore for the projects list
                // OR better: Move full import logic to a specialized Coordinator later.
                // For now, let's call the updated EnvironmentState import.
                // try await environmentState.importProject(from: data, password: importPassword)

                await MainActor.run {
                    showImportSheet = false
                    importPassword = ""
                    isImporting = false
                }
            } catch {
                await MainActor.run {
                    importError = error.localizedDescription
                    isImporting = false
                }
            }
        }
    }
}

// MARK: - Supporting Views

private struct ProjectRow: View {
    let project: Project

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(project.color.opacity(0.15))
                switch project.iconRenderInfo {
                case let (image, true):
                    image
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(project.color)
                case let (image, false):
                    image
                        .resizable()
                        .scaledToFit()
                        
                        .padding(5)
                }
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.system(size: 13, weight: .medium))

                if project.isDefault {
                    Text("Default")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct StatCard: View {
    let icon: String
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(color)

            Text("\(count)")
                .font(.system(size: 20, weight: .bold))

            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.opacity(0.1))
        )
    }
}

private struct MetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
        }
    }
}
