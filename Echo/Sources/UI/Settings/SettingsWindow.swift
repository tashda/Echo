import SwiftUI
import Foundation
import Combine
#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Primary settings scene built with a native `NavigationSplitView`.
struct SettingsWindow: Scene {
    static let sceneID = "settings"

    var body: some Scene {
        Window("Settings", id: Self.sceneID) {
            SettingsView()
                .environmentObject(AppCoordinator.shared.appModel)
                .environmentObject(AppCoordinator.shared.appState)
                .environmentObject(AppCoordinator.shared.clipboardHistory)
                .environmentObject(ThemeManager.shared)
        }
        .defaultSize(width: 720, height: 520)
    }
}

/// Hosts the sidebar/detail split view and renders each settings section.
struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var clipboardHistory: ClipboardHistoryStore
    @EnvironmentObject private var themeManager: ThemeManager

    enum SettingsSection: String, CaseIterable, Identifiable {
        case appearance
        case queryResults
        case autocomplete
        case diagrams
        case applicationCache
        case keyboardShortcuts

        var id: String { rawValue }

        var title: String {
            switch self {
            case .appearance: return "Appearance"
            case .queryResults: return "Query Results"
            case .autocomplete: return "Autocomplete"
            case .diagrams: return "Diagrams"
            case .applicationCache: return "Application Cache"
            case .keyboardShortcuts: return "Keyboard Shortcuts"
        }
        }

        var systemImage: String {
            switch self {
            case .appearance: return "paintbrush"
            case .queryResults: return "tablecells"
            case .autocomplete: return "text.insert"
            case .diagrams: return "rectangle.connected.to.line.below"
            case .applicationCache: return "internaldrive"
            case .keyboardShortcuts: return "command"
        }
        }
    }

#if os(macOS)
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
#endif
    @State private var preferredColumn: NavigationSplitViewColumn = .sidebar
    @State private var selection: SettingsSection? = .appearance
    @State private var navigationHistory: [SettingsSection] = [.appearance]
    @State private var historyIndex: Int = 0
    @State private var isUpdatingFromHistory = false

    var body: some View {
        settingsSplitView
        .frame(minWidth: 720, minHeight: 520)
        .onAppear {
            if selection == nil {
                selection = .appearance
            }
#if os(macOS)
            columnVisibility = .all
#endif
            navigationHistory = [.appearance]
            historyIndex = 0
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsSection)) { notification in
            guard let raw = notification.object as? String,
                  let section = SettingsSection(rawValue: raw) else { return }
            selection = section
            preferredColumn = .sidebar
#if os(macOS)
            columnVisibility = .all
#endif
        }
        .onChange(of: selection) { _, newValue in
            guard !isUpdatingFromHistory else {
                isUpdatingFromHistory = false
                return
            }
            guard let newValue else { return }
            if historyIndex < navigationHistory.count - 1 {
                navigationHistory = Array(navigationHistory.prefix(historyIndex + 1))
            }
            navigationHistory.append(newValue)
            historyIndex = navigationHistory.count - 1
        }
        .accentColor(themeManager.accentColor)
        .preferredColorScheme(themeManager.effectiveColorScheme)
        .background(themeManager.windowBackground)
    }

    @ViewBuilder
    private var settingsSplitView: some View {
#if os(macOS)
        NavigationSplitView(columnVisibility: $columnVisibility, preferredCompactColumn: $preferredColumn) {
            sidebar
        } detail: {
            detailContent
        }
        .toolbar(removing: .sidebarToggle)
        .toolbarBackground(.hidden, for: .windowToolbar)
        .background(
            TitlebarAccessoryBridge(
                title: selection?.title ?? "Settings",
                canNavigateBack: canNavigateBack,
                canNavigateForward: canNavigateForward,
                onNavigateBack: navigateBack,
                onNavigateForward: navigateForward
            )
        )
#else
        NavigationSplitView(preferredCompactColumn: $preferredColumn) {
            sidebar
        } detail: {
            detailContent
        }
#endif
    }

    private var sidebar: some View {
        List(selection: $selection) {
            ForEach(SettingsSection.allCases) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
        }
        .navigationTitle("Settings")
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: fixedSidebarWidth, ideal: fixedSidebarWidth, max: fixedSidebarWidth)
#if os(macOS)
        .background(Color.clear)
#else
        .scrollContentBackground(.hidden)
        .background(themeManager.surfaceBackgroundColor)
#endif
    }

    private var detailContent: some View {
        NavigationStack {
            Group {
                if let selection {
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
        .frame(minWidth: 560, minHeight: 420)
        .background(themeManager.surfaceBackgroundColor)
        .toolbar {
#if os(macOS)
            ToolbarItemGroup(placement: .navigation) {
                Button(action: navigateBack, label: {
                    Image(systemName: "chevron.left")
                })
                .disabled(!canNavigateBack)

                Button(action: navigateForward, label: {
                    Image(systemName: "chevron.right")
                })
                .disabled(!canNavigateForward)
            }
            ToolbarItem(placement: .principal) {
                Text(selection?.title ?? "Settings")
                    .font(.system(size: 28, weight: .bold))
            }
#endif
        }
#if os(macOS)
        .toolbar(removing: .sidebarToggle)
        .toolbarBackground(.visible, for: .windowToolbar)
        .toolbarBackground(.ultraThinMaterial, for: .windowToolbar)
#endif
    }

    @ViewBuilder
    private func sectionView(for section: SettingsSection) -> some View {
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

        case .autocomplete:
            AutocompleteSettingsView()
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


#if os(macOS)
    private var canNavigateBack: Bool {
        historyIndex > 0
    }

    private var canNavigateForward: Bool {
        historyIndex + 1 < navigationHistory.count
    }

    private func navigateBack() {
        guard canNavigateBack else { return }
        historyIndex -= 1
        isUpdatingFromHistory = true
        selection = navigationHistory[historyIndex]
    }

    private func navigateForward() {
        guard canNavigateForward else { return }
        historyIndex += 1
        isUpdatingFromHistory = true
        selection = navigationHistory[historyIndex]
    }

    private var fixedSidebarWidth: CGFloat { 280 }
#else
    private var canNavigateBack: Bool { historyIndex > 0 }
    private var canNavigateForward: Bool { historyIndex + 1 < navigationHistory.count }
    private func navigateBack() { if canNavigateBack { historyIndex -= 1; isUpdatingFromHistory = true; selection = navigationHistory[historyIndex] } }
    private func navigateForward() { if canNavigateForward { historyIndex += 1; isUpdatingFromHistory = true; selection = navigationHistory[historyIndex] } }
    private var fixedSidebarWidth: CGFloat { 280 }
#endif
}

#Preview("Settings Window") {
    SettingsView()
}

extension Notification.Name {
    static let openSettingsSection = Notification.Name("com.fuzee.settings.openSection")
}

#if os(macOS)
private struct TitlebarAccessoryBridge: NSViewRepresentable {
    let title: String
    let canNavigateBack: Bool
    let canNavigateForward: Bool
    let onNavigateBack: () -> Void
    let onNavigateForward: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            context.coordinator.update(window: view.window, state: currentState)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.update(window: nsView.window, state: currentState)
        }
    }

    private var currentState: TitlebarState {
        TitlebarState(
            title: title,
            canNavigateBack: canNavigateBack,
            canNavigateForward: canNavigateForward,
            onNavigateBack: onNavigateBack,
            onNavigateForward: onNavigateForward
        )
    }

    final class Coordinator {
        private var accessoryController: NSTitlebarAccessoryViewController?

        func update(window: NSWindow?, state: TitlebarState) {
            guard let window else { return }

            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.toolbarStyle = .unified
            window.toolbar?.showsBaselineSeparator = false
            window.toolbar?.allowsExtensionItems = false
            window.toolbar?.displayMode = .iconOnly
            window.toolbar?.sizeMode = .regular

            let content = TitlebarAccessoryView(state: state)

            if let hosting = accessoryController?.view as? NSHostingView<TitlebarAccessoryView> {
                hosting.rootView = content
                hosting.layoutSubtreeIfNeeded()
                return
            }

            let hosting = NSHostingView(rootView: content)
            hosting.translatesAutoresizingMaskIntoConstraints = false

            let controller = NSTitlebarAccessoryViewController()
            controller.layoutAttribute = .left
            controller.view = hosting
            controller.fullScreenMinHeight = 44

            accessoryController = controller
            window.addTitlebarAccessoryViewController(controller)
        }
    }
}

private struct TitlebarState: Equatable {
    var title: String
    var canNavigateBack: Bool
    var canNavigateForward: Bool
    var onNavigateBack: () -> Void
    var onNavigateForward: () -> Void
}

private struct TitlebarAccessoryView: View {
    let state: TitlebarState

    var body: some View {
        HStack(spacing: 10) {
            titlebarButton(systemName: "chevron.left", isEnabled: state.canNavigateBack, action: state.onNavigateBack)
            titlebarButton(systemName: "chevron.right", isEnabled: state.canNavigateForward, action: state.onNavigateForward)
            Text(state.title)
                .font(.system(size: 22, weight: .semibold))
                .padding(.leading, 3)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(minWidth: 320, alignment: .leading)
    }

    @ViewBuilder
    private func titlebarButton(systemName: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 24, height: 22)
        }
        .buttonStyle(.borderless)
        .disabled(!isEnabled)
        .foregroundStyle(isEnabled ? Color.primary : Color.primary.opacity(0.4))
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(isEnabled ? 0.12 : 0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.primary.opacity(isEnabled ? 0.2 : 0.08), lineWidth: 1)
        )
    }
}
#endif
