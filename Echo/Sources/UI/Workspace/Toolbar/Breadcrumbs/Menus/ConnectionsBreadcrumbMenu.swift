import SwiftUI

#if os(macOS)
import AppKit
#endif

struct ConnectionsBreadcrumbMenu: View {
    #if os(macOS)
    @Environment(ConnectionStore.self) private var connectionStore
    @EnvironmentObject private var workspaceSessionStore: WorkspaceSessionStore

    var body: some View {
        NativeConnectionsBreadcrumbMenu(connectionStore: connectionStore, workspaceSessionStore: workspaceSessionStore)
    }
    #else
    var body: some View {
        EmptyView()
    }
    #endif
}

#if os(macOS)
private struct NativeConnectionsBreadcrumbMenu: NSViewControllerRepresentable {
    let connectionStore: ConnectionStore
    let workspaceSessionStore: WorkspaceSessionStore

    func makeNSViewController(context: Context) -> ConnectionsPopoverController {
        ConnectionsPopoverController(connectionStore: connectionStore, workspaceSessionStore: workspaceSessionStore)
    }

    func updateNSViewController(_ nsViewController: ConnectionsPopoverController, context: Context) {
    }
}
#endif
