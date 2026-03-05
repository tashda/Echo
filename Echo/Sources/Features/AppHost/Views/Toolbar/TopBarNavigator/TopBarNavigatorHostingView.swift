import SwiftUI

#if os(macOS)
import AppKit

/// Transparent view placed inside NSToolbarView so that
/// NSTitlebarContainerView's hitTest chain can find a hittable view
/// in the breadcrumb region. The proxy returns **itself** from hitTest
/// (staying within the toolbar hierarchy to avoid cursor-tracking
/// recursion) and forwards mouse events to the hosting view, which
/// lets NSWindow.sendEvent deliver them through the normal dispatch.
final class TopBarNavigatorHitProxy: NSView {
    weak var hostingView: TopBarNavigatorHostingView?

    override func draw(_ dirtyRect: NSRect) {}
    override var isOpaque: Bool { false }
    override var wantsDefaultClipping: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let hostingView, let superview = self.superview else { return nil }
        // Check if the hosting view has interactive content at this point.
        let windowPoint = superview.convert(point, to: nil)
        let containerPoint = hostingView.superview?.convert(windowPoint, from: nil) ?? windowPoint
        guard hostingView.hitTest(containerPoint) != nil else { return nil }
        // Return self — NOT the hosting view's subview — to stay within
        // NSToolbarView's hierarchy and avoid cursor-tracking recursion.
        return self
    }

    // Forward mouse events to the hosting view so SwiftUI gesture
    // recognizers fire through the normal sendEvent chain.
    override func mouseDown(with event: NSEvent) {
        hostingView?.mouseDown(with: event)
    }
    override func mouseDragged(with event: NSEvent) {
        hostingView?.mouseDragged(with: event)
    }
    override func mouseUp(with event: NSEvent) {
        hostingView?.mouseUp(with: event)
    }
    override func rightMouseDown(with event: NSEvent) {
        hostingView?.rightMouseDown(with: event)
    }
    override func rightMouseUp(with event: NSEvent) {
        hostingView?.rightMouseUp(with: event)
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }
    override func invalidateIntrinsicContentSize() {}
    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class TopBarNavigatorHostingView: NSHostingView<AnyView> {
    required init(rootView: AnyView) {
        super.init(rootView: rootView)
        translatesAutoresizingMaskIntoConstraints = true
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.masksToBounds = false
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // point is in superview coordinates — convert to local for bounds check.
        let localPoint = convert(point, from: superview)
        guard bounds.contains(localPoint) else { return nil }
        // Delegate to super which routes through NSHostingView's SwiftUI
        // layer. It may return self (meaning SwiftUI content is present and
        // the hosting view handles event routing internally) or a specific
        // subview. Return nil only when super returns nil (no content at all).
        guard let hit = super.hitTest(point) else { return nil }
        return hit
    }

    // Prevent the hosting view from influencing NSToolbar's internal
    // layout engine. Without these overrides, NSHostingView reports an
    // intrinsic size based on its SwiftUI content and invalidates its
    // superview's layout when content changes — causing NSToolbar to
    // shift its items.
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }

    override func invalidateIntrinsicContentSize() {
        // No-op: our size is managed entirely by frame-based positioning
        // in TopBarNavigatorOverlay.updateLayout(). Do not propagate to
        // NSToolbarView.
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override var mouseDownCanMoveWindow: Bool {
        false
    }
}
#endif
