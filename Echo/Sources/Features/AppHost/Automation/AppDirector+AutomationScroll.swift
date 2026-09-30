#if DEBUG
import AppKit

/// A scripted scroll, frame by frame through the scroll view's clip view as a trackpad would,
/// so scrolling can be traced without synthetic events (which land in whatever window is on top).
///
///     { "action": "scroll", "target": "sidebar", "distance": 1200, "seconds": 1.5 }
///
/// `target` is `sidebar` (the leftmost big scroll view, past the rail: the Explorer tree) or `content` (the
/// largest one: the active tab's grid or list).
extension AppDirector {
    func performAutomationScroll(target: String, distance: CGFloat, seconds: Double) async {
        guard let root = NSApp.windows.first(where: { $0.identifier == AppWindowIdentifier.workspace })?.contentView,
              let scrollView = automationScrollView(target, in: root) else { return }
        let frames = max(Int(seconds * 60), 1)
        for _ in 0..<frames {
            let clip = scrollView.contentView
            var origin = clip.bounds.origin
            origin.y += distance / CGFloat(frames)
            clip.scroll(to: origin)
            scrollView.reflectScrolledClipView(clip)
            try? await Task.sleep(for: .milliseconds(16))
        }
    }

    private func automationScrollView(_ target: String, in root: NSView) -> NSScrollView? {
        var found: [NSScrollView] = []
        func collect(_ view: NSView) {
            if let scrollView = view as? NSScrollView, !scrollView.isHiddenOrHasHiddenAncestor,
               scrollView.frame.height > 200, scrollView.frame.width > 150 {
                found.append(scrollView)
            }
            view.subviews.forEach(collect)
        }
        collect(root)
        let placed = found.map { ($0, $0.convert($0.bounds, to: nil)) }
        switch target {
        case "sidebar":
            return placed.min { $0.1.minX < $1.1.minX }?.0
        default:
            return placed.max { $0.1.width * $0.1.height < $1.1.width * $1.1.height }?.0
        }
    }
}
#endif
