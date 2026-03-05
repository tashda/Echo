import SwiftUI

extension ManageProjectsSheet {
    var projectsList: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Projects")
                    .font(TypographyTokens.prominent.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: { isPresentingNewProjectSheet = true }) {
                    Image(systemName: "plus")
                        .font(TypographyTokens.caption2.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
            .padding(.horizontal, SpacingTokens.md)
            .padding(.vertical, SpacingTokens.sm)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // List
            List(selection: $selectedProjectID) {
                ForEach(projectStore.projects) { project in
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
                        .font(TypographyTokens.caption2.weight(.medium))
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                Spacer()
            }
            .padding(SpacingTokens.sm)
            .background(Color(nsColor: .controlBackgroundColor))
        }
    }
}

struct ProjectRow: View {
    let project: Project

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(project.color.opacity(0.15))
                switch project.iconRenderInfo {
                case let (image, true):
                    image
                        .font(TypographyTokens.display.weight(.semibold))
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
                    .font(TypographyTokens.standard.weight(.medium))

                if project.isDefault {
                    Text("Default")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, SpacingTokens.xxs)
    }
}
