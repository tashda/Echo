import SwiftUI
import Combine

#if os(macOS)
import AppKit

extension TopBarNavigatorOverlay {
    func registerObservers(window: NSWindow, toolbarView: NSView) {
        removeObservers()
        let center = NotificationCenter.default

        // Frame / resize notifications call updateLayout() directly
        // so the pill tracks the window edge without any async delay.
        observers.append(
            center.addObserver(
                forName: NSView.frameDidChangeNotification,
                object: toolbarView,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateLayout() }
            }
        )

        observers.append(
            center.addObserver(
                forName: NSWindow.didResizeNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateLayout() }
            }
        )

        observers.append(
            center.addObserver(
                forName: NSWindow.didEndLiveResizeNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateLayout() }
            }
        )
    }

    func removeObservers() {
        let center = NotificationCenter.default
        observers.forEach { center.removeObserver($0) }
        observers.removeAll()
    }

    func configureStateObservers(appState: AppState, navigationStore: NavigationStore) {
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
            .sink { [weak self] _ in
                self?.lastStateChangeTime = CACurrentMediaTime()
                self?.scheduleDeferredLayoutUpdate()
            }
            .store(in: &stateCancellables)

        // Observe state changes that cause toolbar buttons to re-evaluate,
        // which triggers a transient NSToolbar re-layout. Mark the time
        // so updateLayout() can skip the transient frame and defer.
        appState.$showTabOverview
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.lastStateChangeTime = CACurrentMediaTime()
                self?.scheduleDeferredLayoutUpdate()
            }
            .store(in: &stateCancellables)
    }

    /// Schedules a layout update after a brief delay to let toolbar transitions settle.
    func scheduleDeferredLayoutUpdate() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.updateLayout()
        }
    }

    func updateToolbarItemObservers(toolbar: NSToolbar, toolbarView: NSView) {
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
            view.postsFrameChangedNotifications = true
            itemObservers.append(
                center.addObserver(
                    forName: NSView.frameDidChangeNotification,
                    object: view,
                    queue: .main
                ) { [weak self] _ in
                    MainActor.assumeIsolated { self?.scheduleLayoutUpdate() }
                }
            )
        }
    }

    func removeItemObservers() {
        let center = NotificationCenter.default
        itemObservers.forEach { center.removeObserver($0) }
        itemObservers.removeAll()
        observedItemIdentifiers = []
        observedViewIDs = []
    }
}
#endif
