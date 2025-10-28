import SwiftUI
#if os(macOS)
import AppKit

@MainActor
final class SettingsContainerViewController: NSViewController {
    let selectionModel = SettingsSelectionModel()
    private let toolbarBridge: SettingsNavigationBridge

    private let sidebarWidth: CGFloat = 280

    private let rootView = NSView()
    private let sidebarContainer = NSView()
    private let detailContainer = NSView()
    private let divider = NSBox()
    private let sidebarBackground = NSVisualEffectView()
    private let headerBlurView = NSVisualEffectView()
    private var sidebarVC: AppKitSettingsSidebarViewController!

    // Manual layout; toolbarTopInset controls divider start under header
    var toolbarTopInset: CGFloat = 0 {
        didSet {
            // Ensure updates always run on the main actor
            Task { @MainActor in self.layoutManually() }
        }
    }

    private var leftHost: NSHostingController<AnyView>!
    private var rightHost: NSHostingController<AnyView>!

    init(bridge: SettingsNavigationBridge) {
        self.toolbarBridge = bridge
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() {
        // Manual layout: disable Auto Layout entirely for deterministic geometry
        rootView.translatesAutoresizingMaskIntoConstraints = true
        sidebarContainer.translatesAutoresizingMaskIntoConstraints = true
        detailContainer.translatesAutoresizingMaskIntoConstraints = true
        divider.translatesAutoresizingMaskIntoConstraints = true
        sidebarBackground.translatesAutoresizingMaskIntoConstraints = true

        divider.boxType = .separator
        divider.isTransparent = false
        divider.fillColor = .separatorColor

        sidebarBackground.material = .sidebar
        sidebarBackground.state = .active
        sidebarBackground.blendingMode = .withinWindow

        headerBlurView.material = .headerView
        headerBlurView.state = .active
        headerBlurView.blendingMode = .withinWindow
        headerBlurView.translatesAutoresizingMaskIntoConstraints = true

        sidebarVC = AppKitSettingsSidebarViewController(selectionModel: selectionModel)
        addChild(sidebarVC)

        let detail = SettingsDetailView(toolbarBridge: toolbarBridge)
            .environmentObject(AppCoordinator.shared.appModel)
            .environmentObject(AppCoordinator.shared.appState)
            .environmentObject(AppCoordinator.shared.clipboardHistory)
            .environmentObject(ThemeManager.shared)
            .environmentObject(selectionModel)
        rightHost = NSHostingController(rootView: AnyView(detail))
        rightHost.view.translatesAutoresizingMaskIntoConstraints = true

        view = rootView
        view.addSubview(sidebarContainer)
        view.addSubview(divider)
        view.addSubview(detailContainer)
        view.addSubview(headerBlurView)
        sidebarContainer.addSubview(sidebarBackground)
        sidebarContainer.addSubview(sidebarVC.view)
        detailContainer.addSubview(rightHost.view)

        view.postsFrameChangedNotifications = true
        layoutManually()
        NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: view, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.layoutManually() }
        }
    }

    private func layoutManually() {
        let bounds = view.bounds
        let header = max(0, toolbarTopInset)
        // Sidebar 280 fixed
        sidebarContainer.frame = NSRect(x: 0, y: 0, width: sidebarWidth, height: bounds.height)
        sidebarBackground.frame = sidebarContainer.bounds
        sidebarVC.view.frame = sidebarContainer.bounds
        // Header blur spans full width, matches toolbar height
        headerBlurView.frame = NSRect(x: 0, y: bounds.height - header, width: bounds.width, height: header)
        // Divider starts below header
        divider.frame = NSRect(x: sidebarWidth, y: 0, width: 1, height: max(0, bounds.height - header))
        // Detail fills remainder
        detailContainer.frame = NSRect(x: sidebarWidth + 1, y: 0, width: max(0, bounds.width - (sidebarWidth + 1)), height: bounds.height)
        rightHost.view.frame = detailContainer.bounds
    }

    // Public for diagnostics
    var currentSidebarWidth: CGFloat { sidebarWidth }
    func enforceSidebarWidth() { layoutManually() }
}

#endif
