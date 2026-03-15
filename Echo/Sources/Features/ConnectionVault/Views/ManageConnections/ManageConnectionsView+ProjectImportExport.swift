import SwiftUI
import UniformTypeIdentifiers

// MARK: - Import Settings Sheet (Granular)

extension ManageConnectionsView {
    @ViewBuilder
    var importSettingsSheet: some View {
        VStack(spacing: 0) {
            if let source = importSettingsSourceProject {
                 granularImportContent(source: source)
            } else {
                projectSelectionContent
            }
        }
        .frame(width: 500, height: 600)
    }

    @ViewBuilder
    private var projectSelectionContent: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: SpacingTokens.md) {
                Text("Select Project to Import From")
                    .font(TypographyTokens.displayLarge.weight(.bold))

                Text("Choose a project from the list below to see its available resources.")
                    .font(TypographyTokens.standard)
                    .foregroundStyle(ColorTokens.Text.secondary)

                List {
                    let targetID: UUID? = {
                        if case .project(let id) = sidebarSelection { return id }
                        return projectStore.selectedProject?.id
                    }()

                    ForEach(projectStore.projects.filter { $0.id != targetID }) { project in
                        Button {
                            withAnimation {
                                importSettingsSourceProject = project
                                importSelectedConnectionIDs = Set(connectionStore.connections.filter { $0.projectID == project.id }.map(\.id))
                                importSelectedIdentityIDs = Set(connectionStore.identities.filter { $0.projectID == project.id }.map(\.id))
                            }
                        } label: {
                            HStack {
                                Label(project.name, systemImage: project.iconName ?? "folder.fill")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(TypographyTokens.compact.weight(.bold))
                                    .foregroundStyle(ColorTokens.Text.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, SpacingTokens.xxxs)
                    }
                }
                .listStyle(.inset)
                .background(ColorTokens.Text.secondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(SpacingTokens.lg)

                Spacer()

                Divider()

                HStack {
                Button("Cancel") {
                    showImportSettingsPopup = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()
                }
                .padding(SpacingTokens.md)
                .background(.bar)
        }
    }

    private func granularImportContent(source: Project) -> some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button {
                        importSettingsSourceProject = nil
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(TypographyTokens.prominent.weight(.bold))
                    }
                    .buttonStyle(.plain)

                    importHeaderView(source: source)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: SpacingTokens.md2) {
                        importOptionsSection
                        importConnectionsSection(source: source)
                        importIdentitiesSection(source: source)
                    }
                    .padding(SpacingTokens.lg)
                }
            }

            Divider()

            let targetID: UUID? = {
                if case .project(let id) = sidebarSelection { return id }
                return projectStore.selectedProject?.id
            }()

            if let targetID {
                importFooterView(source: source, targetID: targetID)
            }
        }
    }

    private func importHeaderView(source: Project) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            Text("Import from \(source.name)")
                .font(TypographyTokens.displayLarge.weight(.bold))
            Text("Select the specific items you want to import into your current project.")
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        .padding(.vertical, SpacingTokens.lg)
        .padding(.trailing, SpacingTokens.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var importOptionsSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            Text("GENERAL OPTIONS")
                .font(TypographyTokens.detail.weight(.bold))
                .foregroundStyle(ColorTokens.Text.secondary)

            Toggle("Include Project Settings", isOn: $importIncludeSettings)
                .font(TypographyTokens.standard)

            Picker("Method", selection: $importSettingsMerge) {
                Text("Merge with current project").tag(true)
                Text("Replace current project content").tag(false)
            }
            .pickerStyle(.radioGroup)
            .font(TypographyTokens.standard)
        }
    }

    private func importConnectionsSection(source: Project) -> some View {
        let conns = connectionStore.connections.filter { $0.projectID == source.id }
        return VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            HStack {
                Text("CONNECTIONS (\(conns.count))")
                    .font(TypographyTokens.detail.weight(.bold))
                    .foregroundStyle(ColorTokens.Text.secondary)
                Spacer()
                Button(importSelectedConnectionIDs.count == conns.count ? "Deselect All" : "Select All") {
                    if importSelectedConnectionIDs.count == conns.count {
                        importSelectedConnectionIDs.removeAll()
                    } else {
                        importSelectedConnectionIDs = Set(conns.map(\.id))
                    }
                }
                .buttonStyle(.link)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.accent)
            }
            .font(TypographyTokens.detail.weight(.bold))
            .foregroundStyle(ColorTokens.Text.secondary)

            if conns.isEmpty {
                Text("No connections in this project").font(TypographyTokens.caption2).italic()
            } else {
                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    ForEach(conns.sorted(by: { $0.connectionName < $1.connectionName })) { conn in
                        Toggle(isOn: Binding(
                            get: { importSelectedConnectionIDs.contains(conn.id) },
                            set: { val in
                                if val { importSelectedConnectionIDs.insert(conn.id) }
                                else { importSelectedConnectionIDs.remove(conn.id) }
                            }
                        )) {
                            Label(conn.connectionName, systemImage: "externaldrive")
                                .font(TypographyTokens.standard)
                        }
                        .toggleStyle(.checkbox)
                    }
                }
                .padding(SpacingTokens.sm)
                .background(ColorTokens.Text.secondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: SpacingTokens.xs))
            }
        }
    }

    private func importIdentitiesSection(source: Project) -> some View {
        let ids = connectionStore.identities.filter { $0.projectID == source.id }
        return VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            HStack {
                Text("IDENTITIES (\(ids.count))")
                    .font(TypographyTokens.detail.weight(.bold))
                    .foregroundStyle(ColorTokens.Text.secondary)
                Spacer()
                Button(importSelectedIdentityIDs.count == ids.count ? "Deselect All" : "Select All") {
                    if importSelectedIdentityIDs.count == ids.count {
                        importSelectedIdentityIDs.removeAll()
                    } else {
                        importSelectedIdentityIDs = Set(ids.map(\.id))
                    }
                }
                .buttonStyle(.link)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.accent)
            }
            .font(TypographyTokens.detail.weight(.bold))
            .foregroundStyle(ColorTokens.Text.secondary)

            if ids.isEmpty {
                Text("No identities in this project").font(TypographyTokens.caption2).italic()
            } else {
                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    ForEach(ids.sorted(by: { $0.name < $1.name })) { identity in
                        Toggle(isOn: Binding(
                            get: { importSelectedIdentityIDs.contains(identity.id) },
                            set: { val in
                                if val { importSelectedIdentityIDs.insert(identity.id) }
                                else { importSelectedIdentityIDs.remove(identity.id) }
                            }
                        )) {
                            Label(identity.name, systemImage: "person.crop.circle")
                                .font(TypographyTokens.standard)
                        }
                        .toggleStyle(.checkbox)
                    }
                }
                .padding(SpacingTokens.sm)
                .background(ColorTokens.Text.secondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: SpacingTokens.xs))
            }
        }
    }

    private func importFooterView(source: Project, targetID: UUID) -> some View {
        HStack {
            Spacer()
            Button("Cancel") {
                showImportSettingsPopup = false
                importSettingsSourceProject = nil
            }
            .keyboardShortcut(.cancelAction)

            Button("Import Selected Items") {
                Task {
                    try? await projectStore.importProjectResources(
                        from: source,
                        into: targetID,
                        connectionStore: connectionStore,
                        merge: importSettingsMerge,
                        includeSettings: importIncludeSettings,
                        connectionIDs: importSelectedConnectionIDs,
                        identityIDs: importSelectedIdentityIDs
                    )
                    showImportSettingsPopup = false
                    importSettingsSourceProject = nil
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(importSelectedConnectionIDs.isEmpty && importSelectedIdentityIDs.isEmpty && !importIncludeSettings)
        }
        .padding(SpacingTokens.md)
    }
}

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
                    Button("Choose File…") {
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
