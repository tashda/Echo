import SwiftUI

/// Round MC: the sidebar. A project switcher on top (projects are a scope, not a page), then
/// Connections (All, Recently Used) and Identities. No folders.
extension ManageConnectionsView {
    var sidebar: some View {
        List(selection: Binding(get: { scope }, set: { if let new = $0 { navigate(to: .scope(new)) } })) {
            Section("Connections") {
                Label("All Connections", systemImage: "externaldrive.connected.to.line.below")
                    .badge(projectConnections.count)
                    .tag(ManageScope.allConnections)
                Label("Recently Used", systemImage: "clock")
                    .badge(recentConnections.count)
                    .tag(ManageScope.recentConnections)
            }
            Section("Identities") {
                Label("All Identities", systemImage: "person.crop.circle")
                    .badge(projectIdentities.count)
                    .tag(ManageScope.identities)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top, spacing: SpacingTokens.none) {
            projectSwitcher
                .padding(.horizontal, SpacingTokens.sm)
                .padding(.bottom, SpacingTokens.xs)
        }
    }

    // MARK: - Project switcher

    private var projectSwitcher: some View {
        Menu {
            Section("Projects") {
                ForEach(projectStore.projects) { project in
                    Toggle(isOn: Binding(
                        get: { projectStore.selectedProject?.id == project.id },
                        set: { if $0 { environmentState.requestProjectSwitch(to: project) } }
                    )) {
                        Label(project.name, systemImage: project.iconName ?? "folder.fill")
                    }
                }
            }
            Divider()
            Button("New Project…") { isPresentingNewProjectSheet = true }
            Button("Project Settings…") { isShowingProjectSettings = true }
            Divider()
            Button("Import from Another Project…") {
                importSettingsSourceProject = nil
                showImportSettingsPopup = true
            }
            Button("Export “\(projectStore.selectedProject?.name ?? "Project")”…") {
                exportProjectID = projectStore.selectedProject?.id
                showExportSheet = true
            }
        } label: {
            HStack(spacing: SpacingTokens.xs) {
                Image(systemName: projectStore.selectedProject?.iconName ?? "folder.fill")
                    .foregroundStyle(projectStore.selectedProject?.color ?? ColorTokens.accent)
                    .frame(width: SpacingTokens.md2)
                VStack(alignment: .leading, spacing: SpacingTokens.none) {
                    Text(projectStore.selectedProject?.name ?? "Project")
                        .font(TypographyTokens.standard.weight(.semibold))
                        .foregroundStyle(ColorTokens.Text.primary)
                        .lineLimit(1)
                    Text("\(projectConnections.count) connections · \(projectIdentities.count) identities")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: SpacingTokens.xxs)
                Image(systemName: "chevron.up.chevron.down")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .padding(.horizontal, SpacingTokens.xs)
            .padding(.vertical, SpacingTokens.xxs2)
            .background(ColorTokens.Text.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: SpacingTokens.xs, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: SpacingTokens.xs, style: .continuous))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .help("Switch project, or open its settings")
    }
}
