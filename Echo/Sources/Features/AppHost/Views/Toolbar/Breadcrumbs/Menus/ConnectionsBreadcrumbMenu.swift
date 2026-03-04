import SwiftUI

#if os(macOS)
import AppKit
#endif

struct ConnectionsBreadcrumbMenu: View {
    #if os(macOS)
    @Environment(ConnectionStore.self) private var connectionStore
    @EnvironmentObject private var environmentState: EnvironmentState

    var body: some View {
        NativeConnectionsBreadcrumbMenu(connectionStore: connectionStore, environmentState: environmentState)
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
    let environmentState: EnvironmentState

    func makeNSViewController(context: Context) -> ConnectionsPopoverController {
        ConnectionsPopoverController(connectionStore: connectionStore, environmentState: environmentState)
    }

    func updateNSViewController(_ nsViewController: ConnectionsPopoverController, context: Context) {
    }
}
#endif
