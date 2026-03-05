import SwiftUI
import os.log
#if os(macOS)
import AppKit

private let winLog = Logger(subsystem: "com.echo.overlay", category: "window")

struct WorkspaceWindowConfigurator: NSViewRepresentable {
    @Environment(ProjectStore.self) private var projectStore
    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(NavigationStore.self) private var navigationStore
    @Environment(TabStore.self) private var tabStore

    @EnvironmentObject private var environmentState: EnvironmentState
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var appearanceStore: AppearanceStore

    var tabBarStyle: WorkspaceTabBarStyle

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        winLog.warning("makeNSView called")
        DispatchQueue.main.async {
            guard let window = view.window else { winLog.warning("makeNSView: no window"); return }
            winLog.warning("makeNSView: configuring with window")
            context.coordinator.configure(
                window: window,
                environmentState: environmentState,
                appState: appState,
                appearanceStore: appearanceStore,
                projectStore: projectStore,
                connectionStore: connectionStore,
                navigationStore: navigationStore,
                tabStore: tabStore
            )
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            context.coordinator.configure(
                window: window,
                environmentState: environmentState,
                appState: appState,
                appearanceStore: appearanceStore,
                projectStore: projectStore,
                connectionStore: connectionStore,
                navigationStore: navigationStore,
                tabStore: tabStore
            )
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSWindowDelegate {
        private var lastWindowID: ObjectIdentifier?
        private var lastKeyState: Bool?
        private let overlay = TopBarNavigatorOverlay()

        func configure(
            window: NSWindow,
            environmentState: EnvironmentState,
            appState: AppState,
            appearanceStore: AppearanceStore,
            projectStore: ProjectStore,
            connectionStore: ConnectionStore,
            navigationStore: NavigationStore,
            tabStore: TabStore
        ) {
            let windowID = ObjectIdentifier(window)
            if lastWindowID != windowID { lastWindowID = windowID }
            applyWindowStyling(window)
            if window.delegate !== self { window.delegate = self }
            let isKey = window.isKeyWindow && window.identifier == AppWindowIdentifier.workspace
            if lastKeyState != isKey { navigationStore.isWorkspaceWindowKey = isKey; lastKeyState = isKey }

            overlay.apply(
                window: window,
                environmentState: environmentState,
                appState: appState,
                appearanceStore: appearanceStore,
                projectStore: projectStore,
                connectionStore: connectionStore,
                navigationStore: navigationStore,
                tabStore: tabStore,
                isEnabled: true
            )
        }

        private func applyWindowStyling(_ window: NSWindow) {
            if window.identifier != AppWindowIdentifier.workspace { window.identifier = AppWindowIdentifier.workspace }
            if window.titleVisibility != .visible { window.titleVisibility = .visible }
            if !window.titlebarAppearsTransparent { window.titlebarAppearsTransparent = true }
            if window.title != " " { window.title = " " }
            if window.toolbarStyle != .unified { window.toolbarStyle = .unified }
            if #unavailable(macOS 15) { window.toolbar?.showsBaselineSeparator = false }
            if window.toolbar?.allowsUserCustomization != false { window.toolbar?.allowsUserCustomization = false }
            let contentMinWidth: CGFloat = 980
            if window.contentMinSize.width < contentMinWidth { window.contentMinSize.width = contentMinWidth }
            let chromeDelta = window.frame.width - window.contentLayoutRect.width
            if window.minSize.width < (contentMinWidth + chromeDelta) { window.minSize.width = contentMinWidth + chromeDelta }
        }

        func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
            let minFrameWidth: CGFloat = 980 + (sender.frame.width - sender.contentLayoutRect.width)
            var size = frameSize
            if size.width < minFrameWidth { size.width = minFrameWidth }
            return size
        }

        nonisolated deinit {
            MainActor.assumeIsolated {
                overlay.detach()
            }
        }
    }
}
#else
struct WorkspaceWindowConfigurator: UIViewRepresentable {
    var tabBarStyle: WorkspaceTabBarStyle
    func makeUIView(context: Context) -> UIView { UIView() }
    func updateUIView(_ uiView: UIView, context: Context) {}
}
#endif
