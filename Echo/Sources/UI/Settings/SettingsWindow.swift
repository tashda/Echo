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

    init() {
        // Simple init - no navigation bridge needed
    }

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
    private let fixedSidebarWidth: CGFloat = 300

    var body: some View {
        settingsSplitView
            .frame(minWidth: 1000, minHeight: 700)
            .preferredColorScheme(themeManager.effectiveColorScheme) // Proper theme integration like ManageConnectionsView
            .accentColor(themeManager.accentColor) // Proper accent color
            .ignoresSafeArea(.all) // Ignore all safe areas for full window coverage
            .onAppear {
                if selection == nil {
                    selection = .appearance
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openSettingsSection)) { notification in
                guard let raw = notification.object as? String,
                      let section = SettingsSection(rawValue: raw) else { return }
                selection = section
            }
    }

    // No complex navigation state management needed with NavigationSplitView

    @ViewBuilder
    private var settingsSplitView: some View {
        NavigationSplitView {
            sidebar
                .frame(minWidth: fixedSidebarWidth, idealWidth: fixedSidebarWidth, maxWidth: fixedSidebarWidth)
#if os(macOS)
                .toolbar(removing: .sidebarToggle) // Remove sidebar toggle
#endif
        } detail: {
            detailContent
        }
#if os(macOS)
        .navigationSplitViewStyle(.balanced) // Use balanced style like ManageConnectionsView
#endif
    }

    private var sidebar: some View {
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
#if os(macOS)
        .scrollContentBackground(.hidden)
        .background(themeManager.surfaceBackgroundColor) // Proper theme background like ManageConnectionsView
        .ignoresSafeArea(.all, edges: .top) // Extend sidebar to very top of window
#endif
    }

    private var detailContent: some View {
        detailBaseContent
            .frame(minWidth: 560, minHeight: 420)
            .navigationTitle(selection?.title ?? "Settings") // Simple navigation title
            .background(themeManager.surfaceBackgroundColor) // Proper theme background
    }

    private var detailBaseContent: some View {
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

#if os(macOS)
enum SettingsWindowStyle: String, CaseIterable {
    case swiftUI
    case appKit

    var displayName: String {
        switch self {
        case .swiftUI: return "SwiftUI Window"
        case .appKit: return "AppKit Preview"
        }
    }
}

@MainActor
enum SettingsWindowPresenter {
    private static let defaultsKey = "com.fuzee.settings.preferredWindowStyle"
    private nonisolated(unsafe) static var cachedStyle: SettingsWindowStyle?

    static var preferredStyle: SettingsWindowStyle {
        get {
            if let cachedStyle { return cachedStyle }
            if let raw = UserDefaults.standard.string(forKey: defaultsKey),
               let style = SettingsWindowStyle(rawValue: raw) {
                cachedStyle = style
                return style
            }
            cachedStyle = .swiftUI
            return .swiftUI
        }
        set {
            cachedStyle = newValue
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
        }
    }

    static func present(section: SettingsView.SettingsSection? = nil, style: SettingsWindowStyle? = nil) {
        // Use pure SwiftUI window presentation
        print("📍 SettingsWindowPresenter: Using pure SwiftUI implementation")
        
        let settingsView = SettingsView()
            .environmentObject(AppCoordinator.shared.appModel)
            .environmentObject(AppCoordinator.shared.appState)
            .environmentObject(AppCoordinator.shared.clipboardHistory)
            .environmentObject(ThemeManager.shared)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Settings"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.contentMinSize = NSSize(width: 800, height: 600)
        window.center()
        window.isReleasedWhenClosed = false
        
        // Disable rounded corners for native macOS appearance
        if #available(macOS 13.0, *) {
            window.toolbarStyle = .unifiedCompact
        }
        
        // Force sharp corners like native macOS windows
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 0
        
        let hostingController = NSHostingController(rootView: settingsView)
        window.contentViewController = hostingController
        
        if let section {
            NotificationCenter.default.post(name: .openSettingsSection, object: section.rawValue)
        }
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
#endif
