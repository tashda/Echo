import SwiftUI
import UniformTypeIdentifiers

struct ManageProjectsSheet: View {
    @EnvironmentObject private var appModel: AppModel
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
    @State private var exportError: String?
    @State private var importError: String?
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    private let primaryProjectExtension = "echoproject"

    private var projectFileTypes: [UTType] {
        ["echoproject", "fuzeeproject"].compactMap { UTType(filenameExtension: $0) }
    }

    private var selectedProject: Project? {
        guard let id = selectedProjectID else { return nil }
        return appModel.projects.first { $0.id == id }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            projectsList
                .frame(minWidth: 260)
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 320)
        } detail: {
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
        .frame(width: 820, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Manage Projects")
                    .font(.system(size: 15, weight: .semibold))
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .sheet(isPresented: $showExportSheet) {
            exportSheet
        }
        .sheet(isPresented: $showImportSheet) {
            importSheet
        }
        .alert("Delete Project?", isPresented: $showDeleteConfirmation, presenting: projectToDelete) { project in
            Button("Delete", role: .destructive) {
                Task {
                    await appModel.deleteProject(project)
                    selectedProjectID = nil
                    projectToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                projectToDelete = nil
            }
        } message: { project in
            Text("Are you sure you want to delete '\(project.name)'? This will permanently delete all connections, identities, and folders in this project.")
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
                Button(action: { appModel.showNewProjectSheet = true }) {
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
                ForEach(appModel.projects) { project in
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

                    if appModel.selectedProject?.id == project.id {
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
                            count: appModel.connections.filter { $0.projectID == project.id }.count,
                            label: "Connections",
                            color: .blue
                        )

                        StatCard(
                            icon: "person.crop.circle",
                            count: appModel.identities.filter { $0.projectID == project.id }.count,
                            label: "Identities",
                            color: .purple
                        )

                        StatCard(
                            icon: "folder",
                            count: appModel.folders.filter { $0.projectID == project.id }.count,
                            label: "Folders",
                            color: .orange
                        )
                    }
                }

                Divider()

                ProjectAppearanceSection(project: project)

                Divider()

                // Actions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Actions")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)

                    VStack(spacing: 8) {
                        if appModel.selectedProject?.id != project.id {
                            Button(action: {
                                appModel.selectedProject = project
                                appModel.navigationState.selectProject(project)
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
                let data = try await appModel.exportProject(
                    project,
                    includeGlobalSettings: includeGlobalSettings,
                    includeClipboardHistory: includeClipboardHistory,
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
                try await appModel.importProject(from: data, password: importPassword)

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

private struct ProjectAppearanceSection: View {
    @EnvironmentObject private var appModel: AppModel
    let project: Project

    @State private var selectedPaletteID: String?
    @State private var projectCustomPalette: SQLEditorPalette?
    @State private var paletteEditorDraft: SQLEditorPalette?
    @State private var isSaving = false
    @State private var localShowLineNumbers: Bool
    @State private var localHighlightSelected: Bool
    @State private var localHighlightDelay: Double
    @State private var localWrapLines: Bool
    @State private var localIndentWrappedLines: Int

    private var paletteSelectionBinding: Binding<String?> {
        Binding(
            get: { selectedPaletteID },
            set: { newValue in
                selectedPaletteID = newValue
                handleSelectionChange(newValue)
            }
        )
    }

    private var paletteEditorPresentedBinding: Binding<Bool> {
        Binding(
            get: { paletteEditorDraft != nil },
            set: { if !$0 { cancelEditing() } }
        )
    }

    private var paletteEditorDraftBinding: Binding<SQLEditorPalette> {
        Binding(
            get: { paletteEditorDraft ?? projectCustomPalette ?? currentPalette },
            set: { paletteEditorDraft = $0 }
        )
    }

    init(project: Project) {
        self.project = project
        _selectedPaletteID = State(initialValue: project.settings.customEditorPalette?.id ?? project.settings.effectivePaletteIdentifier)
        _projectCustomPalette = State(initialValue: project.settings.customEditorPalette)
        _localShowLineNumbers = State(initialValue: project.settings.showLineNumbers ?? true)
        _localHighlightSelected = State(initialValue: project.settings.highlightSelectedSymbol ?? true)
        _localHighlightDelay = State(initialValue: project.settings.highlightDelay ?? 0.25)
        _localWrapLines = State(initialValue: project.settings.wrapLines ?? true)
        _localIndentWrappedLines = State(initialValue: project.settings.indentWrappedLines ?? 4)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Query Editor Palette")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text("Override the global SQL editor palette for this project.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            PalettePreview(palette: currentPalette)
                .frame(height: 120)
                .allowsHitTesting(false)

            Picker("Palette", selection: paletteSelectionBinding) {
                Text("Use Global Default").tag(String?.none)
                ForEach(availablePalettes, id: \.id) { palette in
                    Text(palette.name)
                        .tag(Optional(palette.id))
                }
                if let custom = projectCustomPalette, !availablePalettes.contains(where: { $0.id == custom.id }) {
                    Text("\(custom.name) (Project)")
                        .tag(Optional(custom.id))
                }
            }
            .pickerStyle(.menu)

            if selectedPaletteID == nil {
                Text("Inheriting the global default palette.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if isUsingCustomPalette {
                Text("This project uses a dedicated custom palette.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button(action: startCustomizing) {
                    Label(isUsingCustomPalette ? "Edit Project Palette" : "Customize Colors…", systemImage: "slider.horizontal.3")
                }
                .buttonStyle(.bordered)

                if selectedPaletteID != nil {
                    Button("Revert to Global") {
                        paletteSelectionBinding.wrappedValue = nil
                    }
                    .buttonStyle(.borderless)
                }

                if isSaving {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer()
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Display Overrides")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                Toggle(isOn: projectShowLineNumbersBinding) {
                    Text("Show line numbers")
                        .font(.subheadline)
                }
                .toggleStyle(.switch)

                Toggle(isOn: projectHighlightSelectedBinding) {
                    Text("Highlight instances of selected symbol")
                        .font(.subheadline)
                }
                .toggleStyle(.switch)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Highlighting delay")
                            .font(.subheadline)
                        Text("Seconds before similar text glows in this project")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Stepper(value: projectHighlightDelayBinding, in: 0...2, step: 0.05) {
                        Text(String(format: "%.2fs", currentHighlightDelay))
                            .frame(width: 60, alignment: .trailing)
                    }
                    .controlSize(.small)
                }

                Toggle(isOn: projectWrapLinesBinding) {
                    Text("Wrap lines to editor width")
                        .font(.subheadline)
                }
                .toggleStyle(.switch)

                if currentWrapLines {
                    HStack {
                        Text("Indent wrapped lines")
                            .font(.subheadline)

                        Spacer()

                        Stepper(value: projectIndentWrappedLinesBinding, in: 0...12) {
                            Text("\(currentIndentWrappedLines) spaces")
                                .frame(width: 100, alignment: .trailing)
                        }
                        .controlSize(.small)
                    }
                }

                Button("Use Global Defaults") {
                    resetDisplayOverrides()
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
        .sheet(isPresented: paletteEditorPresentedBinding) {
            if paletteEditorDraft != nil {
                ProjectPaletteEditorSheet(
                    projectName: project.name,
                    palette: paletteEditorDraftBinding,
                    isNew: projectCustomPalette == nil,
                    isSaving: isSaving,
                    onCancel: cancelEditing,
                    onSave: saveCustomPalette
                )
                .frame(minWidth: 440, minHeight: 500)
            }
        }
        .onAppear {
            syncLocalState(with: project)
        }
        .onChange(of: project) { _, updated in
            selectedPaletteID = updated.settings.customEditorPalette?.id ?? updated.settings.effectivePaletteIdentifier
            projectCustomPalette = updated.settings.customEditorPalette
            syncLocalState(with: updated)
        }
    }

    private var availablePalettes: [SQLEditorPalette] {
        appModel.globalSettings.availablePalettes
    }

    private var currentPalette: SQLEditorPalette {
        if let custom = projectCustomPalette, selectedPaletteID == custom.id {
            return custom
        }
        if let id = selectedPaletteID, let palette = availablePalettes.first(where: { $0.id == id }) {
            return palette
        }
        return appModel.globalSettings.palette(withID: appModel.globalSettings.defaultEditorPaletteID) ?? SQLEditorPalette.aurora
    }

    private var isUsingCustomPalette: Bool {
        if let custom = projectCustomPalette, selectedPaletteID == custom.id {
            return true
        }
        return false
    }

    private var currentHighlightDelay: Double {
        localHighlightDelay
    }

    private var currentWrapLines: Bool {
        localWrapLines
    }

    private var currentIndentWrappedLines: Int {
        localIndentWrappedLines
    }

    private func handleSelectionChange(_ newValue: String?) {
        guard !isSaving else { return }
        Task {
            isSaving = true
            await appModel.updateProjectAppearance(projectID: project.id) { settings in
                settings.editorPaletteID = newValue
                if let custom = projectCustomPalette, newValue == custom.id {
                    settings.customEditorPalette = custom
                } else {
                    settings.customEditorPalette = nil
                }
            }
            await MainActor.run { isSaving = false }
        }
        if let custom = projectCustomPalette, newValue == custom.id {
            // keep
        } else if projectCustomPalette != nil {
            projectCustomPalette = nil
        }
    }

    private func startCustomizing() {
        let base = (projectCustomPalette != nil && selectedPaletteID == projectCustomPalette?.id)
            ? projectCustomPalette!
            : currentPalette
        paletteEditorDraft = projectCustomPalette ?? base.asCustomCopy(named: "\(project.name) Palette")
    }

    private func saveCustomPalette(_ palette: SQLEditorPalette) {
        Task {
            isSaving = true
            await appModel.updateProjectAppearance(projectID: project.id) { settings in
                settings.editorPaletteID = palette.id
                settings.customEditorPalette = palette
            }
            await MainActor.run {
                projectCustomPalette = palette
                selectedPaletteID = palette.id
                paletteEditorDraft = nil
                isSaving = false
            }
        }
    }

    private func cancelEditing() {
        paletteEditorDraft = nil
    }

    private func resetDisplayOverrides() {
        Task {
            isSaving = true
            await appModel.updateProjectAppearance(projectID: project.id) { settings in
                settings.showLineNumbers = nil
                settings.highlightSelectedSymbol = nil
                settings.highlightDelay = nil
                settings.wrapLines = nil
                settings.indentWrappedLines = nil
            }
            await MainActor.run {
                syncLocalState(with: appModel.projects.first(where: { $0.id == project.id }) ?? project)
                isSaving = false
            }
        }
    }

    private func syncLocalState(with project: Project) {
        let resolved = SQLEditorThemeResolver.resolveDisplayOptions(globalSettings: appModel.globalSettings, project: project)
        localShowLineNumbers = project.settings.showLineNumbers ?? resolved.showLineNumbers
        localHighlightSelected = project.settings.highlightSelectedSymbol ?? resolved.highlightSelectedSymbol
        localHighlightDelay = project.settings.highlightDelay ?? resolved.highlightDelay
        localWrapLines = project.settings.wrapLines ?? resolved.wrapLines
        localIndentWrappedLines = project.settings.indentWrappedLines ?? resolved.indentWrappedLines
    }

    private var projectShowLineNumbersBinding: Binding<Bool> {
        Binding(
            get: { localShowLineNumbers },
            set: { newValue in
                localShowLineNumbers = newValue
                Task {
                    await appModel.updateProjectAppearance(projectID: project.id) { settings in
                        settings.showLineNumbers = newValue
                    }
                }
            }
        )
    }

    private var projectHighlightSelectedBinding: Binding<Bool> {
        Binding(
            get: { localHighlightSelected },
            set: { newValue in
                localHighlightSelected = newValue
                Task {
                    await appModel.updateProjectAppearance(projectID: project.id) { settings in
                        settings.highlightSelectedSymbol = newValue
                    }
                }
            }
        )
    }

    private var projectHighlightDelayBinding: Binding<Double> {
        Binding(
            get: { localHighlightDelay },
            set: { newValue in
                localHighlightDelay = newValue
                Task {
                    await appModel.updateProjectAppearance(projectID: project.id) { settings in
                        settings.highlightDelay = newValue
                    }
                }
            }
        )
    }

    private var projectWrapLinesBinding: Binding<Bool> {
        Binding(
            get: { localWrapLines },
            set: { newValue in
                localWrapLines = newValue
                Task {
                    await appModel.updateProjectAppearance(projectID: project.id) { settings in
                        settings.wrapLines = newValue
                    }
                }
            }
        )
    }

    private var projectIndentWrappedLinesBinding: Binding<Int> {
        Binding(
            get: { localIndentWrappedLines },
            set: { newValue in
                localIndentWrappedLines = newValue
                Task {
                    await appModel.updateProjectAppearance(projectID: project.id) { settings in
                        settings.indentWrappedLines = newValue
                    }
                }
            }
        )
    }
}

private struct ProjectPaletteEditorSheet: View {
    let projectName: String
    @Binding var palette: SQLEditorPalette
    let isNew: Bool
    let isSaving: Bool
    let onCancel: () -> Void
    let onSave: (SQLEditorPalette) -> Void

    private var title: String { isNew ? "Create Project Palette" : "Edit Project Palette" }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("Customize how SQL looks inside \(projectName). These colors stay with the project export.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            PaletteEditorView(palette: $palette)

            Divider()

            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button(action: { onSave(palette) }) {
                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(isNew ? "Save Palette" : "Save Changes")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving || palette.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
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
