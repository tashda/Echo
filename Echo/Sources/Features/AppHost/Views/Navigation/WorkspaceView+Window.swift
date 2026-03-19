import SwiftUI
#if os(macOS)
import AppKit

/// Configures the native NSWindow properties that SwiftUI does not expose.
///
/// Added as a `.background()` modifier on the workspace view. Its coordinator
/// acts as the window delegate and handles:
/// - Titlebar appearance (transparent, unified toolbar style)
/// - Window identifier for key-window tracking
/// - Minimum size constraints
struct WorkspaceWindowConfigurator: NSViewRepresentable {
    @Environment(NavigationStore.self) private var navigationStore

    var tabBarStyle: WorkspaceTabBarStyle

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        Task {
            guard let window = view.window else { return }
            context.coordinator.configure(window: window, navigationStore: navigationStore)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        Task {
            guard let window = nsView.window else { return }
            context.coordinator.configure(window: window, navigationStore: navigationStore)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSWindowDelegate {
        private var lastWindowID: ObjectIdentifier?
        private var lastKeyState: Bool?

        func configure(window: NSWindow, navigationStore: NavigationStore) {
            let windowID = ObjectIdentifier(window)
            if lastWindowID != windowID { lastWindowID = windowID }

            applyWindowStyling(window)

            if window.delegate !== self { window.delegate = self }

            let isKey = window.isKeyWindow && window.identifier == AppWindowIdentifier.workspace
            if lastKeyState != isKey {
                navigationStore.isWorkspaceWindowKey = isKey
                lastKeyState = isKey
            }
        }

        // MARK: - Window Styling

        private func applyWindowStyling(_ window: NSWindow) {
            if window.identifier != AppWindowIdentifier.workspace {
                window.identifier = AppWindowIdentifier.workspace
            }
            if !window.titlebarAppearsTransparent {
                window.titlebarAppearsTransparent = true
            }
            if window.titleVisibility != .visible {
                window.titleVisibility = .visible
            }
            if window.toolbarStyle != .unified {
                window.toolbarStyle = .unified
            }
            if window.titlebarSeparatorStyle != .none {
                window.titlebarSeparatorStyle = .none
            }
            if window.tabbingMode != .disallowed {
                window.tabbingMode = .disallowed
            }
            if window.toolbar?.allowsUserCustomization != false {
                window.toolbar?.allowsUserCustomization = false
            }
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

        func windowDidEnterFullScreen(_ notification: Notification) {
            guard let window = notification.object as? NSWindow else { return }
            window.titlebarSeparatorStyle = .none
            // In fullscreen, the toolbar moves to a separate NSToolbarFullScreenWindow.
            // Delay to let the fullscreen layout settle, then hide separators in
            // both the main window and the toolbar fullscreen window.
            Task {
                try? await Task.sleep(for: .seconds(0.1))
                self.hideFullScreenSeparators(for: window)
            }
        }

        func windowDidExitFullScreen(_ notification: Notification) {
            guard let window = notification.object as? NSWindow else { return }
            window.titlebarSeparatorStyle = .none
        }

        /// In fullscreen, the toolbar lives in a separate `NSToolbarFullScreenWindow`.
        /// Find it and hide all pocket separators and titlebar separator views.
        private func hideFullScreenSeparators(for mainWindow: NSWindow) {
            for window in NSApp.windows {
                let className = String(describing: type(of: window))
                if className.contains("ToolbarFullScreen") {
                    if let themeFrame = window.contentView?.superview {
                        hideSeparatorViews(in: themeFrame)
                    }
                }
            }
        }

        private func hideSeparatorViews(in view: NSView) {
            let typeName = String(describing: type(of: view))
            if (typeName.contains("NSLayerBasedFillColorView") && view.frame.height <= 1) ||
               (typeName.contains("NSTitlebarSeparatorView") && view.frame.height <= 1) {
                view.isHidden = true
            }
            for subview in view.subviews {
                hideSeparatorViews(in: subview)
            }
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
