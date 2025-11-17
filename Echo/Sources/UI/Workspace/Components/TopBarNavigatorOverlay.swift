import SwiftUI

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

    private var leadingConstraint: NSLayoutConstraint?
    private var trailingConstraint: NSLayoutConstraint?
    private var centerYConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?

    private var observers: [NSObjectProtocol] = []
    private var pendingLayoutUpdate = false
    private var lastLayoutState: LayoutState?

    private let navigationPrefix = "workspace.navigation"
    private let primaryPrefix = "workspace.primary"
    private let leadingPadding: CGFloat = 18
    private let trailingPadding: CGFloat = 12
    // Tiny upward nudge to visually align with circular toolbar buttons.
    private let verticalInset: CGFloat = -0.5

    func apply(
        window: NSWindow,
        appModel: AppModel,
        appState: AppState,
        themeManager: ThemeManager,
        isEnabled: Bool
    ) {
        if !isEnabled {
            detach()
            return
        }

        installIfNeeded(
            window: window,
            appModel: appModel,
            appState: appState,
            themeManager: themeManager
        )
        scheduleLayoutUpdate()
    }

    func detach() {
        removeObservers()
        pendingLayoutUpdate = false
        leadingConstraint?.isActive = false
        trailingConstraint?.isActive = false
        centerYConstraint?.isActive = false
        heightConstraint?.isActive = false
        leadingConstraint = nil
        trailingConstraint = nil
        centerYConstraint = nil
        heightConstraint = nil

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
        themeManager: ThemeManager
    ) {
        if let hostingView {
            hostingView.rootView = makeRootView(
                appModel: appModel,
                appState: appState,
                themeManager: themeManager
            )
            lastLayoutState = nil
            toolbarView?.layoutSubtreeIfNeeded()
            scheduleLayoutUpdate()
            return
        }

        guard let toolbarView = findToolbarView(in: window) else { return }
        toolbarView.postsFrameChangedNotifications = true

        let hostingView = TopBarNavigatorHostingView(
            rootView: makeRootView(
                appModel: appModel,
                appState: appState,
                themeManager: themeManager
            )
        )

        toolbarView.addSubview(hostingView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        let leading = hostingView.leadingAnchor.constraint(equalTo: toolbarView.leadingAnchor)
        let trailing = hostingView.trailingAnchor.constraint(equalTo: toolbarView.trailingAnchor)
        leading.priority = .defaultHigh
        trailing.priority = .defaultHigh
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

        registerObservers(window: window, toolbarView: toolbarView)
        toolbarView.layoutSubtreeIfNeeded()
    }

    private func makeRootView(
        appModel: AppModel,
        appState: AppState,
        themeManager: ThemeManager
    ) -> AnyView {
        AnyView(
            TopBarNavigator()
                .environmentObject(appModel)
                .environmentObject(appState)
                .environmentObject(themeManager)
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
        guard let toolbarView, let hostingView, let window, let toolbar = window.toolbar else { return }

        let bounds = toolbarView.bounds
        let navigationMaxX = toolbar.items
            .filter { $0.itemIdentifier.rawValue.hasPrefix(navigationPrefix) }
            .compactMap { frame(of: $0, in: toolbarView)?.maxX }
            .max() ?? 0

        let primaryMinX = toolbar.items
            .filter { $0.itemIdentifier.rawValue.hasPrefix(primaryPrefix) }
            .compactMap { frame(of: $0, in: toolbarView)?.minX }
            .min() ?? bounds.width

        let leadingInset = max(navigationMaxX + leadingPadding, leadingPadding)
        let trailingInset = max(bounds.width - primaryMinX + trailingPadding, trailingPadding)
        let availableWidth = bounds.width - leadingInset - trailingInset

        let desiredHeight: CGFloat
        let centerOffset: CGFloat
        if let refHeight = referenceHeight(in: toolbarView, toolbar: toolbar) {
            desiredHeight = max(refHeight, WorkspaceChromeMetrics.toolbarTabBarHeight)
            centerOffset = (referenceMidY(in: toolbarView, toolbar: toolbar) ?? bounds.midY) - bounds.midY + verticalInset
        } else {
            desiredHeight = WorkspaceChromeMetrics.toolbarTabBarHeight
            centerOffset = verticalInset
        }

        let layoutState = LayoutState(
            leading: leadingInset,
            trailing: -trailingInset,
            height: desiredHeight,
            centerOffset: centerOffset,
            isHidden: availableWidth < 350 // hide when we can't honor the minimum
        )

        if let lastLayoutState, lastLayoutState.isApproximatelyEqual(to: layoutState) { return }

        apply(constraint: leadingConstraint, constant: layoutState.leading)
        apply(constraint: trailingConstraint, constant: layoutState.trailing)
        apply(constraint: heightConstraint, constant: layoutState.height)
        apply(constraint: centerYConstraint, constant: layoutState.centerOffset)

        if hostingView.isHidden != layoutState.isHidden {
            hostingView.isHidden = layoutState.isHidden
        }

        lastLayoutState = layoutState
    }

    private func referenceHeight(in toolbarView: NSView, toolbar: NSToolbar) -> CGFloat? {
        let candidateViews = toolbar.items.compactMap { $0.view }
        guard let referenceView = candidateViews.first else { return nil }
        return toolbarView.convert(referenceView.bounds, from: referenceView).height
    }

    private func referenceMidY(in toolbarView: NSView, toolbar: NSToolbar) -> CGFloat? {
        let candidateViews = toolbar.items.compactMap { $0.view }
        guard let referenceView = candidateViews.first else { return nil }
        let frame = toolbarView.convert(referenceView.bounds, from: referenceView)
        return frame.midY
    }

    private func frame(of item: NSToolbarItem, in container: NSView) -> CGRect? {
        guard let view = item.view else { return nil }
        return container.convert(view.bounds, from: view)
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
        let leading: CGFloat
        let trailing: CGFloat
        let height: CGFloat
        let centerOffset: CGFloat
        let isHidden: Bool

        func isApproximatelyEqual(to other: LayoutState, tolerance: CGFloat = 0.5) -> Bool {
            guard isHidden == other.isHidden else { return false }
            return abs(leading - other.leading) <= tolerance &&
                abs(trailing - other.trailing) <= tolerance &&
                abs(height - other.height) <= tolerance &&
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
}

#endif
