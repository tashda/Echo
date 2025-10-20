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
        .accentColor(themeManager.accentColor)
        .preferredColorScheme(themeManager.effectiveColorScheme)
        .background(themeManager.windowBackground)
#if os(macOS)
        .background(
            WindowAppearanceConfigurator(windowBackground: themeManager.windowBackground)
        )
#endif
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
        .scrollContentBackground(.hidden)
        .background(themeManager.surfaceBackgroundColor)
        .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 360)
#if os(macOS)
        .padding(.top, -8)
#endif
    }

    private var detailContent: some View {
        NavigationStack {
            Group {
                if let selection {
                    sectionView(for: selection)
                        .navigationTitle(selection.title)
                } else {
                    ContentUnavailableView {
                        Label("Select a Section", systemImage: "slider.horizontal.3")
                    } description: {
                        Text("Choose a settings category to view its options.")
                    }
                    .navigationTitle("Settings")
                }
            }
        }
        .frame(minWidth: 560, minHeight: 420)
        .background(themeManager.surfaceBackgroundColor)
        .toolbar {
#if os(macOS)
            ToolbarItemGroup(placement: .navigation) {
                Button(action: {}, label: {
                    Image(systemName: "chevron.left")
                })
                .disabled(true)

                Button(action: {}, label: {
                    Image(systemName: "chevron.right")
                })
                .disabled(true)
            }
#endif
        }
#if os(macOS)
        .toolbar(removing: .sidebarToggle)
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
}

#Preview("Settings Window") {
    SettingsView()
}

extension Notification.Name {
    static let openSettingsSection = Notification.Name("com.fuzee.settings.openSection")
}
