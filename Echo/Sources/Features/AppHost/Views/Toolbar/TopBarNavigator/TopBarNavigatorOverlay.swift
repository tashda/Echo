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
    weak var hostingView: TopBarNavigatorHostingView?
    weak var toolbarView: NSView?
    /// The parent of NSToolbarView — we place the hosting view here
    /// so it lives OUTSIDE NSToolbar's subview hierarchy and cannot
    /// interfere with toolbar item layout.
    weak var containerView: NSView?
    weak var window: NSWindow?
    weak var environmentState: EnvironmentState?
    weak var appState: AppState?
    weak var navigationStore: NavigationStore?

    var observers: [NSObjectProtocol] = []
    var itemObservers: [NSObjectProtocol] = []
    var observedItemIdentifiers: [NSToolbarItem.Identifier] = []
    var observedViewIDs: Set<ObjectIdentifier> = []
    var pendingLayoutUpdate = false
    var stateCancellables: Set<AnyCancellable> = []
    let layoutState = TopBarNavigatorLayoutState()
    /// Set after the first successful layout positions the hosting view.
    var hasCompletedInitialLayout = false
    /// Timestamp of the last state change that could trigger transient toolbar re-layout.
    var lastStateChangeTime: CFTimeInterval = 0
    /// Transparent proxy inside NSToolbarView that routes hitTest
    /// to the hosting view, enabling normal event dispatch.
    var hitProxyView: TopBarNavigatorHitProxy?

    let primaryPrefix = "workspace.primary"
    let leadingPadding: CGFloat = 18
    let trailingPadding: CGFloat = 12
    /// Tiny upward nudge to visually align with circular toolbar buttons.
    let verticalInset: CGFloat = -0.5
    let hostingViewIdentifier = NSUserInterfaceItemIdentifier("TopBarNavigatorHostingView")
}
#endif
