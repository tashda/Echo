import SwiftUI
import AppKit

/// A transparent view that, once installed in the view hierarchy, traverses
/// its host window's content view and hides the 1px `_NSLayerBasedFillColorView`
/// separator that `NavigationSplitView` inserts inside `NSHardPocketView`
/// between the toolbar and detail content.
///
/// Usage: place `.background(PocketSeparatorHider())` on the root of a
/// `NavigationSplitView` inside a `WindowGroup`.
struct PocketSeparatorHider: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = PocketSeparatorHiderView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class PocketSeparatorHiderView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        hideSeparators()
    }

    override func layout() {
        super.layout()
        hideSeparators()
    }

    private func hideSeparators() {
        guard let root = window?.contentView else { return }
        hidePocketSeparators(in: root)
    }

    private func hidePocketSeparators(in root: NSView) {
        for subview in root.subviews {
            let typeName = String(describing: type(of: subview))
            if typeName.contains("NSLayerBasedFillColorView"),
               subview.frame.height <= 1 {
                subview.isHidden = true
            }
            hidePocketSeparators(in: subview)
        }
    }
}
