import SwiftUI
#if os(macOS)
import AppKit

struct AppKitContextMenuModifier: ViewModifier {
    let menuProvider: () -> NSMenu?

    func body(content: Content) -> some View {
        AppKitContextMenuHost(content: content, menuProvider: menuProvider)
    }
}

private struct AppKitContextMenuHost<Content: View>: NSViewRepresentable {
    var content: Content
    let menuProvider: () -> NSMenu?

    func makeNSView(context: Context) -> HostingView {
        HostingView(rootView: content, menuProvider: menuProvider)
    }

    func updateNSView(_ nsView: HostingView, context: Context) {
        nsView.rootView = content
        nsView.menuProvider = menuProvider
    }

    final class HostingView: NSHostingView<Content> {
        var menuProvider: (() -> NSMenu?)?

        init(rootView: Content, menuProvider: (() -> NSMenu?)?) {
            self.menuProvider = menuProvider
            super.init(rootView: rootView)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        @available(*, unavailable)
        required init(rootView: Content) {
            fatalError("init(rootView:) has not been implemented")
        }

        override func menu(for event: NSEvent) -> NSMenu? {
            menuProvider?()
        }
    }
}

extension View {
    func appKitContextMenu(_ menuProvider: @escaping () -> NSMenu?) -> some View {
        modifier(AppKitContextMenuModifier(menuProvider: menuProvider))
    }
}

#else
#endif
