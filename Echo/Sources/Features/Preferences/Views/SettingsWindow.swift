import SwiftUI
import Combine
import AppKit

// Simple NavigationSplitView-based settings - no complex navigation bridge needed

// Clean NavigationSplitView-based settings window

/// Hosts the sidebar/detail split view and renders each settings section.
struct SettingsView: View {
    @EnvironmentObject private var environmentState: EnvironmentState
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var clipboardHistory: ClipboardHistoryStore
    @EnvironmentObject private var appearanceStore: AppearanceStore

    enum SettingsSection: String, CaseIterable, Identifiable {
        case general
        case appearance
        case databases
        case sidebar
        case queryResults
        case echoSense
        case diagrams
        case applicationCache
        case keyboardShortcuts

        var id: String { rawValue }

        var title: String {
            switch self {
            case .general: return "General"
            case .appearance: return "Appearance"
            case .databases: return "Databases"
            case .sidebar: return "Sidebar"
            case .queryResults: return "Results"
            case .echoSense: return "EchoSense"
            case .diagrams: return "Diagrams"
            case .applicationCache: return "Application Cache"
            case .keyboardShortcuts: return "Keyboard Shortcuts"
            }
        }

        var systemImage: String? {
            switch self {
            case .general: return "gear"
            case .appearance: return "paintbrush"
            case .databases: return "externaldrive.connected.to.line.below"
            case .sidebar: return "sidebar.left"
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
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
            // FIXME: macOS 26 (Tahoe) bug — .toolbar(removing: .sidebarToggle) has no effect
            // when applied to the NavigationSplitView or detail content. Applying it to the
            // sidebar content does remove the button, but breaks the Liquid Glass sidebar
            // layout (sidebar no longer extends into the toolbar area). Similarly,
            // .navigationSplitViewColumnWidth(_:) prevents expansion but still allows the
            // sidebar to be collapsed to zero. Revisit when Apple fixes these issues.
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
        .preferredColorScheme(appearanceStore.effectiveColorScheme)
        .accentColor(appearanceStore.accentColor)
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsSection)) { notification in
            guard let raw = notification.object as? String,
                  let section = SettingsSection(rawValue: raw) else { return }
            selection = section
            if let highlight = notification.userInfo?["highlightSection"] as? String {
                // Brief delay so the target view has time to mount
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    NotificationCenter.default.post(
                        name: .highlightSettingsGroup,
                        object: highlight
                    )
                }
            }
        }
        .onAppear(perform: configureSettingsWindowIdentifier)
    }

    @ViewBuilder
    private func sectionView(for section: SettingsSection) -> some View {
        switch section {
        case .general:
            GeneralSettingsView()

        case .appearance:
            AppearanceSettingsView()
                .environmentObject(environmentState)
                .environmentObject(appState)
                .environmentObject(appearanceStore)

        case .databases:
            DatabasesSettingsView()

        case .sidebar:
            SidebarSettingsView()

        case .queryResults:
            QueryResultsSettingsView()
                .environmentObject(environmentState)
                .environmentObject(appState)
                .environmentObject(appearanceStore)

        case .echoSense:
            EchoSenseSettingsView()
                .environmentObject(environmentState)
                .environmentObject(appState)
                .environmentObject(appearanceStore)

        case .diagrams:
            DiagramSettingsView()
                .environmentObject(environmentState)
                .environmentObject(appearanceStore)

        case .applicationCache:
            ApplicationCacheSettingsView()
                .environmentObject(environmentState)
                .environmentObject(appState)
                .environmentObject(clipboardHistory)

        case .keyboardShortcuts:
            KeyboardShortcutsSettingsView()
        }
    }

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

}
