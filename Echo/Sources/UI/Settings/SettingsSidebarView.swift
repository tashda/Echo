import SwiftUI

struct SettingsSidebarView: View {
    @EnvironmentObject private var model: SettingsSelectionModel
    @EnvironmentObject private var themeManager: ThemeManager

    private let fixedSidebarWidth: CGFloat = 280

    var body: some View {
        List(selection: Binding(
            get: { model.selection },
            set: { model.setSelection($0) }
        )) {
            ForEach(SettingsView.SettingsSection.allCases) { section in
                Label {
                    Text(section.title)
                } icon: {
                    iconView(for: section)
                }
                .tag(section)
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: fixedSidebarWidth, idealWidth: fixedSidebarWidth, maxWidth: fixedSidebarWidth)
        .frame(maxHeight: .infinity, alignment: .top)
#if os(macOS)
        .background(Color.clear)
#else
        .scrollContentBackground(.hidden)
        .background(themeManager.surfaceBackgroundColor)
#endif
    }

    @ViewBuilder
    private func iconView(for section: SettingsView.SettingsSection) -> some View {
        if let systemName = section.systemImage {
            Image(systemName: systemName)
        } else if let assetName = section.assetImageName {
            Image(assetName)
                .renderingMode(.template)
        } else {
            Image(systemName: "square")
        }
    }
}
