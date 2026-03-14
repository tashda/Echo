import SwiftUI
import UniformTypeIdentifiers

extension ManageConnectionsView {
    @ViewBuilder
    var projectsDetail: some View {
        if case .project(let id) = sidebarSelection,
           let project = projectStore.projects.first(where: { $0.id == id }) {
            projectDetails(project)
        } else if case .section(.projects) = sidebarSelection,
                  let activeProject = projectStore.selectedProject ?? projectStore.projects.first {
            projectDetails(activeProject)
        } else {
            ContentUnavailableView {
                Label("Select a Project", systemImage: "folder.badge.gearshape")
            } description: {
                Text("Choose a project from the sidebar to view its details.")
            }
        }
    }

    @ViewBuilder
    func projectDetails(_ project: Project) -> some View {
        let conns = connectionStore.connections.filter { $0.projectID == project.id }
        let identities = connectionStore.identities.filter { $0.projectID == project.id }
        let folders = connectionStore.folders.filter { $0.projectID == project.id }
        
        ScrollView {
            VStack(spacing: 0) {
                // MARK: - Header
                HStack(alignment: .top, spacing: SpacingTokens.lg) {
                    Button {
                        showIconPicker = true
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(ColorTokens.Text.quaternary.opacity(0.5))
                            Image(systemName: project.iconName ?? "folder.fill")
                                .font(TypographyTokens.hero.weight(.semibold))
                                .foregroundStyle(project.color)
                        }
                        .frame(width: 100, height: 100)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                        Text(project.name)
                            .font(TypographyTokens.hero.weight(.bold))
                        
                        Text(project.isDefault ? "DEFAULT PROJECT" : "USER PROJECT")
                            .font(TypographyTokens.standard.weight(.bold))
                            .foregroundStyle(ColorTokens.Text.secondary)

                        Spacer()

                        Button {
                            projectStore.selectProject(project)
                            navigationStore.selectProject(project)
                        } label: {
                            Text(projectStore.selectedProject?.id == project.id ? "Selected" : "Select")
                                .font(TypographyTokens.standard.weight(.bold))
                                .padding(.horizontal, SpacingTokens.md)
                                .padding(.vertical, SpacingTokens.xxs2)
                                .background(projectStore.selectedProject?.id == project.id ? ColorTokens.Text.secondary.opacity(0.2) : ColorTokens.accent)
                                .foregroundStyle(projectStore.selectedProject?.id == project.id ? AnyShapeStyle(ColorTokens.Text.primary) : AnyShapeStyle(Color.white))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(projectStore.selectedProject?.id == project.id)
                    }
                    Spacer()
                }
                .padding(.horizontal, SpacingTokens.xl2)
                .padding(.top, SpacingTokens.lg2)
                .padding(.bottom, SpacingTokens.xl2)

                Divider().padding(.horizontal, SpacingTokens.xl2)

                // MARK: - Information Section (Two Column)
                VStack(alignment: .leading, spacing: SpacingTokens.md2) {
                    Text("Information")
                        .font(TypographyTokens.hero.weight(.bold))
                        .padding(.bottom, SpacingTokens.xxs)

                    Grid(alignment: .leading, horizontalSpacing: SpacingTokens.xl2, verticalSpacing: SpacingTokens.md) {
                        GridRow {
                            appStoreInfoColumn(label: "Created", value: project.createdAt.formatted(date: .long, time: .omitted))
                            appStoreInfoColumn(label: "Modified", value: project.updatedAt.formatted(date: .long, time: .omitted))
                        }
                        
                        Divider().gridCellColumns(2)
                        
                        GridRow {
                            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                                DisclosureGroup {
                                    VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                                        if conns.isEmpty {
                                            Text("No connections saved")
                                                .font(TypographyTokens.detail)
                                                .foregroundStyle(ColorTokens.Text.tertiary)
                                        } else {
                                            projectResourceTree(
                                                nodes: buildFolderNodes(from: folders.filter { $0.kind == .connections }, itemMap: Dictionary(grouping: conns, by: { $0.folderID })),
                                                rootItems: conns.filter { $0.folderID == nil },
                                                icon: "externaldrive"
                                            )
                                        }
                                    }
                                    .padding(.top, SpacingTokens.xs)
                                    .padding(.leading, SpacingTokens.xxs)
                                } label: {
                                    HStack {
                                        Text("Connections").foregroundStyle(ColorTokens.Text.secondary)
                                        Spacer()
                                        Text("\(conns.count)").foregroundStyle(ColorTokens.Text.primary)
                                    }
                                    .font(TypographyTokens.standard)
                                }
                            }.gridCellColumns(2)
                        }
                        
                        Divider().gridCellColumns(2)

                        GridRow {
                            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                                DisclosureGroup {
                                    VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                                        if identities.isEmpty {
                                            Text("No identities saved")
                                                .font(TypographyTokens.detail)
                                                .foregroundStyle(ColorTokens.Text.tertiary)
                                        } else {
                                            projectResourceTree(
                                                nodes: buildFolderNodes(from: folders.filter { $0.kind == .identities }, itemMap: Dictionary(grouping: identities, by: { $0.folderID })),
                                                rootItems: identities.filter { $0.folderID == nil },
                                                icon: "person.crop.circle"
                                            )
                                        }
                                    }
                                    .padding(.top, SpacingTokens.xs)
                                    .padding(.leading, SpacingTokens.xxs)
                                } label: {
                                    HStack {
                                        Text("Identities").foregroundStyle(ColorTokens.Text.secondary)
                                        Spacer()
                                        Text("\(identities.count)").foregroundStyle(ColorTokens.Text.primary)
                                    }
                                    .font(TypographyTokens.standard)
                                }
                            }.gridCellColumns(2)
                        }

                        Divider().gridCellColumns(2)

                        GridRow {
                            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                                DisclosureGroup {
                                    VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                                        settingsDetailRow(label: "Accent Color", value: project.projectGlobalSettings?.accentColorSource == nil ? "Inherited" : "Custom")
                                        settingsDetailRow(label: "Editor Font", value: project.projectGlobalSettings?.defaultEditorFontFamily ?? "System")
                                        settingsDetailRow(label: "Autocomplete", value: project.projectGlobalSettings?.editorEnableAutocomplete ?? true ? "On" : "Off")
                                        settingsDetailRow(label: "Line Numbers", value: project.projectGlobalSettings?.editorShowLineNumbers ?? true ? "On" : "Off")
                                    }
                                    .padding(.vertical, SpacingTokens.xs)
                                    .padding(.leading, SpacingTokens.xxs)
                                } label: {
                                    HStack {
                                        Text("Settings").foregroundStyle(ColorTokens.Text.secondary)
                                        Spacer()
                                        Text(project.projectGlobalSettings != nil ? "Customized" : "Default").foregroundStyle(ColorTokens.Text.primary)
                                    }
                                    .font(TypographyTokens.standard)
                                }
                            }.gridCellColumns(2)
                        }
                    }
                }
                .padding(.horizontal, SpacingTokens.xl2)
                .padding(.top, SpacingTokens.lg2)
                .padding(.bottom, SpacingTokens.xxxl)
            }
        }
    }

    private func appStoreInfoColumn(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            Text(label)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
            Text(value)
                .font(TypographyTokens.standard.weight(.medium))
                .foregroundStyle(ColorTokens.Text.primary)
        }
    }

    @ViewBuilder
    private func projectResourceTree<Item: Identifiable>(
        nodes: [FolderNode],
        rootItems: [Item],
        icon: String
    ) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            ForEach(nodes) { node in
                ProjectFolderNodeRow(node: node, icon: icon, level: 0)
            }
            ForEach(rootItems) { item in
                let name = (item as? SavedConnection)?.connectionName ?? (item as? SavedIdentity)?.name ?? "Unknown"
                Label(name, systemImage: icon)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .padding(.leading, SpacingTokens.xxs)
            }
        }
    }

    private func settingsDetailRow(label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(ColorTokens.Text.secondary).font(TypographyTokens.detail)
            Spacer()
            Text(value).foregroundStyle(ColorTokens.Text.primary).font(TypographyTokens.detail.weight(.medium))
        }
    }

    // MARK: - Import Settings Sheet (Granular)

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
                    
                    headerView(source: source)
                }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: SpacingTokens.md2) {
                        optionsSection
                        connectionsSection(source: source)
                        identitiesSection(source: source)
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
                footerView(source: source, targetID: targetID)
            }
        }
    }

    private func headerView(source: Project) -> some View {
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

    private var optionsSection: some View {
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

    private func connectionsSection(source: Project) -> some View {
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

    private func identitiesSection(source: Project) -> some View {
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

    private func footerView(source: Project, targetID: UUID) -> some View {
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

    // MARK: - Export / Import (Logic and Sheets)

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
            importFooterButtons
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

    private var importFooterButtons: some View {
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

// MARK: - Internal Tree View

struct ProjectFolderNodeRow: View {
    let node: FolderNode
    let icon: String
    let level: Int

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            Label(node.folder.displayName, systemImage: node.folder.icon)
                .font(TypographyTokens.detail.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.primary)
                .padding(.leading, CGFloat(level) * SpacingTokens.md)

            if let children = node.childNodes {
                ForEach(children) { child in
                    ProjectFolderNodeRow(node: child, icon: icon, level: level + 1)
                }
            }

            ForEach(node.items, id: \.self) { item in
                let name = (item as? SavedConnection)?.connectionName ?? (item as? SavedIdentity)?.name ?? "Unknown"
                Label(name, systemImage: icon)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .padding(.leading, CGFloat(level + 1) * SpacingTokens.md)
            }
        }
    }
}

// MARK: - Icon Picker Sheet

struct ProjectIconPickerSheet: View {
    let project: Project
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedIcon: String

    private let icons = [
        "folder.fill", "star.fill", "bookmark.fill", "tag.fill",
        "briefcase.fill", "desktopcomputer", "server.rack", "cylinder.fill",
        "terminal.fill", "cpu.fill", "shippingbox.fill", "archivebox.fill",
        "globe", "flask.fill", "wrench.and.screwdriver.fill", "gearshape.fill",
        "puzzlepiece.fill", "bolt.fill", "leaf.fill", "flame.fill",
        "heart.fill", "cube.fill", "tray.2.fill", "externaldrive.fill"
    ]

    init(project: Project, onSelect: @escaping (String) -> Void) {
        self.project = project
        self.onSelect = onSelect
        self._selectedIcon = State(initialValue: project.iconName ?? "folder.fill")
    }

    var body: some View {
        VStack(spacing: 0) {
            formContent
            Divider()
            footerButtons
        }
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var formContent: some View {
        Form {
            Section {
                LabeledContent("Icon") { iconPaletteView }
            } header: {
                Text("Change Icon")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .scrollDisabled(true)
    }

    private var iconPaletteView: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: SpacingTokens.xxs2) {
            ForEach(icons, id: \.self) { iconName in
                iconSwatch(name: iconName, isSelected: selectedIcon == iconName)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedIcon = iconName
                        }
                    }
            }
        }
    }

    private func iconSwatch(name: String, isSelected: Bool) -> some View {
        Image(systemName: name)
            .font(TypographyTokens.hero)
            .frame(width: 32, height: 32)
            .foregroundStyle(isSelected ? Color.white : ColorTokens.Text.secondary)
            .background(isSelected ? ColorTokens.accent : Color.clear, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
    }

    private var footerButtons: some View {
        HStack {
            Spacer()
            Button("Cancel", role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button("Done") {
                onSelect(selectedIcon)
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(SpacingTokens.md2)
    }
}
