import SwiftUI
import UniformTypeIdentifiers

extension ManageProjectsSheet {
    
    @ViewBuilder
    var exportSheet: some View {
        VStack(spacing: 20) {
            Text("Export Project")
                .font(TypographyTokens.displayLarge.weight(.bold))

            Text("Choose a password to encrypt your project export. This will protect your connection credentials and other sensitive data.")
                .font(TypographyTokens.standard)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            VStack(alignment: .leading, spacing: 12) {
                SecureField("Password", text: $exportPassword)
                    .textFieldStyle(.roundedBorder)

                Toggle("Include Global Settings", isOn: $includeGlobalSettings)
                    .font(TypographyTokens.standard)

                Toggle("Include Clipboard History", isOn: $includeClipboardHistory)
                    .font(TypographyTokens.standard)
                    .help("Adds saved clipboard items to the export so they can be restored when imported.")

                Toggle("Include Autocomplete History", isOn: $includeAutocompleteHistory)
                    .font(TypographyTokens.standard)
                    .help("Preserves accepted autocomplete suggestions so ranking feels familiar after import.")
            }
            .padding(.horizontal, SpacingTokens.md2)

            if let error = exportError {
                Text(error)
                    .font(TypographyTokens.caption2)
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
        .padding(SpacingTokens.lg2)
        .frame(width: 500)
    }

    @ViewBuilder
    var importSheet: some View {
        VStack(spacing: 20) {
            Text("Import Project")
                .font(TypographyTokens.displayLarge.weight(.bold))

            Text("Select an encrypted project file and enter the password to import it.")
                .font(TypographyTokens.standard)
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
            .padding(.horizontal, SpacingTokens.md2)

            if let error = importError {
                Text(error)
                    .font(TypographyTokens.caption2)
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
                    // Import logic triggered by file selection
                }
                .buttonStyle(.borderedProminent)
                .disabled(true)
            }
        }
        .padding(SpacingTokens.lg2)
        .frame(width: 500)
    }

    func exportProject() {
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
