import SwiftUI
import Combine

#if os(macOS)
import AppKit

extension TopBarNavigatorOverlay {
    func registerObservers(window: NSWindow, toolbarView: NSView) {
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
            .sink { [weak self] _ in self?.scheduleLayoutUpdate() }
            .store(in: &stateCancellables)

        // Observe inspectorWidth via withObservationTracking or a bridge if needed
        // For simplicity, we trigger a manual update when it changes if possible.
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

    func removeItemObservers() {
        let center = NotificationCenter.default
        itemObservers.forEach { center.removeObserver($0) }
        itemObservers.removeAll()
        observedItemIdentifiers = []
        observedViewIDs = []
    }
}
#endif
