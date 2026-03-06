import SwiftUI
#if os(macOS)
import AppKit

/// Configures the native NSWindow properties that SwiftUI does not expose.
///
/// Added as a `.background()` modifier on the workspace view. Its coordinator
/// acts as the window delegate and handles:
/// - Titlebar appearance (transparent, no separator)
/// - Toolbar customization disabled
/// - Breadcrumb toolbar item `isBordered` (liquid glass pill)
/// - Breadcrumb width constraint (40% of window width)
/// - Window identifier for key-window tracking
struct WorkspaceWindowConfigurator: NSViewRepresentable {
    @Environment(NavigationStore.self) private var navigationStore

    var tabBarStyle: WorkspaceTabBarStyle

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            context.coordinator.configure(window: window, navigationStore: navigationStore)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            context.coordinator.configure(window: window, navigationStore: navigationStore)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSWindowDelegate {
        private var lastWindowID: ObjectIdentifier?
        private var lastKeyState: Bool?
        private var widthConstraint: NSLayoutConstraint?

        func configure(window: NSWindow, navigationStore: NavigationStore) {
            let windowID = ObjectIdentifier(window)
            if lastWindowID != windowID { lastWindowID = windowID }

            applyWindowStyling(window)
            configurePrincipalItem(window)

            if window.delegate !== self { window.delegate = self }

            let isKey = window.isKeyWindow && window.identifier == AppWindowIdentifier.workspace
            if lastKeyState != isKey {
                navigationStore.isWorkspaceWindowKey = isKey
                lastKeyState = isKey
            }
        }

        // MARK: - Principal Item (Breadcrumb Pill)

        /// Sets `isBordered = true` for liquid glass appearance and constrains
        /// the breadcrumb width to 40% of the window width.
        private func configurePrincipalItem(_ window: NSWindow) {
            guard let toolbar = window.toolbar else { return }
            for item in toolbar.items where item.itemIdentifier.rawValue.lowercased().contains("breadcrumb") {
                guard let itemView = item.view else { continue }
                item.isBordered = true

                let targetWidth = max(200, window.frame.width * 0.40)

                if let existing = widthConstraint {
                    existing.constant = targetWidth
                } else {
                    itemView.translatesAutoresizingMaskIntoConstraints = false
                    let constraint = itemView.widthAnchor.constraint(equalToConstant: targetWidth)
                    constraint.priority = .defaultHigh
                    constraint.isActive = true
                    widthConstraint = constraint
                }
                return
            }
        }

        // MARK: - Window Styling

        /// Properties that SwiftUI scene modifiers cannot set.
        private func applyWindowStyling(_ window: NSWindow) {
            if window.identifier != AppWindowIdentifier.workspace {
                window.identifier = AppWindowIdentifier.workspace
            }
            if !window.titlebarAppearsTransparent {
                window.titlebarAppearsTransparent = true
            }
            if window.titlebarSeparatorStyle != .none {
                window.titlebarSeparatorStyle = .none
            }
            if window.toolbar?.allowsUserCustomization != false {
                window.toolbar?.allowsUserCustomization = false
            }
            // Minimum width enforced via content min size
            let contentMinWidth: CGFloat = 980
            if window.contentMinSize.width < contentMinWidth {
                window.contentMinSize.width = contentMinWidth
            }
            let chromeDelta = window.frame.width - window.contentLayoutRect.width
            if window.minSize.width < (contentMinWidth + chromeDelta) {
                window.minSize.width = contentMinWidth + chromeDelta
            }
        }

        // MARK: - NSWindowDelegate

        func windowDidResize(_ notification: Notification) {
            guard let window = notification.object as? NSWindow else { return }
            configurePrincipalItem(window)
        }

        func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
            let minFrameWidth: CGFloat = 980 + (sender.frame.width - sender.contentLayoutRect.width)
            var size = frameSize
            if size.width < minFrameWidth { size.width = minFrameWidth }
            return size
        }
    }
}
#endif
