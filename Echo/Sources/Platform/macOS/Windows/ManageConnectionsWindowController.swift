#if os(macOS)
import AppKit
import SwiftUI

@MainActor
final class ManageConnectionsWindowController: NSWindowController, NSWindowDelegate {
    static let shared = ManageConnectionsWindowController()

    private var hostingController: NSHostingController<ManageConnectionsWindowRootView>?
    private var isWindowLoadedOnce = false

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

        hostingController?.rootView = ManageConnectionsWindowRootView(onClose: { [weak self] in
            self?.closeWindow()
        })

        // Apply the theme's appearance to the window
        let tone = ThemeManager.shared.activePaletteTone
        window.appearance = NSAppearance(named: tone == .dark ? .darkAqua : .aqua)

        if !isWindowLoadedOnce {
            window.center()
            isWindowLoadedOnce = true
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        AppCoordinator.shared.appModel.isManageConnectionsPresented = true
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
        window.title = "Manage Connections"
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible
        window.toolbarStyle = .unified
        window.contentViewController = hosting
        window.delegate = self
        hostingController = hosting
        self.window = window
    }

    func windowWillClose(_ notification: Notification) {
        AppCoordinator.shared.appModel.isManageConnectionsPresented = false
    }
}

private struct ManageConnectionsWindowRootView: View {
    let onClose: () -> Void

    var body: some View {
        ManageConnectionsView(onClose: onClose)
            .environmentObject(AppCoordinator.shared.appModel)
            .environmentObject(AppCoordinator.shared.appState)
            .environmentObject(AppCoordinator.shared.themeManager)
            .environmentObject(AppCoordinator.shared.clipboardHistory)
    }
}
#endif
