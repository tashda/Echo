import SwiftUI
import UniformTypeIdentifiers

// MARK: - Export / Import (Logic and Sheets)

extension ManageConnectionsView {
    internal var exportProject_: Project? {
        guard let id = exportProjectID else { return nil }
        return projectStore.projects.first { $0.id == id }
    }

    @ViewBuilder
    var exportSheet: some View {
        VStack(spacing: 0) {
            exportFormContent
            Divider()
            exportFooterButtons
        }
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var exportFormContent: some View {
        Form {
            Section {
                Picker("Project", selection: $exportProjectID) {
                    ForEach(projectStore.projects) { project in
                        Text(project.name).tag(Optional(project.id))
                    }
                }

                SecureField("Password", text: $exportPassword, prompt: Text("Encryption password"))
            } header: {
                Text("Export Project")
            }

            Section("Options") {
                Toggle("Include Global Settings Template", isOn: $includeGlobalSettings)
                    .help("The project's own settings are always included. This also exports the global fallback template.")

                Toggle("Include Clipboard History", isOn: $includeClipboardHistory)
                    .help("Adds saved clipboard items to the export so they can be restored when imported.")

                Toggle("Include Autocomplete History", isOn: $includeAutocompleteHistory)
                    .help("Preserves accepted autocomplete suggestions so ranking feels familiar after import.")
            }

            if let error = exportError {
                Section {
                    Text(error)
                        .foregroundStyle(ColorTokens.Status.error)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .scrollDisabled(true)
    }

    private var exportFooterButtons: some View {
        HStack {
            Spacer()
            Button("Cancel", role: .cancel) {
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
            .keyboardShortcut(.defaultAction)
            .disabled(exportPassword.isEmpty || isExporting || exportProjectID == nil)
        }
        .padding(SpacingTokens.md2)
    }

    @ViewBuilder
    var importSheet: some View {
        VStack(spacing: 0) {
            importFormContent
            Divider()
            importFileFooterButtons
        }
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var importFormContent: some View {
        Form {
            Section {
                SecureField("Password", text: $importPassword, prompt: Text("Decryption password"))

                LabeledContent("File") {
                    Button("Choose File") {
                        selectImportFile()
                    }
                }
            } header: {
                Text("Import Project")
            }

            if let error = importError {
                Section {
                    Text(error)
                        .foregroundStyle(ColorTokens.Status.error)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .scrollDisabled(true)
    }

    private var importFileFooterButtons: some View {
        HStack {
            Spacer()
            Button("Cancel", role: .cancel) {
                showImportSheet = false
                importPassword = ""
                importError = nil
            }
            .keyboardShortcut(.cancelAction)

            Button("Import") {
                // Import logic triggered by file selection
            }
            .keyboardShortcut(.defaultAction)
            .disabled(true)
        }
        .padding(SpacingTokens.md2)
    }

    func exportProject() {
        guard let project = exportProject_, !exportPassword.isEmpty else { return }

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
                    autocompleteHistory: nil,
                    diagramCaches: await environmentState.diagramCacheStore.listPayloads(for: project.id),
                    password: exportPassword
                )

                await MainActor.run {
                    let panel = NSSavePanel()
                    panel.nameFieldStringValue = "\(project.name).echoproject"
                    panel.allowedContentTypes = ["echoproject"].compactMap { UTType(filenameExtension: $0) }
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

    func selectImportFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = ["echoproject", "fuzeeproject"].compactMap { UTType(filenameExtension: $0) }
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            importProjectFile(at: url)
        }
    }

    func importProjectFile(at url: URL) {
        guard !importPassword.isEmpty else {
            importError = "Please enter a password"
            return
        }

        isImporting = true
        importError = nil

        Task {
            // Future coordinator implementation will handle full import
            await MainActor.run {
                showImportSheet = false
                importPassword = ""
                isImporting = false
            }
        }
    }
}
