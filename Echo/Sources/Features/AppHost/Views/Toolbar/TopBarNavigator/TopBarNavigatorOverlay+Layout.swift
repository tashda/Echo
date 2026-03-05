import SwiftUI

#if os(macOS)
import AppKit

extension TopBarNavigatorOverlay {
    /// Coalesces multiple layout requests into a single synchronous call
    /// at the end of the current run-loop cycle. Using
    /// `CFRunLoopPerformBlock` on `.commonModes` ensures the update runs
    /// within the same display frame as a live resize, avoiding lag.
    func scheduleLayoutUpdate() {
        guard !pendingLayoutUpdate else { return }
        pendingLayoutUpdate = true
        CFRunLoopPerformBlock(CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue) { [weak self] in
            guard let self else { return }
            self.pendingLayoutUpdate = false
            self.updateLayout()
        }
    }

    func updateLayout() {
        guard let toolbarView, let containerView, let _ = hostingView,
              let window, let toolbar = window.toolbar else { return }
        updateToolbarItemObservers(toolbar: toolbar, toolbarView: toolbarView)

        let bounds = toolbarView.bounds

        // Collect frames for ALL left-side items (including system sidebar
        // toggle) and our primary-action items on the right.
        let primaryIDs = Set(
            toolbar.items
                .filter { $0.itemIdentifier.rawValue.hasPrefix(primaryPrefix) }
                .map(\.itemIdentifier)
        )

        let leftFrames = toolbar.items
            .filter { !primaryIDs.contains($0.itemIdentifier) }
            .compactMap { frame(for: $0, in: toolbarView) }

        let rightFrames = toolbar.items
            .filter { primaryIDs.contains($0.itemIdentifier) }
            .compactMap { frame(for: $0, in: toolbarView) }

        let navigationMaxX = leftFrames.map(\.maxX).max() ?? 0
        let primaryMinX = rightFrames.map(\.minX).min() ?? bounds.width

        let leftEdge = max(leadingPadding, navigationMaxX + leadingPadding)
        var rightEdge = min(bounds.width - trailingPadding, primaryMinX - trailingPadding)

        // Prevent the pill from extending over the inspector area.
        if let appState, appState.showInfoSidebar {
            let contentWidth = window.contentLayoutRect.width
            let scale: CGFloat = contentWidth > 0 ? bounds.width / contentWidth : 1
            let inspWidth = navigationStore?.inspectorWidth
                ?? WorkspaceLayoutMetrics.inspectorMinWidth
            let inspectorLeft = bounds.width - inspWidth * scale
            rightEdge = min(rightEdge, inspectorLeft - trailingPadding)
        }

        // Safety: ensure the region is never negative / inverted.
        rightEdge = max(rightEdge, leftEdge + 200)

        let regionWidth = rightEdge - leftEdge

        // Guard against transient toolbar states (e.g. during SwiftUI
        // state transitions that temporarily remove / reposition items).
        // If the region shrank below a sane minimum, keep the previous
        // frame instead of jumping.
        if regionWidth < 300, let hv = hostingView, hv.frame.width > 100 {
            return
        }

        layoutState.update(availableWidth: regionWidth, centerX: 0, toolbarWidth: bounds.width)

        let desiredHeight: CGFloat
        let centerOffset: CGFloat
        if let metrics = referenceMetrics(in: toolbarView, toolbar: toolbar) {
            desiredHeight = metrics.height
            centerOffset = metrics.midY - bounds.midY + verticalInset
        } else {
            desiredHeight = WorkspaceChromeMetrics.toolbarTabBarHeight
            centerOffset = verticalInset
        }

        // Compute frame in toolbar-view coordinates. The hosting view is
        // now a direct child of toolbarView, so no coordinate conversion needed.
        let yInToolbar = (bounds.height - desiredHeight) / 2 + centerOffset
        let toolbarRect = NSRect(x: leftEdge, y: yInToolbar,
                                 width: rightEdge - leftEdge, height: desiredHeight)
        let newFrame = toolbarRect

        guard let hostingView else { return }
        // During a brief cooldown after a state change that triggers toolbar
        // button re-evaluation, skip layout updates to avoid picking up
        // transient item positions. The deferred update will run after settling.
        if hasCompletedInitialLayout {
            let elapsed = CACurrentMediaTime() - lastStateChangeTime
            if elapsed < 0.18 {
                return
            }
        } else {
            hasCompletedInitialLayout = true
        }
        if !hostingView.frame.equalTo(newFrame) {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0
                context.allowsImplicitAnimation = false
                hostingView.frame = newFrame
            }
        }
        // No hit proxy to sync — hosting view is in toolbarView directly.
    }

    func referenceMetrics(in toolbarView: NSView, toolbar: NSToolbar) -> (height: CGFloat, midY: CGFloat)? {
        let candidateViews = toolbar.items.compactMap { $0.view }
        guard let referenceView = candidateViews.max(by: { $0.bounds.height < $1.bounds.height }) else {
            return nil
        }
        let frame = toolbarView.convert(referenceView.bounds, from: referenceView)
        return (frame.height, frame.midY)
    }

    /// Returns the toolbar item's view frame in toolbar-view coordinates,
    /// or nil when the item has no backing view (flexible spaces, etc.).
    /// Only the item's own view is used — the superview container can have
    /// a misleading frame during SwiftUI toolbar transitions.
    func frame(for item: NSToolbarItem, in container: NSView) -> CGRect? {
        guard let view = item.view else { return nil }
        let rect = container.convert(view.bounds, from: view)
        // Ignore zero-width items (transient state during re-evaluation).
        guard rect.width > 1 else { return nil }
        return rect
    }

}
#endif
