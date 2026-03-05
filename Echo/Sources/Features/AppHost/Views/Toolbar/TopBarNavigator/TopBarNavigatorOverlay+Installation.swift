import SwiftUI
import os.log

#if os(macOS)
import AppKit

private let installLog = Logger(subsystem: "com.echo.overlay", category: "install")

extension TopBarNavigatorOverlay {
    func apply(
        window: NSWindow,
        environmentState: EnvironmentState,
        appState: AppState,
        appearanceStore: AppearanceStore,
        projectStore: ProjectStore,
        connectionStore: ConnectionStore,
        navigationStore: NavigationStore,
        tabStore: TabStore,
        isEnabled: Bool
    ) {
        let stateInstancesChanged = self.appState !== appState || self.navigationStore !== navigationStore
        self.environmentState = environmentState
        self.appState = appState
        self.navigationStore = navigationStore
        if stateInstancesChanged || stateCancellables.isEmpty {
            configureStateObservers(appState: appState, navigationStore: navigationStore)
        }

        if !isEnabled {
            detach()
            return
        }

        installIfNeeded(
            window: window,
            environmentState: environmentState,
            appState: appState,
            appearanceStore: appearanceStore,
            projectStore: projectStore,
            connectionStore: connectionStore,
            navigationStore: navigationStore,
            tabStore: tabStore
        )
        scheduleLayoutUpdate()
    }

    func detach() {
        removeObservers()
        removeItemObservers()
        removeHitProxy()
        stateCancellables.removeAll()
        pendingLayoutUpdate = false
        hasCompletedInitialLayout = false

        if let containerView {
            removeExistingHostingViews(from: containerView, keeping: nil)
        }
        if let toolbarView {
            removeExistingHostingViews(from: toolbarView, keeping: nil)
        }
        hostingView?.removeFromSuperview()
        hostingView = nil
        containerView = nil
        toolbarView = nil
        window = nil
    }

    func installIfNeeded(
        window: NSWindow,
        environmentState: EnvironmentState,
        appState: AppState,
        appearanceStore: AppearanceStore,
        projectStore: ProjectStore,
        connectionStore: ConnectionStore,
        navigationStore: NavigationStore,
        tabStore: TabStore
    ) {
        if let hostingView, let toolbarView, let containerView {
            removeExistingHostingViews(from: containerView, keeping: hostingView)
            if hostingView.superview !== containerView {
                hostingView.removeFromSuperview()
                addHostingView(hostingView, toolbarView: toolbarView, containerView: containerView, window: window)
                hostingView.rootView = makeRootView(
                    environmentState: environmentState,
                    appState: appState,
                    appearanceStore: appearanceStore,
                    projectStore: projectStore,
                    connectionStore: connectionStore,
                    navigationStore: navigationStore,
                    tabStore: tabStore
                )
            }
            installHitProxy(hostingView: hostingView, toolbarView: toolbarView)
            scheduleLayoutUpdate()
            return
        }

        guard let toolbarView = findToolbarView(in: window),
              let containerView = toolbarView.superview else {
            installLog.warning("installIfNeeded: findToolbarView returned nil")
            return
        }
        installLog.warning("installIfNeeded: FRESH INSTALL")
        toolbarView.postsFrameChangedNotifications = true
        removeExistingHostingViews(from: containerView, keeping: nil)
        removeExistingHostingViews(from: toolbarView, keeping: nil)

        let hostingView = TopBarNavigatorHostingView(
            rootView: makeRootView(
                environmentState: environmentState,
                appState: appState,
                appearanceStore: appearanceStore,
                projectStore: projectStore,
                connectionStore: connectionStore,
                navigationStore: navigationStore,
                tabStore: tabStore
            )
        )

        addHostingView(hostingView, toolbarView: toolbarView, containerView: containerView, window: window)
        registerObservers(window: window, toolbarView: toolbarView)
        installHitProxy(hostingView: hostingView, toolbarView: toolbarView)
    }

    func addHostingView(
        _ hostingView: TopBarNavigatorHostingView,
        toolbarView: NSView,
        containerView: NSView,
        window: NSWindow
    ) {
        hostingView.identifier = hostingViewIdentifier
        hostingView.translatesAutoresizingMaskIntoConstraints = true
        containerView.addSubview(hostingView, positioned: .above, relativeTo: toolbarView)

        let h = WorkspaceChromeMetrics.toolbarTabBarHeight
        let toolbarFrame = toolbarView.frame
        hostingView.frame = NSRect(
            x: toolbarFrame.origin.x,
            y: toolbarFrame.origin.y + (toolbarFrame.height - h) / 2,
            width: toolbarFrame.width, height: h
        )

        self.hostingView = hostingView
        self.containerView = containerView
        self.toolbarView = toolbarView
        self.window = window
    }

    // MARK: - Hit Proxy
    // NSTitlebarContainerView's hitTest does not traverse to our hosting
    // view because it lives outside NSToolbarView. We place a transparent
    // proxy view INSIDE NSToolbarView that delegates hitTest to the
    // hosting view, enabling normal NSWindow.sendEvent event dispatch.

    private static let hitProxyIdentifier = NSUserInterfaceItemIdentifier("TopBarNavigatorHitProxy")

    func installHitProxy(hostingView: TopBarNavigatorHostingView, toolbarView: NSView) {
        if let existing = hitProxyView, existing.superview === toolbarView {
            existing.hostingView = hostingView
            return
        }
        hitProxyView?.removeFromSuperview()

        let proxy = TopBarNavigatorHitProxy()
        proxy.identifier = Self.hitProxyIdentifier
        proxy.translatesAutoresizingMaskIntoConstraints = true
        proxy.hostingView = hostingView
        // Place at the front of toolbar's subview list so hitTest finds it first.
        toolbarView.addSubview(proxy, positioned: .above, relativeTo: nil)
        hitProxyView = proxy
    }

    func removeHitProxy() {
        hitProxyView?.removeFromSuperview()
        hitProxyView = nil
    }

    func removeExistingHostingViews(from parentView: NSView, keeping view: NSView?) {
        for subview in parentView.subviews where subview.identifier == hostingViewIdentifier {
            if let view, subview === view { continue }
            subview.removeFromSuperview()
        }
    }

    func makeRootView(
        environmentState: EnvironmentState,
        appState: AppState,
        appearanceStore: AppearanceStore,
        projectStore: ProjectStore,
        connectionStore: ConnectionStore,
        navigationStore: NavigationStore,
        tabStore: TabStore
    ) -> AnyView {
        AnyView(
            TopBarNavigator()
                .environment(projectStore)
                .environment(connectionStore)
                .environment(navigationStore)
                .environment(tabStore)
                .environmentObject(environmentState)
                .environmentObject(appState)
                .environmentObject(appearanceStore)
                .environmentObject(layoutState)
        )
    }
}
#endif
