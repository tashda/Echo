import SwiftUI

/// Round MC: projects are a scope chosen in the sidebar's switcher. Their settings live in one
/// sheet: name and icon, what is inside, sync, and the rare actions with their consequence.
extension ManageConnectionsView {
    @ViewBuilder
    var projectSettingsSheet: some View {
        if let project = projectStore.selectedProject {
            ProjectSettingsSheet(
                project: project,
                connectionCount: connectionStore.connections.filter { $0.projectID == project.id }.count,
                identityCount: connectionStore.identities.filter { $0.projectID == project.id }.count,
                showsSync: AppDirector.shared.syncEngine != nil && authState.isSignedIn,
                onChooseIcon: { afterClosingSettings { showIconPicker = true } },
                onImport: { afterClosingSettings { importSettingsSourceProject = nil; showImportSettingsPopup = true } },
                onExport: { afterClosingSettings { exportProjectID = project.id; showExportSheet = true } },
                onReset: { afterClosingSettings { showResetSettingsConfirmation = true } },
                onDelete: { afterClosingSettings { projectToDelete = project; showDeleteConfirmation = true } }
            )
            .environment(projectStore)
        }
    }

    /// Opens another sheet or alert once the settings sheet has closed.
    private func afterClosingSettings(_ action: @escaping @MainActor () -> Void) {
        isShowingProjectSettings = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            action()
        }
    }
}

private struct ProjectSettingsSheet: View {
    let project: Project
    let connectionCount: Int
    let identityCount: Int
    let showsSync: Bool
    let onChooseIcon: () -> Void
    let onImport: () -> Void
    let onExport: () -> Void
    let onReset: () -> Void
    let onDelete: () -> Void

    @Environment(ProjectStore.self) private var projectStore
    @Environment(\.dismiss) private var dismiss
    @State private var name: String

    init(project: Project, connectionCount: Int, identityCount: Int, showsSync: Bool,
         onChooseIcon: @escaping () -> Void, onImport: @escaping () -> Void, onExport: @escaping () -> Void,
         onReset: @escaping () -> Void, onDelete: @escaping () -> Void) {
        self.project = project
        self.connectionCount = connectionCount
        self.identityCount = identityCount
        self.showsSync = showsSync
        self.onChooseIcon = onChooseIcon
        self.onImport = onImport
        self.onExport = onExport
        self.onReset = onReset
        self.onDelete = onDelete
        _name = State(initialValue: project.name)
    }

    var body: some View {
        VStack(spacing: SpacingTokens.none) {
            HStack {
                Text("Project Settings")
                    .font(TypographyTokens.standard.weight(.semibold))
                Spacer()
                Button("Done") { saveName(); dismiss() }
                    .buttonStyle(.glassProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, SpacingTokens.md)
            .padding(.top, SpacingTokens.sm)

            Form {
                Section {
                    HStack(spacing: SpacingTokens.sm) {
                        Button(action: onChooseIcon) {
                            Image(systemName: project.iconName ?? "folder.fill")
                                .font(.system(size: SpacingTokens.md2, weight: .semibold))
                                .foregroundStyle(project.color)
                                .frame(width: SpacingTokens.xl2, height: SpacingTokens.xl2)
                                .background(project.color.opacity(0.15), in: RoundedRectangle(cornerRadius: SpacingTokens.sm, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .help("Change the icon")
                        TextField("", text: $name, prompt: Text("Project name"))
                            .textFieldStyle(.plain)
                            .font(TypographyTokens.title3.weight(.semibold))
                            .onSubmit(saveName)
                    }
                    if project.isDefault {
                        Text("The default project")
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                }

                Section("Contents") {
                    LabeledContent("Connections", value: "\(connectionCount)")
                    LabeledContent("Identities", value: "\(identityCount)")
                }

                if showsSync {
                    Section {
                        Toggle("Sync this project", isOn: syncBinding)
                    } footer: {
                        Text("Connections, identities and bookmarks sync to your Echo account. Passwords stay in your Keychain.")
                    }
                }

                Section("Move Things") {
                    Button("Import from Another Project…", action: onImport)
                    Button("Export “\(project.name)”…", action: onExport)
                }

                Section {
                    Button("Reset Settings…", action: onReset)
                    if !project.isDefault {
                        Button("Delete Project…", role: .destructive, action: onDelete)
                    }
                } footer: {
                    Text(project.isDefault
                         ? "Reset puts this project's settings back to Echo's defaults; connections and identities stay. The default project can't be deleted."
                         : "Reset puts this project's settings back to Echo's defaults; connections and identities stay. Deleting removes the project with its \(connectionCount) connections and \(identityCount) identities.")
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(width: 460)
        .frame(minHeight: 420, idealHeight: 520)
    }

    private func saveName() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != project.name,
              var updated = projectStore.projects.first(where: { $0.id == project.id }) else { return }
        updated.name = trimmed
        updated.updatedAt = Date()
        Task { try? await projectStore.updateProject(updated) }
    }

    private var syncBinding: Binding<Bool> {
        Binding(
            get: { projectStore.projects.first(where: { $0.id == project.id })?.isSyncEnabled ?? project.isSyncEnabled },
            set: { newValue in
                guard var updated = projectStore.projects.first(where: { $0.id == project.id }) else { return }
                updated.isSyncEnabled = newValue
                Task {
                    try? await projectStore.updateProject(updated)
                    if newValue, let syncEngine = AppDirector.shared.syncEngine {
                        try? await syncEngine.performInitialUpload(for: updated, strategy: .merge)
                    }
                }
            }
        )
    }
}
