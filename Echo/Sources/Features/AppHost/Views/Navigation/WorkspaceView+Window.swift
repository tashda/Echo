import SwiftUI
#if os(macOS)
import AppKit

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
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            context.coordinator.configure(window: window, tabBarStyle: tabBarStyle, environmentState: environmentState, appState: appState, appearanceStore: appearanceStore, projectStore: projectStore, connectionStore: connectionStore, navigationStore: navigationStore, tabStore: tabStore)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            context.coordinator.configure(window: window, tabBarStyle: tabBarStyle, environmentState: environmentState, appState: appState, appearanceStore: appearanceStore, projectStore: projectStore, connectionStore: connectionStore, navigationStore: navigationStore, tabStore: tabStore)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSWindowDelegate {
        private let topBarNavigatorOverlay = TopBarNavigatorOverlay()
        private var lastWindowID: ObjectIdentifier?
        private var lastStyle: WorkspaceTabBarStyle?
        private var lastKeyState: Bool?

        func configure(window: NSWindow, tabBarStyle: WorkspaceTabBarStyle, environmentState: EnvironmentState, appState: AppState, appearanceStore: AppearanceStore, projectStore: ProjectStore, connectionStore: ConnectionStore, navigationStore: NavigationStore, tabStore: TabStore) {
            let windowID = ObjectIdentifier(window)
            if lastWindowID != windowID { topBarNavigatorOverlay.detach(); lastWindowID = windowID }
            applyWindowStyling(window)
            if window.delegate !== self { window.delegate = self }
            lastStyle = tabBarStyle
            topBarNavigatorOverlay.apply(window: window, environmentState: environmentState, appState: appState, appearanceStore: appearanceStore, projectStore: projectStore, connectionStore: connectionStore, navigationStore: navigationStore, tabStore: tabStore, isEnabled: true)
            let isKey = window.isKeyWindow && window.identifier == AppWindowIdentifier.workspace
            if lastKeyState != isKey { navigationStore.isWorkspaceWindowKey = isKey; lastKeyState = isKey }
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
            let minContent = requiredContentWidth(for: sender)
            let chromeDelta = sender.frame.width - sender.contentLayoutRect.width
            let minFrameWidth = minContent + chromeDelta
            var size = frameSize
            if size.width < minFrameWidth { size.width = minFrameWidth }
            return size
        }

        private func requiredContentWidth(for window: NSWindow) -> CGFloat {
            guard let toolbar = window.toolbar, let toolbarView = findToolbarView(in: window) else { return 980 }
            let navMaxX = toolbar.items.filter { $0.itemIdentifier.rawValue.hasPrefix("workspace.navigation") }.compactMap { $0.view }.map { toolbarView.convert($0.bounds, from: $0).maxX }.max() ?? 0
            let primaryFrames = toolbar.items.filter { $0.itemIdentifier.rawValue.hasPrefix("workspace.primary") }.compactMap { $0.view }.map { toolbarView.convert($0.bounds, from: $0) }
            let primaryGroupWidth = primaryFrames.isEmpty ? 0 : (primaryFrames.map(\.maxX).max()! - primaryFrames.map(\.minX).min()!)
            return max(980, navMaxX + 18 + primaryGroupWidth + 24 + 350)
        }

        private func findToolbarView(in window: NSWindow) -> NSView? {
            guard let container = window.contentView?.superview else { return nil }
            var stack: [NSView] = [container]
            while let view = stack.popLast() {
                let name = String(describing: type(of: view))
                if name.contains("NSTitlebarContainerView") { stack.append(contentsOf: view.subviews); continue }
                if name.contains("NSToolbarView") { return view }
                stack.append(contentsOf: view.subviews)
            }
            return nil
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
