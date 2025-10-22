import SwiftUI
import Combine
#if os(macOS)
import AppKit
#endif

final class SettingsNavigationBridge: ObservableObject {
    @Published var title: String
    @Published var canNavigateBack: Bool
    @Published var canNavigateForward: Bool

    var performBack: (() -> Void)?
    var performForward: (() -> Void)?

    init(initialTitle: String = "Appearance") {
        self.title = initialTitle
        self.canNavigateBack = false
        self.canNavigateForward = false
    }

    func triggerBack() {
        performBack?()
    }

    func triggerForward() {
        performForward?()
    }
}

// MARK: - SwiftUI Settings Window (DISABLED - Using AppKit version instead)
// This implementation has been disabled in favor of AppKitSettingsWindowController
// which provides better control and matches Xcode Settings appearance exactly.

#if os(macOS) && false
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private let navigationBridge = SettingsNavigationBridge()
private lazy var titlebarAccessoryManager = SettingsTitlebarAccessoryManager(bridge: navigationBridge)

    private override init(window: NSWindow?) {
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present(section: SettingsView.SettingsSection? = nil) {
        if window == nil {
            let hostingController = SettingsHostingController(bridge: navigationBridge)
            let window = NSWindow(contentViewController: hostingController)
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.toolbarStyle = .unified
            window.isReleasedWhenClosed = false
            window.title = "Settings"
            window.setContentSize(NSSize(width: 960, height: 660))
            window.contentMinSize = NSSize(width: 820, height: 580)
            window.toolbar = nil
            window.delegate = self
            titlebarAccessoryManager.install(on: window)
            self.window = window
        }

        if let section {
            NotificationCenter.default.post(name: .openSettingsSection, object: section.rawValue)
        }

        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

}
#endif

// SwiftUI helpers (disabled)
#if os(macOS) && false
private struct SettingsRootView: View {
    let bridge: SettingsNavigationBridge

    var body: some View {
        SettingsView(toolbarBridge: bridge)
            .environmentObject(AppCoordinator.shared.appModel)
            .environmentObject(AppCoordinator.shared.appState)
            .environmentObject(AppCoordinator.shared.clipboardHistory)
            .environmentObject(ThemeManager.shared)
    }
}

private final class SettingsHostingController: NSHostingController<SettingsRootView> {
    init(bridge: SettingsNavigationBridge) {
        super.init(rootView: SettingsRootView(bridge: bridge))
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class SettingsTitlebarAccessoryManager {
    private let bridge: SettingsNavigationBridge
    private let accessoryController: NSTitlebarAccessoryViewController
    private let titlebarView: SettingsTitlebarView
    private var cancellables: Set<AnyCancellable> = []

    init(bridge: SettingsNavigationBridge) {
        self.bridge = bridge
        self.accessoryController = NSTitlebarAccessoryViewController()
        self.titlebarView = SettingsTitlebarView()
        accessoryController.layoutAttribute = .left
        accessoryController.view = titlebarView
        titlebarView.setFrameSize(titlebarView.intrinsicContentSize)

        titlebarView.onNavigateBack = { [weak bridge] in bridge?.triggerBack() }
        titlebarView.onNavigateForward = { [weak bridge] in bridge?.triggerForward() }
    }

    func install(on window: NSWindow) {
        if window.titlebarAccessoryViewControllers.contains(accessoryController) == false {
            window.addTitlebarAccessoryViewController(accessoryController)
        }
        observeBridge()
        titlebarView.updateTitle(bridge.title)
        titlebarView.updateNavigation(canGoBack: bridge.canNavigateBack, canGoForward: bridge.canNavigateForward)
        titlebarView.layoutSubtreeIfNeeded()
    }

    private func observeBridge() {
        cancellables.removeAll()

        bridge.$title
            .receive(on: RunLoop.main)
            .sink { [weak self] title in
                self?.titlebarView.updateTitle(title)
            }
            .store(in: &cancellables)

        bridge.$canNavigateBack
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                self?.titlebarView.updateNavigation(canGoBack: enabled, canGoForward: self?.bridge.canNavigateForward ?? false)
            }
            .store(in: &cancellables)

        bridge.$canNavigateForward
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                self?.titlebarView.updateNavigation(canGoBack: self?.bridge.canNavigateBack ?? false, canGoForward: enabled)
            }
            .store(in: &cancellables)
    }
}

private final class SettingsTitlebarView: NSVisualEffectView {
    var onNavigateBack: (() -> Void)?
    var onNavigateForward: (() -> Void)?

    private let navControl: NSSegmentedControl
    private let capsuleView = CapsuleTitleContainer()
    private let stackView: NSStackView
    private let navWidthConstraint: NSLayoutConstraint

    override init(frame frameRect: NSRect) {
        navControl = NSSegmentedControl(images: [
            NSImage(systemSymbolName: "chevron.left", accessibilityDescription: nil) ?? NSImage(),
            NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil) ?? NSImage()
        ], trackingMode: .momentary, target: nil, action: nil)
        stackView = NSStackView()
        navWidthConstraint = navControl.widthAnchor.constraint(equalToConstant: 56)
        super.init(frame: frameRect)

        material = .titlebar
        blendingMode = .withinWindow
        state = .active
        isEmphasized = false

        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        navControl.segmentStyle = .separated
        navControl.controlSize = .small
        navControl.translatesAutoresizingMaskIntoConstraints = false
        navControl.setContentHuggingPriority(.required, for: .horizontal)
        navControl.setContentCompressionResistancePriority(.required, for: .horizontal)
        navControl.setImageScaling(.scaleProportionallyDown, forSegment: 0)
        navControl.setImageScaling(.scaleProportionallyDown, forSegment: 1)
        navControl.selectedSegment = -1
        navControl.setWidth(28, forSegment: 0)
        navControl.setWidth(28, forSegment: 1)
        navControl.sizeToFit()
        navWidthConstraint.constant = max(navControl.fittingSize.width, 56)
        navWidthConstraint.isActive = true

        capsuleView.translatesAutoresizingMaskIntoConstraints = false
        capsuleView.setContentHuggingPriority(.required, for: .horizontal)
        capsuleView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.setContentHuggingPriority(.required, for: .horizontal)
        stackView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        stackView.addArrangedSubview(navControl)
        stackView.addArrangedSubview(capsuleView)

        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 4),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -4)
        ])

        navControl.target = self
        navControl.action = #selector(handleNavigation(_:))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        let navSize = navControl.intrinsicContentSize
        let capsuleSize = capsuleView.intrinsicContentSize
        let width = 12 + navSize.width + 12 + capsuleSize.width + 14
        let height = max(32, navSize.height + 8, capsuleSize.height + 8)
        return NSSize(width: width, height: height)
    }

    func updateTitle(_ title: String) {
        capsuleView.update(title: title)
    }

    func updateNavigation(canGoBack: Bool, canGoForward: Bool) {
        navControl.setEnabled(canGoBack, forSegment: 0)
        navControl.setEnabled(canGoForward, forSegment: 1)
    }

    @objc private func handleNavigation(_ sender: NSSegmentedControl) {
        defer { sender.selectedSegment = -1 }
        switch sender.selectedSegment {
        case 0: onNavigateBack?()
        case 1: onNavigateForward?()
        default: break
        }
    }
}

private final class CapsuleTitleContainer: NSView {
    private let blurView = NSVisualEffectView()
    private let titleField = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true

        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.material = .hudWindow
        blurView.state = .active
        blurView.blendingMode = .withinWindow
        blurView.wantsLayer = true
        blurView.layer?.cornerRadius = 16
        blurView.layer?.masksToBounds = true

        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.font = .systemFont(ofSize: 13, weight: .semibold)
        titleField.textColor = .labelColor
        titleField.alignment = .center
        titleField.backgroundColor = .clear
        titleField.isBordered = false
        titleField.isEditable = false
        titleField.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        titleField.setContentCompressionResistancePriority(.required, for: .horizontal)

        addSubview(blurView)
        blurView.addSubview(titleField)

        setContentHuggingPriority(.defaultHigh, for: .horizontal)
        setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        NSLayoutConstraint.activate([
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),
            blurView.heightAnchor.constraint(equalToConstant: 28),

            titleField.leadingAnchor.constraint(equalTo: blurView.leadingAnchor, constant: 18),
            titleField.trailingAnchor.constraint(equalTo: blurView.trailingAnchor, constant: -18),
            titleField.centerYAnchor.constraint(equalTo: blurView.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        let labelSize = titleField.intrinsicContentSize
        let width = max(180, labelSize.width + 40)
        return NSSize(width: width, height: 28)
    }

    func update(title: String) {
        titleField.stringValue = title
        invalidateIntrinsicContentSize()
    }
}
#endif

/// Hosts the sidebar/detail split view and renders each settings section.
struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var clipboardHistory: ClipboardHistoryStore
    @EnvironmentObject private var themeManager: ThemeManager

    @ObservedObject private var toolbarBridge: SettingsNavigationBridge

    init(toolbarBridge: SettingsNavigationBridge = SettingsNavigationBridge()) {
        self._toolbarBridge = ObservedObject(initialValue: toolbarBridge)
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

#if os(macOS)
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
#endif
    @State private var preferredColumn: NavigationSplitViewColumn = .sidebar
    @State private var selection: SettingsSection? = .appearance
    @State private var navigationHistory: [SettingsSection] = [.appearance]
    @State private var historyIndex: Int = 0
    @State private var isUpdatingFromHistory = false

    private let fixedSidebarWidth: CGFloat = 280

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
                toolbarBridge.performBack = { navigateBack() }
                toolbarBridge.performForward = { navigateForward() }
                syncToolbarState()
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
                    syncToolbarState()
                    return
                }
                guard let newValue else { return }
                if historyIndex < navigationHistory.count - 1 {
                    navigationHistory = Array(navigationHistory.prefix(historyIndex + 1))
                }
                guard navigationHistory.last != newValue else {
                    historyIndex = navigationHistory.count - 1
                    syncToolbarState()
                    return
                }
                navigationHistory.append(newValue)
                historyIndex = navigationHistory.count - 1
                syncToolbarState()
            }
            .onChange(of: historyIndex) { _, _ in
                syncToolbarState()
            }
            .accentColor(themeManager.accentColor)
            .preferredColorScheme(themeManager.effectiveColorScheme)
            .background(themeManager.windowBackground)
    }

    private func syncToolbarState() {
        let currentTitle = selection?.title ?? "Settings"
        let back = canNavigateBack
        let forward = canNavigateForward

        let bridge = toolbarBridge
        DispatchQueue.main.async {
            bridge.title = currentTitle
            bridge.canNavigateBack = back
            bridge.canNavigateForward = forward
        }
    }

    @ViewBuilder
    private var settingsSplitView: some View {
#if os(macOS)
        NavigationSplitView(columnVisibility: $columnVisibility, preferredCompactColumn: $preferredColumn) {
            sidebar
        } detail: {
            detailContent
        }
        .ignoresSafeArea(.container, edges: .top)
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
                Label {
                    Text(section.title)
                } icon: {
                    iconView(for: section)
                }
                .tag(section)
            }
        }
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
#if os(macOS)
        detailBaseContent
            .frame(minWidth: 560, minHeight: 420)
            .background(themeManager.surfaceBackgroundColor)
#else
        detailBaseContent
            .frame(minWidth: 560, minHeight: 420)
            .background(themeManager.surfaceBackgroundColor)
            .navigationTitle(selection?.title ?? "Settings")
            .toolbar {
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
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
#endif
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
#else
    private var canNavigateBack: Bool { historyIndex > 0 }
    private var canNavigateForward: Bool { historyIndex + 1 < navigationHistory.count }
    private func navigateBack() { if canNavigateBack { historyIndex -= 1; isUpdatingFromHistory = true; selection = navigationHistory[historyIndex] } }
    private func navigateForward() { if canNavigateForward { historyIndex += 1; isUpdatingFromHistory = true; selection = navigationHistory[historyIndex] } }
#endif
}

#Preview("Settings Window") {
    SettingsView()
        .environmentObject(AppCoordinator.shared.appModel)
        .environmentObject(AppCoordinator.shared.appState)
        .environmentObject(AppCoordinator.shared.clipboardHistory)
        .environmentObject(ThemeManager.shared)
}

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

enum SettingsWindowPresenter {
    private static let defaultsKey = "com.fuzee.settings.preferredWindowStyle"
    private static var cachedStyle: SettingsWindowStyle?

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
        // Always use AppKit implementation (matches Xcode Settings exactly)
        print("📍 SettingsWindowPresenter: Using AppKit implementation")
        AppKitSettingsWindowController.shared.present(section: section)
    }
}
#endif
