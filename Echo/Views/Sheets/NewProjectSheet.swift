import SwiftUI

struct NewProjectSheet: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var projectName: String = ""
    @State private var selectedColorHex: String = "007AFF"
    @State private var selectedIconName: String? = nil

    private let availableColors: [String] = [
        "007AFF", // Blue
        "34C759", // Green
        "FF9500", // Orange
        "FF3B30", // Red
        "AF52DE", // Purple
        "5AC8FA", // Teal
        "FFCC00", // Yellow
        "FF2D55", // Pink
        "5856D6", // Indigo
        "32ADE6"  // Cyan
    ]

    private let availableIcons: [String] = [
        "folder.badge.gearshape",
        "folder",
        "folder.fill",
        "square.stack.3d.up",
        "square.stack.3d.up.fill",
        "briefcase",
        "briefcase.fill",
        "building.2",
        "building.2.fill",
        "app.connected.to.app.below.fill"
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Project")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Project name
                    FormSection(title: "Project Name") {
                        TextField("Enter project name", text: $projectName)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 14))
                    }

                    // Color picker
                    FormSection(title: "Color") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                            ForEach(availableColors, id: \.self) { colorHex in
                                ColorButton(
                                    colorHex: colorHex,
                                    isSelected: selectedColorHex == colorHex,
                                    action: { selectedColorHex = colorHex }
                                )
                            }
                        }
                    }

                    // Icon picker
                    FormSection(title: "Icon (Optional)") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                            Button(action: { selectedIconName = nil }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(selectedIconName == nil ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.06))
                                    Image(systemName: "xmark")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(selectedIconName == nil ? Color.accentColor : Color.secondary)
                                }
                                .frame(height: 44)
                            }
                            .buttonStyle(.plain)

                            ForEach(availableIcons, id: \.self) { iconName in
                                IconButton(
                                    iconName: iconName,
                                    color: Color(hex: selectedColorHex) ?? .accentColor,
                                    isSelected: selectedIconName == iconName,
                                    action: { selectedIconName = iconName }
                                )
                            }
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            // Actions
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create Project") {
                    createProject()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(20)
        }
        .frame(width: 500, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func createProject() {
        let trimmedName = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let newProject = Project(
            name: trimmedName,
            colorHex: selectedColorHex,
            iconName: selectedIconName
        )

        Task {
            await appModel.createProject(newProject)
            appModel.selectedProject = newProject
            appModel.navigationState.selectProject(newProject)
            dismiss()
        }
    }
}

// MARK: - Supporting Views

private struct FormSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            content
        }
    }
}

private struct ColorButton: View {
    let colorHex: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(hex: colorHex) ?? .accentColor)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                }
            }
            .frame(height: 44)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? Color.primary.opacity(0.3) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct IconButton: View {
    let iconName: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? color.opacity(0.15) : Color.primary.opacity(0.06))

                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? color : Color.secondary)
            }
            .frame(height: 44)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? color.opacity(0.5) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
