import SwiftUI

#if os(macOS)
import AppKit

final class WorkspaceToolbarTabBarOverlay {
    private weak var hostingView: ToolbarTabBarHostingView?
    private weak var toolbarView: NSView?
    private weak var window: NSWindow?

    private var leadingConstraint: NSLayoutConstraint?
    private var trailingConstraint: NSLayoutConstraint?
    private var centerYConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?

    private var observers: [NSObjectProtocol] = []
    private var pendingLayoutUpdate = false

    private let navigationPrefix = "workspace.navigation"
    private let primaryPrefix = "workspace.primary"
    private let leadingPadding: CGFloat = 14
    private let trailingPadding: CGFloat = 12

    func apply(
        style: WorkspaceTabBarStyle,
        window: NSWindow,
        appModel: AppModel,
        appState: AppState,
        themeManager: ThemeManager
    ) {
        switch style {
        case .toolbarCompact:
            installIfNeeded(
                window: window,
                style: style,
                appModel: appModel,
                appState: appState,
                themeManager: themeManager
            )
            scheduleLayoutUpdate()
        case .floating:
            detach()
        }
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
    }

    private func installIfNeeded(
        window: NSWindow,
        style: WorkspaceTabBarStyle,
        appModel: AppModel,
        appState: AppState,
        themeManager: ThemeManager
    ) {
        if let hostingView {
            hostingView.rootView = makeRootView(
                style: style,
                appModel: appModel,
                appState: appState,
                themeManager: themeManager
            )
            toolbarView?.layoutSubtreeIfNeeded()
            scheduleLayoutUpdate()
            return
        }

        guard let toolbarView = WorkspaceToolbarTabBarOverlay.findToolbarView(in: window) else {
            return
        }

        toolbarView.postsFrameChangedNotifications = true

        let hostingView = ToolbarTabBarHostingView(
            rootView: makeRootView(
                style: style,
                appModel: appModel,
                appState: appState,
                themeManager: themeManager
            )
        )

        toolbarView.addSubview(hostingView)

        let leading = hostingView.leadingAnchor.constraint(equalTo: toolbarView.leadingAnchor)
        let trailing = hostingView.trailingAnchor.constraint(equalTo: toolbarView.trailingAnchor)
        let centerY = hostingView.centerYAnchor.constraint(equalTo: toolbarView.centerYAnchor)
        let height = hostingView.heightAnchor.constraint(
            equalToConstant: WorkspaceChromeMetrics.toolbarTabBarHeight
        )

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
        style: WorkspaceTabBarStyle,
        appModel: AppModel,
        appState: AppState,
        themeManager: ThemeManager
    ) -> AnyView {
        AnyView(
            WorkspaceToolbarTabBar(maxVisibleTabs: style.maxVisibleToolbarTabs)
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
                self?.scheduleLayoutUpdate()
            }
        )

        observers.append(
            center.addObserver(
                forName: NSWindow.didResizeNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.scheduleLayoutUpdate()
            }
        )

        observers.append(
            center.addObserver(
                forName: NSWindow.didEndLiveResizeNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.scheduleLayoutUpdate()
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
        guard
            let toolbarView,
            let hostingView,
            let window,
            let toolbar = window.toolbar
        else { return }

        toolbarView.layoutSubtreeIfNeeded()

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

        leadingConstraint?.constant = leadingInset
        trailingConstraint?.constant = -trailingInset

        if let referenceHeight = referenceHeight(in: toolbarView, toolbar: toolbar) {
            heightConstraint?.constant = referenceHeight
            let offset = (referenceMidY(in: toolbarView, toolbar: toolbar) ?? (bounds.midY)) - bounds.midY
            centerYConstraint?.constant = offset
        } else {
            heightConstraint?.constant = WorkspaceChromeMetrics.toolbarTabBarHeight
            centerYConstraint?.constant = 0
        }

        hostingView.isHidden = availableWidth < 64
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

    private static func findToolbarView(in window: NSWindow) -> NSView? {
        guard let titlebarContainer = window.contentView?.superview else { return nil }
        var views: [NSView] = [titlebarContainer]

        while let view = views.popLast() {
            if String(describing: type(of: view)).contains("NSToolbarView") {
                return view
            }
            views.append(contentsOf: view.subviews)
        }

        return nil
    }
}

private final class ToolbarTabBarHostingView: NSHostingView<AnyView> {
    required init(rootView: AnyView) {
        super.init(rootView: rootView)
        translatesAutoresizingMaskIntoConstraints = false
        configureAppearance()
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        configureAppearance()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureAppearance()
    }

    private func configureAppearance() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.masksToBounds = false
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let location = convert(event.locationInWindow, from: nil)
        if bounds.contains(location) {
            return super.menu(for: event)
        }
        return nil
    }
}
#endif
