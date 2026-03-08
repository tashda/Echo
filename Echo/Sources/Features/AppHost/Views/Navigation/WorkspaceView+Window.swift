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
            if window.titleVisibility != .hidden {
                window.titleVisibility = .hidden
            }
            if window.toolbarStyle != .unified {
                window.toolbarStyle = .unified
            }
            if window.titlebarSeparatorStyle != .none {
                window.titlebarSeparatorStyle = .none
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

        func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
            let minFrameWidth: CGFloat = 980 + (sender.frame.width - sender.contentLayoutRect.width)
            var size = frameSize
            if size.width < minFrameWidth { size.width = minFrameWidth }
            return size
        }
    }
}
#endif
