import SwiftUI
import AppKit

/// Hosts the sidebar/detail split view and renders each settings section.
struct SettingsView: View {
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(AppState.self) private var appState
    @Environment(ClipboardHistoryStore.self) private var clipboardHistory
    @Environment(AppearanceStore.self) private var appearanceStore

    enum SettingsSection: String, CaseIterable, Identifiable {
        case general
        case notifications
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
            case .notifications: return "Notifications"
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
            case .notifications: return "bell.badge"
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

    /// Composite navigation state that captures the full destination,
    /// including sub-tabs like the database settings tab.
    struct Destination: Hashable {
        var section: SettingsSection
        var databaseTab: DatabasesSettingsView.DatabaseSettingsTab = .shared
    }

    @State private var selection: SettingsSection? = .general
    @State private var databaseTab: DatabasesSettingsView.DatabaseSettingsTab = .shared
    @State private var navHistory = NavigationHistory<Destination>()
    /// Suppresses history recording during programmatic back/forward navigation.
    @State private var isRestoringNavigation = false

    /// Snapshot the current navigation state into a `Destination`.
    private var currentDestination: Destination {
        Destination(
            section: selection ?? .general,
            databaseTab: databaseTab
        )
    }

    /// Restore all state from a `Destination`, suppressing onChange recording.
    private func restore(_ destination: Destination) {
        isRestoringNavigation = true
        selection = destination.section
        databaseTab = destination.databaseTab
        // Reset after SwiftUI processes the state changes.
        Task {
            isRestoringNavigation = false
        }
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
                        .frame(minWidth: 620, minHeight: 420)
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
            .compositeNavigationHistoryToolbar(
                history: navHistory,
                snapshot: { currentDestination },
                restore: { restore($0) }
            )
        }
        .preferredColorScheme(appearanceStore.effectiveColorScheme)
        .accentColor(appearanceStore.accentColor)
        .onChange(of: selection) { oldValue, _ in
            guard !isRestoringNavigation, let oldValue else { return }
            navHistory.push(Destination(section: oldValue, databaseTab: databaseTab))
        }
        .onChange(of: databaseTab) { oldValue, _ in
            guard !isRestoringNavigation, let section = selection else { return }
            navHistory.push(Destination(section: section, databaseTab: oldValue))
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsSection)) { notification in
            guard let raw = notification.object as? String,
                  let section = SettingsSection(rawValue: raw) else { return }
            selection = section
            if let highlight = notification.userInfo?["highlightSection"] as? String {
                Task {
                    try? await Task.sleep(for: .seconds(0.15))
                    NotificationCenter.default.post(
                        name: .highlightSettingsGroup,
                        object: highlight
                    )
                }
            }
        }
        .onAppear(perform: configureSettingsWindow)
    }

    @ViewBuilder
    private func sectionView(for section: SettingsSection) -> some View {
        switch section {
        case .general:
            GeneralSettingsView()

        case .notifications:
            NotificationSettingsView()

        case .appearance:
            AppearanceSettingsView()
                .environment(environmentState)
                .environment(appState)
                .environment(appearanceStore)

        case .databases:
            DatabasesSettingsView(selectedTab: $databaseTab)

        case .sidebar:
            SidebarSettingsView()

        case .queryResults:
            QueryResultsSettingsView()
                .environment(environmentState)
                .environment(appState)
                .environment(appearanceStore)

        case .echoSense:
            EchoSenseSettingsView()
                .environment(environmentState)
                .environment(appState)
                .environment(appearanceStore)

        case .diagrams:
            DiagramSettingsView()
                .environment(environmentState)
                .environment(appearanceStore)

        case .applicationCache:
            ApplicationCacheSettingsView()
                .environment(environmentState)
                .environment(appState)
                .environment(clipboardHistory)

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
