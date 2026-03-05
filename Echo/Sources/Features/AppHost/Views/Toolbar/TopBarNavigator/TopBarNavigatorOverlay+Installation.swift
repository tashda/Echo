import SwiftUI

#if os(macOS)
import AppKit

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
        self.environmentState = environmentState
        self.appState = appState
        self.navigationStore = navigationStore
        configureStateObservers(appState: appState, navigationStore: navigationStore)

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
        stateCancellables.removeAll()
        pendingLayoutUpdate = false
        leadingConstraint?.isActive = false
        trailingConstraint?.isActive = false
        centerYConstraint?.isActive = false
        heightConstraint?.isActive = false
        leadingConstraint = nil
        trailingConstraint = nil
        centerYConstraint = nil
        heightConstraint = nil

        if let toolbarView {
            removeExistingHostingViews(from: toolbarView, keeping: nil)
        }
        hostingView?.removeFromSuperview()
        hostingView = nil
        toolbarView = nil
        window = nil
        lastLayoutState = nil
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
        if let hostingView, let toolbarView {
            removeExistingHostingViews(from: toolbarView, keeping: hostingView)
            if hostingView.superview !== toolbarView {
                hostingView.removeFromSuperview()
                removeExistingHostingViews(from: toolbarView, keeping: nil)
                addHostingView(
                    hostingView,
                    to: toolbarView,
                    window: window
                )
            }
            hostingView.rootView = makeRootView(
                environmentState: environmentState,
                appState: appState,
                appearanceStore: appearanceStore,
                projectStore: projectStore,
                connectionStore: connectionStore,
                navigationStore: navigationStore,
                tabStore: tabStore
            )
            lastLayoutState = nil
            toolbarView.layoutSubtreeIfNeeded()
            scheduleLayoutUpdate()
            return
        }

        guard let toolbarView = findToolbarView(in: window) else { return }
        toolbarView.postsFrameChangedNotifications = true
        disableImplicitFrameAnimationsRecursively(in: toolbarView)
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

        addHostingView(
            hostingView,
            to: toolbarView,
            window: window
        )

        registerObservers(window: window, toolbarView: toolbarView)
        toolbarView.layoutSubtreeIfNeeded()
    }

    func addHostingView(
        _ hostingView: TopBarNavigatorHostingView,
        to toolbarView: NSView,
        window: NSWindow
    ) {
        hostingView.identifier = hostingViewIdentifier
        toolbarView.addSubview(hostingView, positioned: .above, relativeTo: nil)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        let leading = hostingView.leadingAnchor.constraint(equalTo: toolbarView.leadingAnchor)
        let trailing = hostingView.trailingAnchor.constraint(equalTo: toolbarView.trailingAnchor)
        leading.priority = .required
        trailing.priority = .required
        let centerY = hostingView.centerYAnchor.constraint(equalTo: toolbarView.centerYAnchor)
        let height = hostingView.heightAnchor.constraint(equalToConstant: WorkspaceChromeMetrics.toolbarTabBarHeight)

        NSLayoutConstraint.activate([leading, trailing, centerY, height])

        self.hostingView = hostingView
        self.toolbarView = toolbarView
        self.window = window
        leadingConstraint = leading
        trailingConstraint = trailing
        centerYConstraint = centerY
        heightConstraint = height

        hostingView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        hostingView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    func removeExistingHostingViews(from toolbarView: NSView, keeping view: NSView?) {
        for subview in toolbarView.subviews where subview.identifier == hostingViewIdentifier {
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
