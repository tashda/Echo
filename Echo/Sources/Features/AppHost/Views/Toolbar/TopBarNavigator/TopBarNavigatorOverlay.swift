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
    weak var window: NSWindow?
    weak var environmentState: EnvironmentState?
    weak var appState: AppState?
    weak var navigationStore: NavigationStore?

    var leadingConstraint: NSLayoutConstraint?
    var trailingConstraint: NSLayoutConstraint?
    var centerYConstraint: NSLayoutConstraint?
    var heightConstraint: NSLayoutConstraint?

    var observers: [NSObjectProtocol] = []
    var itemObservers: [NSObjectProtocol] = []
    var observedItemIdentifiers: [NSToolbarItem.Identifier] = []
    var observedViewIDs: Set<ObjectIdentifier> = []
    var pendingLayoutUpdate = false
    var lastLayoutState: LayoutState?
    var stateCancellables: Set<AnyCancellable> = []
    let layoutState = TopBarNavigatorLayoutState()

    let navigationPrefix = "workspace.navigation"
    let primaryPrefix = "workspace.primary"
    let leadingPadding: CGFloat = 18
    let trailingPadding: CGFloat = 12
    // Tiny upward nudge to visually align with circular toolbar buttons.
    let verticalInset: CGFloat = -0.5
    // Fraction of the inspector width we project into the toolbar layout.
    // Using the full width makes the center region collapse too far when
    // the inspector is visible; Xcode keeps the pill only slightly
    // narrower, so we intentionally use a partial influence.
    let inspectorInfluence: CGFloat = 0.55
    // Sidebar influence mirrors inspector behavior for Xcode-like centering.
    let sidebarInfluence: CGFloat = 0.55
    let minimumAvailableWidth: CGFloat = 420
    let hostingViewIdentifier = NSUserInterfaceItemIdentifier("TopBarNavigatorHostingView")

    struct LayoutState: Equatable {
        let height: CGFloat
        let centerOffset: CGFloat

        func isApproximatelyEqual(to other: LayoutState, tolerance: CGFloat = 0.5) -> Bool {
            return abs(height - other.height) <= tolerance &&
                abs(centerOffset - other.centerOffset) <= tolerance
        }
    }
}
#endif
