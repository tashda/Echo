import SwiftUI

/// Round MC: the sidebar. A project switcher on top (projects are a scope, not a page), then
/// Connections (All, Recently Used, then folders) and Identities (All, then folders). The project
/// reads like the account at the top of System Settings (R2-D, PJ2) and opens the project menu.
extension ManageConnectionsView {
    var sidebar: some View {
        List(selection: Binding(get: { scope }, set: { if let new = $0 { navigate(to: .scope(new)) } })) {
            Section("Connections") {
                Label("All Connections", systemImage: "externaldrive.connected.to.line.below")
                    .badge(projectConnections.count)
                    .tag(ManageScope.allConnections)
                    // Dropping connections here takes them out of their folder.
                    .dropDestination(for: String.self) { items, _ in
                        drop(items, kind: .connections, intoFolder: nil)
                    }
                Label("Recently Used", systemImage: "clock")
                    .badge(recentConnections.count)
                    .tag(ManageScope.recentConnections)
                folderRows(.connections)
            }
            Section("Identities") {
                Label("All Identities", systemImage: "person.crop.circle")
                    .badge(projectIdentities.count)
                    .tag(ManageScope.identities)
                    .dropDestination(for: String.self) { items, _ in
                        drop(items, kind: .identities, intoFolder: nil)
                    }
                folderRows(.identities)
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
            ProjectAccountRow(
                name: projectStore.selectedProject?.name ?? "Project",
                iconName: projectStore.selectedProject?.iconName ?? "folder.fill",
                color: projectStore.selectedProject?.color ?? ColorTokens.accent,
                detail: projectConnections.count == 1 ? "Project · 1 connection" : "Project · \(projectConnections.count) connections"
            )
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .help("Switch project, or open its settings")
    }
}

/// R2-D (PJ2): the project as an account row: a large round picture, the name, one grey line.
/// No box and no arrow; it highlights on hover like a sidebar row and opens the project menu.
struct ProjectAccountRow: View {
    let name: String
    let iconName: String
    let color: Color
    let detail: String

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: SpacingTokens.sm) {
            Image(systemName: iconName)
                .font(.system(size: ProjectAccountRowMetrics.symbolSize, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: ProjectAccountRowMetrics.pictureSize, height: ProjectAccountRowMetrics.pictureSize)
                .background(
                    Circle().fill(LinearGradient(colors: [color.opacity(0.75), color], startPoint: .top, endPoint: .bottom))
                )
            VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                Text(name)
                    .font(TypographyTokens.standard.weight(.semibold))
                    .foregroundStyle(ColorTokens.Text.primary)
                    .lineLimit(1)
                Text(detail)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: SpacingTokens.none)
        }
        .padding(.horizontal, SpacingTokens.xs)
        .padding(.vertical, SpacingTokens.xxs2)
        .background(
            RoundedRectangle(cornerRadius: SpacingTokens.xs, style: .continuous)
                .fill(isHovered ? ColorTokens.Text.primary.opacity(0.06) : Color.clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: SpacingTokens.xs, style: .continuous))
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Switch project, or open its settings")
    }
}

enum ProjectAccountRowMetrics {
    static let pictureSize: CGFloat = 36
    static let symbolSize: CGFloat = 16
}
