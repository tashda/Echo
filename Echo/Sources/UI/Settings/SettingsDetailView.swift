import SwiftUI

struct SettingsDetailView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var clipboardHistory: ClipboardHistoryStore
    @EnvironmentObject private var themeManager: ThemeManager

    @EnvironmentObject private var model: SettingsSelectionModel

    let toolbarBridge: SettingsNavigationBridge

    var body: some View {
        detailBaseContent
            .frame(minWidth: 560, minHeight: 420)
            .background(themeManager.surfaceBackgroundColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onAppear {
                toolbarBridge.performBack = { model.navigateBack() }
                toolbarBridge.performForward = { model.navigateForward() }
                syncToolbarState()
            }
            .onReceive(NotificationCenter.default.publisher(for: .openSettingsSection)) { notification in
                guard let raw = notification.object as? String,
                      let section = SettingsView.SettingsSection(rawValue: raw) else { return }
                model.setSelection(section)
            }
            .onChange(of: model.selection) { _, _ in
                syncToolbarState()
            }
            .onChange(of: model.historyIndex) { _, _ in
                syncToolbarState()
            }
            .accentColor(themeManager.accentColor)
            .preferredColorScheme(themeManager.effectiveColorScheme)
            .background(themeManager.windowBackground)
    }

    private func syncToolbarState() {
        let currentTitle = model.selection?.title ?? "Settings"
        let back = model.canNavigateBack
        let forward = model.canNavigateForward
        let bridge = toolbarBridge
        DispatchQueue.main.async {
            bridge.title = currentTitle
            bridge.canNavigateBack = back
            bridge.canNavigateForward = forward
        }
    }

    @ViewBuilder
    private var detailBaseContent: some View {
        Group {
            if let selection = model.selection {
                sectionView(for: selection)
                    .id(selection)
            } else {
                ContentUnavailableView {
                    Label("Select a Section", systemImage: "slider.horizontal.3")
                } description: {
                    Text("Choose a settings category to view its options.")
                }
            }
        }
    }

    @ViewBuilder
    private func sectionView(for section: SettingsView.SettingsSection) -> some View {
        switch section {
        case .appearance:
            AppearanceSettingsView()
                .environmentObject(appModel)
                .environmentObject(appState)
                .environmentObject(themeManager)

        case .queryResults:
            QueryResultsSettingsView()
                .environmentObject(appModel)
                .environmentObject(appState)
                .environmentObject(themeManager)

        case .echoSense:
            EchoSenseSettingsView()
                .environmentObject(appModel)
                .environmentObject(appState)
                .environmentObject(themeManager)

        case .diagrams:
            DiagramSettingsView()
                .environmentObject(appModel)
                .environmentObject(themeManager)

        case .applicationCache:
            ApplicationCacheSettingsView()
                .environmentObject(clipboardHistory)

        case .keyboardShortcuts:
            KeyboardShortcutsSettingsView()
        }
    }
}
