import SwiftUI

struct NewProjectSheet: View {
    @Environment(ProjectStore.self) private var projectStore
    @Environment(NavigationStore.self) private var navigationStore
    @Environment(\.dismiss) private var dismiss

    @State private var projectName: String = ""
    @State private var selectedIconName: String = "folder.fill"

    private let icons = [
        "folder.fill", "star.fill", "bookmark.fill", "tag.fill",
        "briefcase.fill", "desktopcomputer", "server.rack", "cylinder.fill",
        "terminal.fill", "cpu.fill", "shippingbox.fill", "archivebox.fill"
    ]

    var body: some View {
        VStack(spacing: SpacingTokens.xxxs) {
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
                TextField("Name", text: $projectName, prompt: Text("Project name"))
                LabeledContent("Icon") { iconPaletteView }
            } header: {
                Text("New Project")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .scrollDisabled(true)
    }

    private var iconPaletteView: some View {
        HStack(spacing: SpacingTokens.xxs2) {
            ForEach(icons, id: \.self) { iconName in
                iconSwatch(name: iconName, isSelected: selectedIconName == iconName)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedIconName = iconName
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func iconSwatch(name: String, isSelected: Bool) -> some View {
        Image(systemName: name)
            .font(TypographyTokens.prominent)
            .frame(width: 26, height: 26)
            .foregroundStyle(isSelected ? Color.white : ColorTokens.Text.secondary)
            .background(isSelected ? ColorTokens.accent : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
    }

    private var footerButtons: some View {
        HStack {
            Spacer()
            Button("Cancel", role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button("Create") { createProject() }
                .keyboardShortcut(.defaultAction)
                .disabled(projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(SpacingTokens.md2)
    }

    private func createProject() {
        let trimmedName = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        Task {
            do {
                let project = try await projectStore.createProject(
                    name: trimmedName,
                    colorHex: "",
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
