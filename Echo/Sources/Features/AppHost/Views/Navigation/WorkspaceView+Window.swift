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
            context.coordinator.configure(
                window: window,
                environmentState: environmentState,
                connectionStore: connectionStore,
                navigationStore: navigationStore
            )
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Read observable property to establish SwiftUI tracking dependency
        let _ = navigationStore.breadcrumbPopoverRequest

        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            context.coordinator.configure(
                window: window,
                environmentState: environmentState,
                connectionStore: connectionStore,
                navigationStore: navigationStore
            )
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSWindowDelegate, NSPopoverDelegate {
        private var lastWindowID: ObjectIdentifier?
        private var lastKeyState: Bool?
        private var widthConstraint: NSLayoutConstraint?
        private var activePopover: NSPopover?

        func configure(
            window: NSWindow,
            environmentState: EnvironmentState,
            connectionStore: ConnectionStore,
            navigationStore: NavigationStore
        ) {
            let windowID = ObjectIdentifier(window)
            if lastWindowID != windowID { lastWindowID = windowID }
            applyWindowStyling(window)
            configurePrincipalItem(window)
            if window.delegate !== self { window.delegate = self }
            let isKey = window.isKeyWindow && window.identifier == AppWindowIdentifier.workspace
            if lastKeyState != isKey { navigationStore.isWorkspaceWindowKey = isKey; lastKeyState = isKey }

            if let request = navigationStore.breadcrumbPopoverRequest {
                navigationStore.breadcrumbPopoverRequest = nil
                presentBreadcrumbPopover(
                    request,
                    from: window,
                    connectionStore: connectionStore,
                    environmentState: environmentState
                )
            }
        }

        // MARK: - Breadcrumb Popover

        private func presentBreadcrumbPopover(
            _ request: NavigationStore.BreadcrumbPopover,
            from window: NSWindow,
            connectionStore: ConnectionStore,
            environmentState: EnvironmentState
        ) {
            activePopover?.close()
            activePopover = nil

            guard let toolbar = window.toolbar else { return }
            var itemView: NSView?
            for item in toolbar.items where item.itemIdentifier.rawValue.lowercased().contains("breadcrumb") {
                itemView = item.view
                break
            }
            guard let itemView else { return }

            // Build popover content
            let contentView: AnyView
            switch request {
            case .connections:
                contentView = AnyView(
                    ConnectionsPopoverContent(
                        connectionStore: connectionStore,
                        environmentState: environmentState,
                        dismiss: { [weak self] in self?.activePopover?.close() }
                    )
                    .environment(connectionStore)
                    .environmentObject(environmentState)
                )
            case .database:
                contentView = AnyView(
                    DatabaseBreadcrumbMenu()
                        .environment(connectionStore)
                        .environmentObject(environmentState)
                )
            }

            let hosting = NSHostingController(rootView: contentView)
            hosting.sizingOptions = [.intrinsicContentSize]

            let popover = NSPopover()
            popover.behavior = .transient
            popover.animates = true
            popover.delegate = self
            popover.contentViewController = hosting
            activePopover = popover

            // Walk up from itemView to find its NSToolbarItemViewer container,
            // which has the correct frame for positioning.
            var anchorView: NSView = itemView
            var parent = itemView.superview
            while let p = parent {
                let className = NSStringFromClass(type(of: p))
                if className.contains("ItemViewer") {
                    anchorView = p
                    break
                }
                parent = p.superview
            }

            popover.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: .minY)
        }

        nonisolated func popoverDidClose(_ notification: Notification) {
            MainActor.assumeIsolated {
                activePopover = nil
            }
        }

        // MARK: - Principal Item Sizing

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

        private func applyWindowStyling(_ window: NSWindow) {
            if window.identifier != AppWindowIdentifier.workspace { window.identifier = AppWindowIdentifier.workspace }
            if window.titleVisibility != .hidden { window.titleVisibility = .hidden }
            if window.title != "" { window.title = "" }
            if !window.titlebarAppearsTransparent { window.titlebarAppearsTransparent = true }
            if window.toolbarStyle != .unified { window.toolbarStyle = .unified }
            if window.titlebarSeparatorStyle != .none { window.titlebarSeparatorStyle = .none }
            if window.toolbar?.allowsUserCustomization != false { window.toolbar?.allowsUserCustomization = false }
            let contentMinWidth: CGFloat = 980
            if window.contentMinSize.width < contentMinWidth { window.contentMinSize.width = contentMinWidth }
            let chromeDelta = window.frame.width - window.contentLayoutRect.width
            if window.minSize.width < (contentMinWidth + chromeDelta) { window.minSize.width = contentMinWidth + chromeDelta }
        }

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
#else
struct WorkspaceWindowConfigurator: UIViewRepresentable {
    var tabBarStyle: WorkspaceTabBarStyle
    func makeUIView(context: Context) -> UIView { UIView() }
    func updateUIView(_ uiView: UIView, context: Context) {}
}
#endif
