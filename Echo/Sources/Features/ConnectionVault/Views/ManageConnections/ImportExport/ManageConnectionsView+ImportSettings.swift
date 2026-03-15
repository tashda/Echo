import SwiftUI

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

    func granularImportContent(source: Project) -> some View {
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

    func importHeaderView(source: Project) -> some View {
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

    var importOptionsSection: some View {
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
}
