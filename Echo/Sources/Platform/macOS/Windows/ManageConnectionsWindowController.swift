import AppKit
import SwiftUI
import Combine

@MainActor
final class ManageConnectionsWindowController: NSWindowController, NSWindowDelegate {
    static let shared = ManageConnectionsWindowController()
    private static let toolbarIdentifier = NSToolbar.Identifier("ManageConnectionsToolbar")

    private var hostingController: PocketSeparatorHidingHostingController<ManageConnectionsWindowRootView>?
    private var isWindowLoadedOnce = false
    private var themeCancellables = Set<AnyCancellable>()

    private override init(window: NSWindow?) {
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present(initialSection: ManageSection? = nil) {
        if window == nil {
            configureWindow()
        }

        guard let window else { return }
        AppDirector.shared.connectionStore.selectedFolderID = nil

        hostingController?.rootView = ManageConnectionsWindowRootView(onClose: { [weak self] in
            self?.closeWindow()
        }, initialSection: initialSection)

        applyTheme(to: window)

        if !isWindowLoadedOnce {
            window.center()
            isWindowLoadedOnce = true
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        AppDirector.shared.navigationStore.isManageConnectionsPresented = true
    }

    func closeWindow() {
        guard let window else { return }
        window.close()
    }

    private func configureWindow() {
        let rootView = ManageConnectionsWindowRootView(onClose: { [weak self] in
            self?.closeWindow()
        })
        let hosting = PocketSeparatorHidingHostingController(rootView: rootView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.identifier = AppWindowIdentifier.manageConnections
        window.title = "Manage Connections"
        window.isReleasedWhenClosed = false
        window.toolbarStyle = .unified
        window.titlebarSeparatorStyle = .none
        window.tabbingMode = .disallowed
        let toolbar = NSToolbar(identifier: Self.toolbarIdentifier)
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        toolbar.sizeMode = .regular
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar
        window.contentViewController = hosting
        window.delegate = self
        applyTheme(to: window)
        bindThemeUpdates(for: window)
        hostingController = hosting
        self.window = window
    }

    func windowWillClose(_ notification: Notification) {
        AppDirector.shared.navigationStore.isManageConnectionsPresented = false
    }

    private func bindThemeUpdates(for window: NSWindow) {
        themeCancellables.removeAll()

        AppearanceStore.shared.$effectiveColorScheme
            .receive(on: RunLoop.main)
            .sink { [weak self, weak window] _ in
                guard let window else { return }
                self?.applyTheme(to: window)
            }
            .store(in: &themeCancellables)
    }

    private func applyTheme(to window: NSWindow) {
        let manager = AppearanceStore.shared
        let isDark = manager.effectiveColorScheme == .dark
        window.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
    }
}

// MARK: - Pocket Separator Hiding

/// NSHostingController subclass that hides the 1px `_NSLayerBasedFillColorView`
/// separator that `NavigationSplitView` inserts inside `NSHardPocketView`
/// between the toolbar and detail content.
final class PocketSeparatorHidingHostingController<Content: View>: NSHostingController<Content> {
    override func viewDidLayout() {
        super.viewDidLayout()
        hidePocketSeparators(in: view)
    }

    private func hidePocketSeparators(in root: NSView) {
        for subview in root.subviews {
            let typeName = String(describing: type(of: subview))
            if typeName.contains("NSLayerBasedFillColorView"),
               subview.frame.height <= 1 {
                subview.isHidden = true
            }
            hidePocketSeparators(in: subview)
        }
    }
}

// MARK: - Root View

private struct ManageConnectionsWindowRootView: View {
    let onClose: () -> Void
    var initialSection: ManageSection? = nil

    var body: some View {
        let coordinator = AppDirector.shared
        ManageConnectionsView(onClose: onClose, initialSection: initialSection)
            .environment(coordinator.projectStore)
            .environment(coordinator.connectionStore)
            .environment(coordinator.navigationStore)
            .environment(coordinator.tabStore)
            .environmentObject(coordinator.environmentState)
            .environmentObject(coordinator.appState)
            .environmentObject(coordinator.appearanceStore)
            .environmentObject(coordinator.clipboardHistory)
    }
}
