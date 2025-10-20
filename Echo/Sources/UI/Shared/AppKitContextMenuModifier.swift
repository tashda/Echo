import SwiftUI
#if os(macOS)
import AppKit

struct AppKitContextMenuModifier: ViewModifier {
    let menuProvider: () -> NSMenu?

    func body(content: Content) -> some View {
        content.background(MenuAttacher(menuProvider: menuProvider))
    }

    private struct MenuAttacher: NSViewRepresentable {
        let menuProvider: () -> NSMenu?

        func makeNSView(context: Context) -> MenuAttachingView {
            MenuAttachingView(menuProvider: menuProvider)
        }

        func updateNSView(_ nsView: MenuAttachingView, context: Context) {
            nsView.menuProvider = menuProvider
            nsView.updateMenuIfPossible()
        }
    }

    private final class MenuAttachingView: NSView {
        var menuProvider: () -> NSMenu?

        init(menuProvider: @escaping () -> NSMenu?) {
            self.menuProvider = menuProvider
            super.init(frame: .zero)
            translatesAutoresizingMaskIntoConstraints = false
            isHidden = true
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidMoveToSuperview() {
            super.viewDidMoveToSuperview()
            updateMenuIfPossible()
        }

        func updateMenuIfPossible() {
            guard let hostView = superview else { return }
            hostView.menu = menuProvider()
        }
    }
}

extension View {
    func appKitContextMenu(_ menuProvider: @escaping () -> NSMenu?) -> some View {
#if os(macOS)
        modifier(AppKitContextMenuModifier(menuProvider: menuProvider))
#else
        self
#endif
    }
}

#endif
