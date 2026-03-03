import SwiftUI
import Combine
#if os(macOS)
import AppKit
#endif

// Simple NavigationSplitView-based settings - no complex navigation bridge needed

// Clean NavigationSplitView-based settings window

/// Hosts the sidebar/detail split view and renders each settings section.
struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var clipboardHistory: ClipboardHistoryStore
    @EnvironmentObject private var themeManager: ThemeManager

    enum SettingsSection: String, CaseIterable, Identifiable {
        case appearance
        case queryResults
        case echoSense
        case diagrams
        case applicationCache
        case keyboardShortcuts

        var id: String { rawValue }

        var title: String {
            switch self {
            case .appearance: return "Appearance"
            case .queryResults: return "Query Results"
            case .echoSense: return "EchoSense"
            case .diagrams: return "Diagrams"
            case .applicationCache: return "Application Cache"
            case .keyboardShortcuts: return "Keyboard Shortcuts"
            }
        }

        var systemImage: String? {
            switch self {
            case .appearance: return "paintbrush"
            case .queryResults: return "tablecells"
            case .diagrams: return "rectangle.connected.to.line.below"
            case .applicationCache: return "internaldrive"
            case .keyboardShortcuts: return "command"
            case .echoSense: return nil
            }
        }

        var assetImageName: String? {
            switch self {
            case .echoSense:
                return "bulb.bolt"
            default:
                return nil
            }
        }
    }

    @State private var selection: SettingsSection? = .appearance

    /// Fixed sidebar width based on the longest section title.
    /// We approximate character width to keep the list comfortably sized.
    private var sidebarColumnWidth: CGFloat {
        let longestTitle = SettingsSection.allCases
            .map(\.title)
            .max(by: { $0.count < $1.count }) ?? "Settings"

        // Rough character width + space for icon and padding.
        let approximateWidth = CGFloat(longestTitle.count) * 8.0 + 80.0
        // Clamp to a sensible range so it doesn't look extreme on different systems.
        return min(max(approximateWidth, 200), 260)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(SettingsSection.allCases) { section in
                    Label {
                        Text(section.title)
                    } icon: {
                        iconView(for: section)
                    }
                    .tag(section)
                }
            }
            .listStyle(.sidebar)
//            .toolbar(removing: .sidebarToggle)
            //.toolbar(.hidden, for: .windowToolbar)
        } detail: {
            Group {
                if let selection {
                    sectionView(for: selection)
                        .id(selection)
                        .frame(minWidth: 560, minHeight: 420)
                } else {
                    ContentUnavailableView {
                        Label("Select a Section", systemImage: "slider.horizontal.3")
                    } description: {
                        Text("Choose a settings category to view its options.")
                    }
                }
            }
            .navigationTitle(selection?.title ?? "Settings")
            .toolbarTitleDisplayMode(.automatic)
        }
        // Remove the standard "Hide Sidebar" toggle and pin the sidebar width.
        .toolbar(removing: .sidebarToggle)
        .navigationSplitViewColumnWidth(min: sidebarColumnWidth,
                                        ideal: sidebarColumnWidth,
                                        max: sidebarColumnWidth)
        .toolbar(removing: .sidebarToggle)
        .preferredColorScheme(themeManager.effectiveColorScheme)
        .accentColor(themeManager.accentColor)
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsSection)) { notification in
            guard let raw = notification.object as? String,
                  let section = SettingsSection(rawValue: raw) else { return }
            selection = section
        }
#if os(macOS)
        .onAppear(perform: configureSettingsWindowIdentifier)
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

#if os(macOS)
    @ViewBuilder
    private func iconView(for section: SettingsSection) -> some View {
        if let systemName = section.systemImage {
            Image(systemName: systemName)
        } else if let assetName = section.assetImageName {
            Image(assetName)
                .renderingMode(.template)
        } else {
            Image(systemName: "square")
        }
    }
#else
    @ViewBuilder
    private func iconView(for section: SettingsSection) -> some View {
        if let systemName = section.systemImage {
            Image(systemName: systemName)
        } else if let assetName = section.assetImageName {
            Image(assetName)
                .renderingMode(.template)
        } else {
            Image(systemName: "square")
        }
    }
#endif

    // Simple NavigationSplitView - no manual navigation needed
}

#if os(macOS)
private func configureSettingsWindowIdentifier() {
    DispatchQueue.main.async {
        guard let window = NSApp?.keyWindow else { return }
        if window.identifier != AppWindowIdentifier.settings {
            window.identifier = AppWindowIdentifier.settings
        }
    }
}
#endif

#Preview("Settings Window") {
    SettingsView()
        .environmentObject(AppCoordinator.shared.appModel)
        .environmentObject(AppCoordinator.shared.appState)
        .environmentObject(AppCoordinator.shared.clipboardHistory)
        .environmentObject(ThemeManager.shared)
}

// VisualEffectView removed - using simple navigationTitle instead

extension Notification.Name {
    static let openSettingsSection = Notification.Name("com.fuzee.settings.openSection")
}
