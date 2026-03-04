import SwiftUI
import Combine

#if os(macOS)
import AppKit

/// Positions `TopBarNavigator` inside the macOS unified toolbar, centered between
/// the navigation items (left) and primary actions (right). The overlay stretches
/// to the available region; the navigator view then centers itself and computes
/// its own width (3/5 rule with min/ideal/max bounds).
@MainActor
final class TopBarNavigatorOverlay {
    private weak var hostingView: TopBarNavigatorHostingView?
    private weak var toolbarView: NSView?
    private weak var window: NSWindow?
    private weak var appModel: AppModel?
    private weak var appState: AppState?
    private weak var navigationStore: NavigationStore?

    private var leadingConstraint: NSLayoutConstraint?
    private var trailingConstraint: NSLayoutConstraint?
    private var centerYConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?

    private var observers: [NSObjectProtocol] = []
    private var itemObservers: [NSObjectProtocol] = []
    private var observedItemIdentifiers: [NSToolbarItem.Identifier] = []
    private var observedViewIDs: Set<ObjectIdentifier> = []
    private var pendingLayoutUpdate = false
    private var lastLayoutState: LayoutState?
    private var stateCancellables: Set<AnyCancellable> = []
    private let layoutState = TopBarNavigatorLayoutState()

    private let navigationPrefix = "workspace.navigation"
    private let primaryPrefix = "workspace.primary"
    private let leadingPadding: CGFloat = 18
    private let trailingPadding: CGFloat = 12
    // Tiny upward nudge to visually align with circular toolbar buttons.
    private let verticalInset: CGFloat = -0.5
    // Fraction of the inspector width we project into the toolbar layout.
    // Using the full width makes the center region collapse too far when
    // the inspector is visible; Xcode keeps the pill only slightly
    // narrower, so we intentionally use a partial influence.
    private let inspectorInfluence: CGFloat = 0.55
    // Sidebar influence mirrors inspector behavior for Xcode-like centering.
    private let sidebarInfluence: CGFloat = 0.55
    private let minimumAvailableWidth: CGFloat = 420
    private let hostingViewIdentifier = NSUserInterfaceItemIdentifier("TopBarNavigatorHostingView")

    func apply(
        window: NSWindow,
        appModel: AppModel,
        appState: AppState,
        themeManager: ThemeManager,
        projectStore: ProjectStore,
        connectionStore: ConnectionStore,
        navigationStore: NavigationStore,
        tabStore: TabStore,
        isEnabled: Bool
    ) {
        self.appModel = appModel
        self.appState = appState
        self.navigationStore = navigationStore
        configureStateObservers(appState: appState, navigationStore: navigationStore)

        if !isEnabled {
            detach()
            return
        }

        installIfNeeded(
            window: window,
            appModel: appModel,
            appState: appState,
            themeManager: themeManager,
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

    private func installIfNeeded(
        window: NSWindow,
        appModel: AppModel,
        appState: AppState,
        themeManager: ThemeManager,
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
                appModel: appModel,
                appState: appState,
                themeManager: themeManager,
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
                appModel: appModel,
                appState: appState,
                themeManager: themeManager,
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

    private func addHostingView(
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

    private func removeExistingHostingViews(from toolbarView: NSView, keeping view: NSView?) {
        for subview in toolbarView.subviews where subview.identifier == hostingViewIdentifier {
            if let view, subview === view { continue }
            subview.removeFromSuperview()
        }
    }

    private func makeRootView(
        appModel: AppModel,
        appState: AppState,
        themeManager: ThemeManager,
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
                .environmentObject(appModel)
                .environmentObject(appState)
                .environmentObject(themeManager)
                .environmentObject(layoutState)
        )
    }

    private func registerObservers(window: NSWindow, toolbarView: NSView) {
        removeObservers()
        let center = NotificationCenter.default

        observers.append(
            center.addObserver(
                forName: NSView.frameDidChangeNotification,
                object: toolbarView,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in self?.scheduleLayoutUpdate() }
            }
        )

        observers.append(
            center.addObserver(
                forName: NSWindow.didResizeNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in self?.scheduleLayoutUpdate() }
            }
        )

        observers.append(
            center.addObserver(
                forName: NSWindow.didEndLiveResizeNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in self?.scheduleLayoutUpdate() }
            }
        )
    }

    private func removeObservers() {
        let center = NotificationCenter.default
        observers.forEach { center.removeObserver($0) }
        observers.removeAll()
    }

    private func configureStateObservers(appState: AppState, navigationStore: NavigationStore) {
        stateCancellables.removeAll()

        appState.$workspaceSidebarWidth
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.scheduleLayoutUpdate() }
            .store(in: &stateCancellables)

        appState.$workspaceSidebarVisibility
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.scheduleLayoutUpdate() }
            .store(in: &stateCancellables)

        appState.$showInfoSidebar
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.scheduleLayoutUpdate() }
            .store(in: &stateCancellables)

        // Observe inspectorWidth via withObservationTracking or a bridge if needed
        // For simplicity, we trigger a manual update when it changes if possible.
    }

    private func updateToolbarItemObservers(toolbar: NSToolbar, toolbarView: NSView) {
        let identifiers = toolbar.items.map(\.itemIdentifier)
        var targets: [NSView] = []
        for item in toolbar.items {
            guard let view = item.view else { continue }
            if let container = view.superview {
                targets.append(container)
            }
            targets.append(view)
        }
        if targets.isEmpty {
            targets = toolbarView.subviews
        }

        let viewIDs = Set(targets.map { ObjectIdentifier($0) })
        guard identifiers != observedItemIdentifiers || viewIDs != observedViewIDs else { return }

        observedItemIdentifiers = identifiers
        observedViewIDs = viewIDs
        removeItemObservers()

        let center = NotificationCenter.default
        for view in targets {
            disableImplicitAnimations(for: view)
            view.postsFrameChangedNotifications = true
            itemObservers.append(
                center.addObserver(
                    forName: NSView.frameDidChangeNotification,
                    object: view,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in self?.scheduleLayoutUpdate() }
                }
            )
        }
        disableImplicitFrameAnimationsRecursively(in: toolbarView)
    }

    private func removeItemObservers() {
        let center = NotificationCenter.default
        itemObservers.forEach { center.removeObserver($0) }
        itemObservers.removeAll()
        observedItemIdentifiers = []
        observedViewIDs = []
    }

    private func disableImplicitAnimations(for view: NSView) {
        var animations = view.animations
        animations["frameOrigin"] = NSNull()
        animations["frameSize"] = NSNull()
        animations["bounds"] = NSNull()
        animations["position"] = NSNull()
        view.animations = animations
    }

    private func disableImplicitFrameAnimationsRecursively(in view: NSView) {
        disableImplicitAnimations(for: view)
        for subview in view.subviews {
            disableImplicitFrameAnimationsRecursively(in: subview)
        }
    }

    private func scheduleLayoutUpdate() {
        guard !pendingLayoutUpdate else { return }
        pendingLayoutUpdate = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.pendingLayoutUpdate = false
            self.updateLayout()
        }
    }

    private func updateLayout() {
        guard let toolbarView, let _ = hostingView, let window, let toolbar = window.toolbar else { return }
        toolbarView.layoutSubtreeIfNeeded()
        updateToolbarItemObservers(toolbar: toolbar, toolbarView: toolbarView)

        let bounds = toolbarView.bounds
        let navigationFrames = toolbar.items
            .filter { $0.itemIdentifier.rawValue.hasPrefix(navigationPrefix) }
            .flatMap { frames(for: $0, in: toolbarView) }

        let primaryFrames = toolbar.items
            .filter { $0.itemIdentifier.rawValue.hasPrefix(primaryPrefix) }
            .flatMap { frames(for: $0, in: toolbarView) }

        let navigationMaxX = navigationFrames.map(\.maxX).max() ?? 0
        let primaryMinX = primaryFrames.map(\.minX).min() ?? bounds.width

        let leftEdge = max(leadingPadding, navigationMaxX + leadingPadding)
        let rightEdge = min(bounds.width - trailingPadding, primaryMinX - trailingPadding)
        let regionWidth = max(0, rightEdge - leftEdge)
        let regionCenterX = (leftEdge + rightEdge) / 2

        // If the sidebar/inspector are visible, shrink the available region
        // while keeping the pill centered.
        let contentWidth = window.contentLayoutRect.width
        var shrink: CGFloat = 0
        if contentWidth > 0 {
            let scale = bounds.width / contentWidth
            let sidebarWidth: CGFloat
            if let appState, appState.workspaceSidebarVisibility != .detailOnly {
                sidebarWidth = appState.workspaceSidebarWidth
            } else {
                sidebarWidth = 0
            }

            let inspectorWidth: CGFloat
            if let appState, appState.showInfoSidebar, let navStore = navigationStore {
                inspectorWidth = navStore.inspectorWidth
            } else {
                inspectorWidth = 0
            }

            shrink = (sidebarWidth * sidebarInfluence + inspectorWidth * inspectorInfluence) * scale
        }

        let minAllowed = min(minimumAvailableWidth, regionWidth)
        let availableWidth = max(minAllowed, regionWidth - shrink)
        layoutState.update(availableWidth: availableWidth, centerX: regionCenterX, toolbarWidth: bounds.width)

        let desiredHeight: CGFloat
        let centerOffset: CGFloat
        if let metrics = referenceMetrics(in: toolbarView, toolbar: toolbar) {
            // Match the tallest native toolbar control so the pill aligns
            // with the “Default”/segmented toolbar buttons.
            desiredHeight = metrics.height
            centerOffset = metrics.midY - bounds.midY + verticalInset
        } else {
            desiredHeight = WorkspaceChromeMetrics.toolbarTabBarHeight
            centerOffset = verticalInset
        }

        let layoutState = LayoutState(height: desiredHeight, centerOffset: centerOffset)

        if let lastLayoutState, lastLayoutState.isApproximatelyEqual(to: layoutState) { return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            context.allowsImplicitAnimation = false
            apply(constraint: leadingConstraint, constant: 0)
            apply(constraint: trailingConstraint, constant: 0)
            apply(constraint: heightConstraint, constant: layoutState.height)
            apply(constraint: centerYConstraint, constant: layoutState.centerOffset)
        }

        lastLayoutState = layoutState
    }

    private func referenceMetrics(in toolbarView: NSView, toolbar: NSToolbar) -> (height: CGFloat, midY: CGFloat)? {
        let candidateViews = toolbar.items.compactMap { $0.view }
        guard let referenceView = candidateViews.max(by: { $0.bounds.height < $1.bounds.height }) else {
            return nil
        }
        let frame = toolbarView.convert(referenceView.bounds, from: referenceView)
        return (frame.height, frame.midY)
    }

    private func frames(for item: NSToolbarItem, in container: NSView) -> [CGRect] {
        guard let view = item.view else { return [] }
        var frames: [CGRect] = [container.convert(view.bounds, from: view)]
        if let superview = view.superview {
            frames.append(container.convert(superview.bounds, from: superview))
        }
        return frames
    }

    private func apply(constraint: NSLayoutConstraint?, constant: CGFloat) {
        guard let constraint else { return }
        if abs(constraint.constant - constant) > 0.25 {
            constraint.constant = constant
        }
    }

    private func findToolbarView(in window: NSWindow) -> NSView? {
        guard let titlebarContainer = window.contentView?.superview else { return nil }
        var views: [NSView] = [titlebarContainer]

        while let view = views.popLast() {
            let className = String(describing: type(of: view))
            if className.contains("NSTitlebarContainerView") {
                views.append(contentsOf: view.subviews)
                continue
            }
            if className.contains("NSToolbarView") {
                return view
            }
            views.append(contentsOf: view.subviews)
        }

        return nil
    }

    private struct LayoutState: Equatable {
        let height: CGFloat
        let centerOffset: CGFloat

        func isApproximatelyEqual(to other: LayoutState, tolerance: CGFloat = 0.5) -> Bool {
            return abs(height - other.height) <= tolerance &&
                abs(centerOffset - other.centerOffset) <= tolerance
        }
    }
}

private final class TopBarNavigatorHostingView: NSHostingView<AnyView> {
    required init(rootView: AnyView) {
        super.init(rootView: rootView)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.masksToBounds = false
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func hitTest(_ point: NSPoint) -> NSView? {
        super.hitTest(point)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override var mouseDownCanMoveWindow: Bool {
        false
    }
}

#endif

final class TopBarNavigatorLayoutState: ObservableObject {
    @Published private(set) var availableWidth: CGFloat = 0
    @Published private(set) var centerX: CGFloat = 0
    @Published private(set) var toolbarWidth: CGFloat = 0

    func update(availableWidth: CGFloat, centerX: CGFloat, toolbarWidth: CGFloat) {
        if abs(self.availableWidth - availableWidth) > 0.5 {
            self.availableWidth = availableWidth
        }
        if abs(self.centerX - centerX) > 0.5 {
            self.centerX = centerX
        }
        if abs(self.toolbarWidth - toolbarWidth) > 0.5 {
            self.toolbarWidth = toolbarWidth
        }
    }
}
