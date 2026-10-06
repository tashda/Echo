import AppKit
import SwiftUI

@MainActor
final class ManageConnectionsWindowController: NSWindowController, NSWindowDelegate {
    static let shared = ManageConnectionsWindowController()
    private static let toolbarIdentifier = NSToolbar.Identifier("ManageConnectionsToolbar")
    private static let frameAutosaveName = "ManageConnectionsWindow"

    private var hostingController: PocketSeparatorHidingHostingController<ManageConnectionsWindowRootView>?
    private var isWindowLoadedOnce = false

    private override init(window: NSWindow?) {
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present(initialSection: ManageSection? = nil, selectedProjectID: UUID? = nil, selectedConnectionID: UUID? = nil, startingNewConnection: Bool = false) {
        if window == nil {
            configureWindow()
        }

        guard let window else { return }

        hostingController?.rootView = ManageConnectionsWindowRootView(onClose: { [weak self] in
            self?.closeWindow()
        }, initialSection: initialSection, selectedProjectID: selectedProjectID, selectedConnectionID: selectedConnectionID, startsNewConnection: startingNewConnection)

        applyTheme(to: window)

        if !isWindowLoadedOnce {
            // The frame you leave the window at comes back next time; the first time it is centred.
            if !window.setFrameUsingName(Self.frameAutosaveName) {
                window.center()
            }
            window.setFrameAutosaveName(Self.frameAutosaveName)
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
        // Round MC: SwiftUI only sets the minimum size. By default it also sets the window to the
        // view's ideal size, which opened the window at its narrowest.
        hosting.sizingOptions = [.minSize]

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 720),
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
        // contentViewController resizes the window to the controller's view; put the size back.
        window.setContentSize(NSSize(width: 1200, height: 720))
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
        observeThemeChanges(for: window)
    }

    private func observeThemeChanges(for window: NSWindow) {
        _ = withObservationTracking {
            AppearanceStore.shared.effectiveColorScheme
        } onChange: { [weak self, weak window] in
            Task { @MainActor in
                guard let self, let window else { return }
                self.applyTheme(to: window)
                self.observeThemeChanges(for: window) // Re-track
            }
        }
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
            // The height first: building a class name for every view of the window, on every layout,
            // was the dearer test and only a hairline can match.
            if subview.frame.height <= 1,
               String(describing: type(of: subview)).contains("NSLayerBasedFillColorView") {
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
    var selectedProjectID: UUID? = nil
    var selectedConnectionID: UUID? = nil
    var startsNewConnection = false

    var body: some View {
        let coordinator = AppDirector.shared
        ManageConnectionsView(onClose: onClose, initialSection: initialSection, initialProjectID: selectedProjectID, initialConnectionID: selectedConnectionID, startsNewConnection: startsNewConnection)
            .id("\(initialSection?.rawValue ?? "")-\(selectedProjectID?.uuidString ?? "")-\(selectedConnectionID?.uuidString ?? "")-\(startsNewConnection)")
            .environment(coordinator.projectStore)
            .environment(coordinator.connectionStore)
            .environment(coordinator.navigationStore)
            .environment(coordinator.tabStore)
            .environment(coordinator.environmentState)
            .environment(coordinator.appState)
            .environment(coordinator.appearanceStore)
            .environment(coordinator.clipboardHistory)
            .environment(coordinator.authState)
    }
}
