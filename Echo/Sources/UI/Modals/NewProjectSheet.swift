import SwiftUI

struct NewProjectSheet: View {
    @Environment(ProjectStore.self) private var projectStore
    @Environment(NavigationStore.self) private var navigationStore
    @Environment(\.dismiss) private var dismiss

    @State private var projectName: String = ""
    @State private var selectedColorHex: String = "007AFF"
    @State private var selectedIconName: String? = "folder.fill"

    private let colors = [
        "007AFF", "5856D6", "AF52DE", "FF2D55", "FF3B30",
        "FF9500", "FFCC00", "34C759", "5AC8FA", "8E8E93"
    ]

    private let icons = [
        "folder.fill", "star.fill", "bookmark.fill", "tag.fill",
        "briefcase.fill", "desktopcomputer", "server.rack", "database.fill",
        "terminal.fill", "cpu.fill", "shippingbox.fill", "archivebox.fill"
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            form
            Divider()
            footer
        }
        .frame(width: 440)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("New Project")
                    .font(.system(size: 18, weight: .bold))
                Text("Create a workspace to organize your database connections.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hex: selectedColorHex)?.opacity(0.15) ?? .blue.opacity(0.15))
                Image(systemName: selectedIconName ?? "folder.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color(hex: selectedColorHex) ?? .blue)
            }
            .frame(width: 48, height: 48)
        }
        .padding(24)
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("NAME")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                    TextField("Project Name", text: $projectName)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.large)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("COLOR")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(colors, id: \.self) { hex in
                            ColorButton(hex: hex, isSelected: selectedColorHex == hex) {
                                selectedColorHex = hex
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("ICON")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(icons, id: \.self) { icon in
                            IconButton(icon: icon, isSelected: selectedIconName == icon, color: Color(hex: selectedColorHex) ?? .blue) {
                                selectedIconName = icon
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Spacer()
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            
            Button("Create Project") {
                createProject()
            }
            .buttonStyle(.borderedProminent)
            .disabled(projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    private func createProject() {
        let trimmedName = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        Task {
            do {
                let project = try await projectStore.createProject(
                    name: trimmedName,
                    colorHex: selectedColorHex,
                    iconName: selectedIconName
                )
                
                projectStore.selectProject(project)
                navigationStore.selectProject(project)
                dismiss()
            } catch {
                print("Failed to create project: \(error)")
            }
        }
    }
}

private struct ColorButton: View {
    let hex: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(hex: hex) ?? .blue)
                    .frame(width: 24, height: 24)
                if isSelected {
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.3), lineWidth: 2)
                        .frame(width: 32, height: 32)
                }
            }
            .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
    }
}

private struct IconButton: View {
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? color.opacity(0.15) : Color.primary.opacity(0.05))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? color : .secondary)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? color.opacity(0.5) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
