import SwiftUI

#if os(macOS)
import AppKit
#endif

struct ConnectionsBreadcrumbMenu: View {
    #if os(macOS)
    @Environment(ConnectionStore.self) private var connectionStore
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        NativeConnectionsBreadcrumbMenu(connectionStore: connectionStore, appModel: appModel)
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
    let appModel: AppModel

    func makeNSViewController(context: Context) -> ConnectionsPopoverController {
        ConnectionsPopoverController(connectionStore: connectionStore, appModel: appModel)
    }

    func updateNSViewController(_ nsViewController: ConnectionsPopoverController, context: Context) {
    }
}
#endif
