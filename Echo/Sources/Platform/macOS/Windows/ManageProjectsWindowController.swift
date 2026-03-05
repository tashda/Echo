import AppKit
import SwiftUI
import Combine

@MainActor
final class ManageProjectsWindowController: NSWindowController, NSWindowDelegate {
    static let shared = ManageProjectsWindowController()
    private static let toolbarIdentifier = NSToolbar.Identifier("ManageProjectsToolbar")

    private var hostingController: NSHostingController<ManageProjectsWindowRootView>?
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

        hostingController?.rootView = ManageProjectsWindowRootView()

        applyTheme(to: window)

        if !isWindowLoadedOnce {
            window.center()
            isWindowLoadedOnce = true
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Force relayout to clear the NavigationSplitView titlebar separator
        // that appears on first display with .unified toolbar style.
        DispatchQueue.main.async {
            let frame = window.frame
            window.setFrame(frame.insetBy(dx: 0, dy: 0.5), display: false)
            window.setFrame(frame, display: true)
        }
    }

    func closeWindow() {
        guard let window else { return }
        window.close()
    }

    private func configureWindow() {
        let rootView = ManageProjectsWindowRootView()
        let hosting = NSHostingController(rootView: rootView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.identifier = AppWindowIdentifier.manageProjects
        window.title = "Manage Projects"
        window.isReleasedWhenClosed = false
        window.toolbarStyle = .unified
        window.titlebarSeparatorStyle = .none
        window.minSize = NSSize(width: 700, height: 500)
        window.setFrameAutosaveName("ManageProjectsWindow")
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
        AppCoordinator.shared.navigationStore.showManageProjectsSheet = false
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

// MARK: - Root View

private struct ManageProjectsWindowRootView: View {
    var body: some View {
        let coordinator = AppCoordinator.shared
        ManageProjectsView()
            .environment(coordinator.projectStore)
            .environment(coordinator.connectionStore)
            .environment(coordinator.navigationStore)
            .environmentObject(coordinator.environmentState)
            .environmentObject(coordinator.appState)
            .environmentObject(coordinator.appearanceStore)
            .environmentObject(coordinator.clipboardHistory)
    }
}
