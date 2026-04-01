import SwiftUI

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
                            environmentState.requestProjectSwitch(to: project)
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

                        if AppDirector.shared.syncEngine != nil, authState.isSignedIn {
                            Divider().gridCellColumns(2)

                            GridRow {
                                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                                    HStack {
                                        Label {
                                            Text("Cloud Sync")
                                                .foregroundStyle(ColorTokens.Text.secondary)
                                        } icon: {
                                            Image(systemName: "icloud")
                                                .foregroundStyle(ColorTokens.Text.secondary)
                                        }
                                        .font(TypographyTokens.standard)

                                        Spacer()

                                        Toggle("", isOn: syncBinding(for: project))
                                            .toggleStyle(.switch)
                                            .labelsHidden()
                                    }

                                    if project.isSyncEnabled {
                                        Text("Connections, folders, identities, and bookmarks in this project are synced to your Echo account. Passwords stay in your local Keychain.")
                                            .font(TypographyTokens.detail)
                                            .foregroundStyle(ColorTokens.Text.tertiary)
                                    }
                                }.gridCellColumns(2)
                            }
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

    private func syncBinding(for project: Project) -> Binding<Bool> {
        Binding(
            get: { project.isSyncEnabled },
            set: { newValue in
                guard var updated = projectStore.projects.first(where: { $0.id == project.id }) else { return }
                updated.isSyncEnabled = newValue
                Task {
                    try? await projectStore.updateProject(updated)
                    if newValue, let syncEngine = AppDirector.shared.syncEngine {
                        try? await syncEngine.performInitialUpload(for: updated)
                    }
                }
            }
        )
    }

    private func settingsDetailRow(label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(ColorTokens.Text.secondary).font(TypographyTokens.detail)
            Spacer()
            Text(value).foregroundStyle(ColorTokens.Text.primary).font(TypographyTokens.detail.weight(.medium))
        }
    }
}
