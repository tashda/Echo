import SwiftUI

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
                PropertyRow(title: "Icon") { iconPaletteView }
            } header: {
                Text("Change Icon")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .scrollDisabled(true)
    }

    private var iconPaletteView: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: SpacingTokens.xxs2) {
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
            .font(TypographyTokens.hero)
            .frame(width: 32, height: 32)
            .foregroundStyle(isSelected ? Color.white : ColorTokens.Text.secondary)
            .background(isSelected ? ColorTokens.accent : Color.clear, in: RoundedRectangle(cornerRadius: 8))
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
            .buttonStyle(.bordered)
            .keyboardShortcut(.defaultAction)
        }
        .padding(SpacingTokens.md2)
    }
}
