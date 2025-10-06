import AppKit
import SwiftUI

final class ConnectionsWindowController: NSWindowController {
    private unowned let coordinator: AppCoordinator
    private var hostingController: NSHostingController<ConnectionsRootView>

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator

        let contentRect = NSRect(x: 0, y: 0, width: 960, height: 640)
        let style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: style,
            backing: .buffered,
            defer: false
        )
        window.title = "Manage Connections"
        window.isReleasedWhenClosed = false
        window.center()

        let rootView = ConnectionsRootView(
            appModel: coordinator.appModel,
            appState: coordinator.appState,
            clipboardHistory: coordinator.clipboardHistory
        )
        hostingController = NSHostingController(rootView: rootView)
        window.contentViewController = hostingController
        window.setContentSize(contentRect.size)
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(makeKey: Bool) {
        guard let window else { return }
        if makeKey {
            window.makeKeyAndOrderFront(nil)
        } else {
            window.orderFrontRegardless()
        }
    }
}

private struct ConnectionsRootView: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject var appState: AppState
    let clipboardHistory: ClipboardHistoryStore

    var body: some View {
        ManageConnectionsTab()
            .environmentObject(appModel)
            .environmentObject(appState)
            .environmentObject(clipboardHistory)
            .environmentObject(ThemeManager.shared)
            .frame(minWidth: 800, minHeight: 520)
    }
}
