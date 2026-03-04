#if os(macOS)
import AppKit
import SwiftUI
import Combine

@MainActor
final class ManageConnectionsWindowController: NSWindowController, NSWindowDelegate {
    static let shared = ManageConnectionsWindowController()
    private static let toolbarIdentifier = NSToolbar.Identifier("ManageConnectionsToolbar")

    private var hostingController: NSHostingController<ManageConnectionsWindowRootView>?
    private var isWindowLoadedOnce = false
    private var themeCancellables = Set<AnyCancellable>()

    private override init(window: NSWindow?) {
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        if window == nil {
            configureWindow()
        }

        guard let window else { return }
        AppCoordinator.shared.connectionStore.selectedFolderID = nil

        hostingController?.rootView = ManageConnectionsWindowRootView(onClose: { [weak self] in
            self?.closeWindow()
        })

        applyTheme(to: window)

        if !isWindowLoadedOnce {
            window.center()
            isWindowLoadedOnce = true
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        AppCoordinator.shared.navigationStore.isManageConnectionsPresented = true
    }

    func closeWindow() {
        guard let window else { return }
        window.close()
    }

    private func configureWindow() {
        let rootView = ManageConnectionsWindowRootView(onClose: { [weak self] in
            self?.closeWindow()
        })
        let hosting = NSHostingController(rootView: rootView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.identifier = AppWindowIdentifier.manageConnections
        window.title = "Manage Connections"
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.toolbarStyle = .unified
        let toolbar = NSToolbar(identifier: Self.toolbarIdentifier)
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        toolbar.sizeMode = .regular
        toolbar.displayMode = .iconOnly
        if #available(macOS 15, *) {
            // showsBaselineSeparator removed on macOS 15
        } else {
            toolbar.showsBaselineSeparator = false
        }
        window.toolbar = toolbar
        window.contentViewController = hosting
        window.delegate = self
        applyTheme(to: window)
        bindThemeUpdates(for: window)
        hostingController = hosting
        self.window = window
    }

    func windowWillClose(_ notification: Notification) {
        AppCoordinator.shared.navigationStore.isManageConnectionsPresented = false
    }

    private func bindThemeUpdates(for window: NSWindow) {
        themeCancellables.removeAll()

        ThemeManager.shared.$effectiveColorScheme
            .receive(on: RunLoop.main)
            .sink { [weak self, weak window] _ in
                guard let window else { return }
                self?.applyTheme(to: window)
            }
            .store(in: &themeCancellables)
    }

    private func applyTheme(to window: NSWindow) {
        let manager = ThemeManager.shared
        let tone = manager.activePaletteTone
        window.appearance = NSAppearance(named: tone == .dark ? .darkAqua : .aqua)
        window.backgroundColor = manager.windowBackgroundNSColor
        if #unavailable(macOS 15) {
            window.toolbar?.showsBaselineSeparator = false
        }
    }
}

private struct ManageConnectionsWindowRootView: View {
    let onClose: () -> Void

    var body: some View {
        let coordinator = AppCoordinator.shared
        ManageConnectionsView(onClose: onClose)
            .ignoresSafeArea()
            .environment(coordinator.projectStore)
            .environment(coordinator.connectionStore)
            .environment(coordinator.navigationStore)
            .environment(coordinator.tabStore)
            .environmentObject(coordinator.appModel)
            .environmentObject(coordinator.appState)
            .environmentObject(coordinator.themeManager)
            .environmentObject(coordinator.clipboardHistory)
    }
}
#endif
