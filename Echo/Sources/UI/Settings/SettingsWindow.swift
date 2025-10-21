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

    init(initialTitle: String = SettingsView.SettingsSection.appearance.title) {
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

#if os(macOS)
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private let navigationBridge = SettingsNavigationBridge()
    private lazy var toolbarController = SettingsToolbarController(bridge: navigationBridge)

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
            window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.toolbarStyle = .unified
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 720, height: 520))
            window.delegate = self
            toolbarController.install(on: window)
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

private final class SettingsHostingController: NSHostingController<SettingsView> {
    init(bridge: SettingsNavigationBridge) {
        let root = SettingsView(toolbarBridge: bridge)
            .environmentObject(AppCoordinator.shared.appModel)
            .environmentObject(AppCoordinator.shared.appState)
            .environmentObject(AppCoordinator.shared.clipboardHistory)
            .environmentObject(ThemeManager.shared)
        super.init(rootView: root)
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class SettingsToolbarController: NSObject, NSToolbarDelegate {
    private weak var window: NSWindow?
    private let bridge: SettingsNavigationBridge
    private var cancellables: Set<AnyCancellable> = []

    private var navControl: NSSegmentedControl?
    private var capsuleView: CapsuleTitleView?

    private let toolbarIdentifier = NSToolbar.Identifier("com.fuzee.settings.toolbar")
    private let navItemIdentifier = NSToolbarItem.Identifier("com.fuzee.settings.toolbar.nav")
    private let labelItemIdentifier = NSToolbarItem.Identifier("com.fuzee.settings.toolbar.label")
    private let capsuleItemIdentifier = NSToolbarItem.Identifier("com.fuzee.settings.toolbar.capsule")

    init(bridge: SettingsNavigationBridge) {
        self.bridge = bridge
    }

    func install(on window: NSWindow) {
        self.window = window

        let toolbar = NSToolbar(identifier: toolbarIdentifier)
        toolbar.delegate = self
        toolbar.allowsUserCustomization = false
        toolbar.allowsExtensionItems = false
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar

        observeBridge()
    }

    private func observeBridge() {
        cancellables.removeAll()

        bridge.$title
            .receive(on: RunLoop.main)
            .sink { [weak self] title in
                self?.capsuleView?.update(title: title)
            }
            .store(in: &cancellables)

        bridge.$canNavigateBack
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                self?.navControl?.setEnabled(enabled, forSegment: 0)
            }
            .store(in: &cancellables)

        bridge.$canNavigateForward
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                self?.navControl?.setEnabled(enabled, forSegment: 1)
            }
            .store(in: &cancellables)
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [navItemIdentifier, labelItemIdentifier, .flexibleSpace, capsuleItemIdentifier]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [navItemIdentifier, labelItemIdentifier, .flexibleSpace, capsuleItemIdentifier]
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier {
        case navItemIdentifier:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            let control = NSSegmentedControl(images: [
                NSImage(systemSymbolName: "chevron.left", accessibilityDescription: nil) ?? NSImage(),
                NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil) ?? NSImage()
            ], trackingMode: .momentary, target: self, action: #selector(handleNavigation(_:)))
            control.segmentStyle = .separated
            control.controlSize = .small
            control.setWidth(30, forSegment: 0)
            control.setWidth(30, forSegment: 1)
            control.translatesAutoresizingMaskIntoConstraints = false

            let container = NSView()
            container.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(control)

            NSLayoutConstraint.activate([
                control.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                control.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                control.topAnchor.constraint(equalTo: container.topAnchor),
                control.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                control.heightAnchor.constraint(equalToConstant: 26)
            ])

            item.view = container
            navControl = control
            control.setEnabled(bridge.canNavigateBack, forSegment: 0)
            control.setEnabled(bridge.canNavigateForward, forSegment: 1)
            return item

        case labelItemIdentifier:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            let label = NSTextField(labelWithString: "Settings")
            label.font = .systemFont(ofSize: 13, weight: .semibold)
            label.textColor = .secondaryLabelColor
            label.alignment = .left
            label.translatesAutoresizingMaskIntoConstraints = false

            let container = NSView()
            container.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(label)

            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
            ])

            item.view = container
            return item

        case capsuleItemIdentifier:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            let capsule = CapsuleTitleView()
            capsule.update(title: bridge.title)
            item.view = capsule
            capsuleView = capsule
            return item

        default:
            return NSToolbarItem(itemIdentifier: itemIdentifier)
        }
    }

    @objc private func handleNavigation(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0:
            bridge.triggerBack()
        case 1:
            bridge.triggerForward()
        default:
            break
        }
        sender.selectedSegment = -1
    }
}

private final class CapsuleTitleView: NSView {
    private let blurView = NSVisualEffectView()
    private let titleField = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true

        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.material = .underWindowBackground
        blurView.blendingMode = .withinWindow
        blurView.state = .active
        blurView.wantsLayer = true
        blurView.layer?.cornerRadius = 18
        blurView.layer?.masksToBounds = true

        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.font = .systemFont(ofSize: 16, weight: .semibold)
        titleField.textColor = .labelColor
        titleField.alignment = .center
        titleField.backgroundColor = .clear
        titleField.isBordered = false
        titleField.isEditable = false

        addSubview(blurView)
        blurView.addSubview(titleField)

        NSLayoutConstraint.activate([
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),
            blurView.heightAnchor.constraint(equalToConstant: 34),

            titleField.leadingAnchor.constraint(equalTo: blurView.leadingAnchor, constant: 24),
            titleField.trailingAnchor.constraint(equalTo: blurView.trailingAnchor, constant: -24),
            titleField.centerYAnchor.constraint(equalTo: blurView.centerYAnchor)
        ])

        layer?.shadowColor = NSColor.black.withAlphaComponent(0.18).cgColor
        layer?.shadowOpacity = 1
        layer?.shadowRadius = 12
        layer?.shadowOffset = NSSize(width: 0, height: -4)
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        let labelSize = titleField.intrinsicContentSize
        return NSSize(width: max(160, labelSize.width + 48), height: 34)
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
        toolbarBridge.title = selection?.title ?? "Settings"
        toolbarBridge.canNavigateBack = canNavigateBack
        toolbarBridge.canNavigateForward = canNavigateForward
    }

    @ViewBuilder
    private var settingsSplitView: some View {
#if os(macOS)
        NavigationSplitView(columnVisibility: $columnVisibility, preferredCompactColumn: $preferredColumn) {
            sidebar
        } detail: {
            detailContent
        }
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
