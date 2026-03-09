import SwiftUI

extension ManageProjectsView {
    @ViewBuilder
    func projectDetails(_ project: Project) -> some View {
        let connectionCount = connectionStore.connections.filter { $0.projectID == project.id }.count
        let identityCount = connectionStore.identities.filter { $0.projectID == project.id }.count

        Form {
            // MARK: - Project Summary (iCloud-style header)
            Section {
                // Header: name + subtitle on left, icon on right
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(project.name)
                            .font(.system(size: 22, weight: .bold))

                        if project.isDefault {
                            Text("Default Project")
                                .font(TypographyTokens.prominent)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Button {
                        showIconPicker = true
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.quaternary.opacity(0.5))
                            Image(systemName: project.iconName ?? "folder.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 48, height: 48)
                    }
                    .buttonStyle(.plain)
                    .help("Change Icon")
                }
                .padding(.bottom, SpacingTokens.xxs2)

                // Stats grid
                HStack(spacing: SpacingTokens.sm) {
                    projectStatCard(
                        icon: "externaldrive",
                        iconColor: .blue,
                        title: "Connections",
                        value: "\(connectionCount)"
                    )

                    projectStatCard(
                        icon: "person.crop.circle",
                        iconColor: .purple,
                        title: "Identities",
                        value: "\(identityCount)"
                    )
                }

                // Dates
                HStack {
                    Text("Created \(project.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    Text("·")
                    Text("Modified \(project.updatedAt.formatted(date: .abbreviated, time: .omitted))")
                    Spacer()
                }
                .font(TypographyTokens.detail)
                .foregroundStyle(.tertiary)
            }

            // MARK: - Settings
            Section("Settings") {
                VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
                    LabeledContent("Import from Project") {
                        if isImportingSettings {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Menu {
                                let otherProjects = projectStore.projects.filter { $0.id != project.id }
                                if otherProjects.isEmpty {
                                    Text("No Other Projects")
                                } else {
                                    ForEach(otherProjects) { source in
                                        Button(source.name) {
                                            importSettingsFromProject(source, into: project.id)
                                        }
                                    }
                                }
                            } label: {
                                Text("Choose Project…")
                            }
                        }
                    }

                    if let imported = lastImportedFrom {
                        Text("Imported from \(imported.name) \(imported.date.formatted(date: .abbreviated, time: .omitted))")
                            .font(TypographyTokens.detail)
                            .foregroundStyle(.secondary)
                    }
                }

                LabeledContent("Factory Defaults") {
                    Button("Reset All Settings") {
                        showResetSettingsConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private func importSettingsFromProject(_ source: Project, into targetID: UUID) {
        isImportingSettings = true
        lastImportedFrom = nil
        Task {
            try? await projectStore.importSettings(from: source, into: targetID)
            isImportingSettings = false
            lastImportedFrom = (name: source.name, date: Date())
        }
    }

    private func projectStatCard(icon: String, iconColor: Color, title: String, value: String) -> some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: icon)
                .font(TypographyTokens.display)
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(TypographyTokens.standard)
                Text(value)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SpacingTokens.sm)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.quaternary.opacity(0.5))
        )
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
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 6) {
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
            .font(.system(size: 14))
            .frame(width: 26, height: 26)
            .foregroundStyle(isSelected ? Color.white : .secondary)
            .background(isSelected ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 6))
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
