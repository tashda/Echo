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
    @State private var navigationHistory: [SettingsSection] = []
    @State private var navigationIndex: Int = -1
    private let fixedSidebarWidth: CGFloat = 300

    var body: some View {
        settingsSplitView
            .frame(minWidth: 1000, minHeight: 700)
            .preferredColorScheme(themeManager.effectiveColorScheme) // Proper theme integration like ManageConnectionsView
            .accentColor(themeManager.accentColor) // Proper accent color
            .ignoresSafeArea(.all, edges: .all) // Ignore all safe areas for full window coverage
            .onAppear {
                if selection == nil {
                    selection = .appearance
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openSettingsSection)) { notification in
                guard let raw = notification.object as? String,
                      let section = SettingsSection(rawValue: raw) else { return }
                navigateTo(section)
            }
            .onChange(of: selection) { oldValue, newValue in
                if let newValue {
                    navigateTo(newValue, isUserInitiated: false)
                }
            }
    }

    // MARK: - Navigation Management

    private func navigateTo(_ section: SettingsSection, isUserInitiated: Bool = true) {
        guard selection != section else { return }

        selection = section

        if isUserInitiated {
            // Clear forward history when navigating to a new section
            navigationHistory = Array(navigationHistory.prefix(navigationIndex + 1))
            navigationHistory.append(section)
            navigationIndex = navigationHistory.count - 1
        } else {
            // Initialize navigation history if empty
            if navigationHistory.isEmpty {
                navigationHistory = [section]
                navigationIndex = 0
            }
        }
    }

    private func goBack() {
        guard navigationIndex > 0 else { return }
        navigationIndex -= 1
        let targetSection = navigationHistory[navigationIndex]
        selection = targetSection
    }

    private func goForward() {
        guard navigationIndex < navigationHistory.count - 1 else { return }
        navigationIndex += 1
        let targetSection = navigationHistory[navigationIndex]
        selection = targetSection
    }

    private var canGoBack: Bool {
        navigationIndex > 0
    }

    private var canGoForward: Bool {
        navigationIndex < navigationHistory.count - 1
    }

    @ViewBuilder
    private var settingsSplitView: some View {
        NavigationSplitView {
            sidebar
                .frame(minWidth: fixedSidebarWidth, idealWidth: fixedSidebarWidth, maxWidth: fixedSidebarWidth)
#if os(iOS)
                .toolbarBackground(.hidden, for: .navigationBar) // Hide navigation bar background
#endif
                .scrollContentBackground(.hidden) // Hide default scroll background
#if os(macOS)
                .toolbar(removing: .sidebarToggle) // Remove sidebar toggle
                .ignoresSafeArea(.all, edges: .top) // Extend sidebar to very top of window
                .clipped() // Ensure no overflow
#endif
        } detail: {
            detailContent
        }
#if os(macOS)
        .navigationSplitViewStyle(.balanced) // Use balanced style like ManageConnectionsView
        .background(themeManager.surfaceBackgroundColor) // Ensure full window background
        .ignoresSafeArea(.all, edges: .top) // Also extend main split view to top
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
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.automatic, for: .navigationBar)
#endif
            .background(themeManager.surfaceBackgroundColor)
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigation) {
                    HStack(spacing: 12) {
                        // Back button
                        Button(action: goBack) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(canGoBack ? .primary : .quaternary)
                        }
                        .disabled(!canGoBack)
                        .keyboardShortcut("[")
                        .buttonStyle(SettingsNavigationButtonStyle(enabled: canGoBack))

                        // Forward button
                        Button(action: goForward) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(canGoForward ? .primary : .quaternary)
                        }
                        .disabled(!canGoForward)
                        .keyboardShortcut("]")
                        .buttonStyle(SettingsNavigationButtonStyle(enabled: canGoForward))

                        // Current view title
                        if let selection = selection {
                            Text(selection.title)
                                .font(.system(size: 15, weight: .semibold, design: .default))
                                .foregroundStyle(.primary)
                                .opacity(0.8)
                        }
                    }
                    .padding(.leading, 4)
                }
#else
                ToolbarItem(placement: .navigation) {
                    HStack(spacing: 16) {
                        // Navigation buttons capsule
                        HStack(spacing: 4) {
                            // Back button
                            Button(action: goBack) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(canGoBack ? .primary : .quaternary)
                            }
                            .disabled(!canGoBack)
                            .keyboardShortcut("[")
                            .buttonStyle(SettingsNavigationButtonStyle(enabled: canGoBack))

                            // Forward button
                            Button(action: goForward) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(canGoForward ? .primary : .quaternary)
                            }
                            .disabled(!canGoForward)
                            .keyboardShortcut("]")
                            .buttonStyle(SettingsNavigationButtonStyle(enabled: canGoForward))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.primary.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
                                )
                        )

                        // Current view title (outside capsule)
                        if let selection = selection {
                            Text(selection.title)
                                .font(.system(size: 15, weight: .semibold, design: .default))
                                .foregroundStyle(.primary)
                                .opacity(0.8)
                        }
                    }
                    .padding(.leading, 4)
                }
#endif
            }
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

// MARK: - System Settings Style Navigation Button

struct SettingsNavigationButtonStyle: ButtonStyle {
    let enabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 32, height: 32)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(configuration.isPressed && enabled ? Color.primary.opacity(0.08) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(enabled ? Color.primary.opacity(0.12) : Color.clear, lineWidth: 0.5)
            )
            .scaleEffect(configuration.isPressed && enabled ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
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
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = true
        // Ensure window is flush with no titlebar spacing
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

        // Ensure content extends to window edges
        window.contentView?.autoresizingMask = [.width, .height]
        
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
