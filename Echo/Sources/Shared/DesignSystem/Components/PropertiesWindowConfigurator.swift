import SwiftUI
#if os(macOS)
import AppKit

/// Configures properties windows (Database Editor, Login Editor, etc.):
/// disables tab grouping and brings the window to front.
struct PropertiesWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        Task {
            guard let window = view.window else { return }
            window.tabbingMode = .disallowed
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif
