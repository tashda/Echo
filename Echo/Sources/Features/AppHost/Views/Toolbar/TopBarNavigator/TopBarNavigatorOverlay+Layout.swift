import SwiftUI

#if os(macOS)
import AppKit

extension TopBarNavigatorOverlay {
    func scheduleLayoutUpdate() {
        guard !pendingLayoutUpdate else { return }
        pendingLayoutUpdate = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.pendingLayoutUpdate = false
            self.updateLayout()
        }
    }

    func updateLayout() {
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

        self.lastLayoutState = layoutState
    }

    func referenceMetrics(in toolbarView: NSView, toolbar: NSToolbar) -> (height: CGFloat, midY: CGFloat)? {
        let candidateViews = toolbar.items.compactMap { $0.view }
        guard let referenceView = candidateViews.max(by: { $0.bounds.height < $1.bounds.height }) else {
            return nil
        }
        let frame = toolbarView.convert(referenceView.bounds, from: referenceView)
        return (frame.height, frame.midY)
    }

    func frames(for item: NSToolbarItem, in container: NSView) -> [CGRect] {
        guard let view = item.view else { return [] }
        var frames: [CGRect] = [container.convert(view.bounds, from: view)]
        if let superview = view.superview {
            frames.append(container.convert(superview.bounds, from: superview))
        }
        return frames
    }

    func apply(constraint: NSLayoutConstraint?, constant: CGFloat) {
        guard let constraint else { return }
        if abs(constraint.constant - constant) > 0.25 {
            constraint.constant = constant
        }
    }
}
#endif
