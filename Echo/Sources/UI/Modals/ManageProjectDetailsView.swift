import SwiftUI

extension ManageProjectsSheet {
    @ViewBuilder
    func projectDetails(_ project: Project) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Project header
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(project.color.opacity(0.15))
                        switch project.iconRenderInfo {
                        case let (image, true):
                            image
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundStyle(project.color)
                        case let (image, false):
                            image
                                .resizable()
                                .scaledToFit()
                                .padding(SpacingTokens.xs2)
                        }
                    }
                    .frame(width: 64, height: 64)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(project.name)
                            .font(.system(size: 24, weight: .bold))

                        if project.isDefault {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(TypographyTokens.caption2)
                                Text("Default Project")
                                    .font(TypographyTokens.caption2.weight(.medium))
                            }
                            .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if projectStore.selectedProject?.id == project.id {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("Active")
                                .font(TypographyTokens.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Divider()

                // Statistics
                VStack(alignment: .leading, spacing: 16) {
                    Text("Statistics")
                        .font(TypographyTokens.prominent.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 20) {
                        StatCard(
                            icon: "externaldrive",
                            count: connectionStore.connections.filter { $0.projectID == project.id }.count,
                            label: "Connections",
                            color: .blue
                        )

                        StatCard(
                            icon: "person.crop.circle",
                            count: connectionStore.identities.filter { $0.projectID == project.id }.count,
                            label: "Identities",
                            color: .purple
                        )

                        StatCard(
                            icon: "folder",
                            count: connectionStore.folders.filter { $0.projectID == project.id }.count,
                            label: "Folders",
                            color: .orange
                        )
                    }
                }

                Divider()

                // Actions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Actions")
                        .font(TypographyTokens.prominent.weight(.semibold))
                        .foregroundStyle(.secondary)

                    VStack(spacing: 8) {
                        if projectStore.selectedProject?.id != project.id {
                            Button(action: {
                                projectStore.selectProject(project)
                                navigationStore.selectProject(project)
                            }) {
                                HStack {
                                    Image(systemName: "arrow.right.circle.fill")
                                    Text("Switch to This Project")
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity)
                                .padding(SpacingTokens.sm)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(project.color.opacity(0.1))
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        Button(action: { showExportSheet = true }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Export Project")
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(SpacingTokens.sm)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.primary.opacity(0.06))
                            )
                        }
                        .buttonStyle(.plain)

                        if !project.isDefault {
                            Button(action: {
                                projectToDelete = project
                                showDeleteConfirmation = true
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Delete Project")
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity)
                                .padding(SpacingTokens.sm)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.red.opacity(0.1))
                                )
                                .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Divider()

                // Metadata
                VStack(alignment: .leading, spacing: 8) {
                    Text("Details")
                        .font(TypographyTokens.prominent.weight(.semibold))
                        .foregroundStyle(.secondary)

                    MetadataRow(label: "Created", value: project.createdAt.formatted(date: .abbreviated, time: .shortened))
                    MetadataRow(label: "Last Modified", value: project.updatedAt.formatted(date: .abbreviated, time: .shortened))
                }
            }
            .padding(SpacingTokens.md2)
        }
    }
}

