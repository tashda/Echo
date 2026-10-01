#if os(macOS)
import AppKit

/// On macOS 26 the results table's scroll view puts a "pocket" behind the pinned header and a
/// banner decoration in it, each with its own 1pt line at the bottom: the line the owner saw 4pt
/// above the gutter's (round 47). Echo draws the one line under the header itself, level with the
/// row-number column's, so the system's are hidden. The views are the system's and found by
/// name, as `PocketSeparatorHider` does for the window's pocket.
@MainActor
enum SystemHeaderLineHider {
    private static let containers = ["NSScrollPocket", "NSBannerView"]
    private static let lineViewName = "_NSLayerBasedFillColorView"

    /// Hides every 1pt line in the scroll view's pockets and banners.
    static func hideLines(in scrollView: NSScrollView) {
        for subview in scrollView.subviews { hide(in: subview, insideContainer: false) }
        hide(in: scrollView.contentView, insideContainer: false)
    }

    private static func hide(in view: NSView, insideContainer: Bool) {
        let name = String(describing: type(of: view))
        let inside = insideContainer || containers.contains(name)
        if inside, name == lineViewName, view.frame.height <= 1.5, !view.isHidden {
            view.isHidden = true
        }
        for subview in view.subviews { hide(in: subview, insideContainer: inside) }
    }
}
#endif
