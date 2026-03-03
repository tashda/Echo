import SwiftUI

#if os(macOS)
import AppKit
#endif

struct ConnectionsBreadcrumbMenu: View {
    #if os(macOS)
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        NativeConnectionsBreadcrumbMenu(appModel: appModel)
    }
    #else
    var body: some View {
        EmptyView()
    }
    #endif
}

#if os(macOS)
private struct NativeConnectionsBreadcrumbMenu: NSViewControllerRepresentable {
    let appModel: AppModel

    func makeNSViewController(context: Context) -> ConnectionsPopoverController {
        ConnectionsPopoverController(appModel: appModel)
    }

    func updateNSViewController(_ nsViewController: ConnectionsPopoverController, context: Context) {
    }
}
#endif
