#if DEBUG
import AppKit

/// A scripted scroll, frame by frame through the scroll view's clip view as a trackpad would,
/// so scrolling can be traced without synthetic events (which land in whatever window is on top).
///
///     { "action": "scroll", "target": "sidebar", "distance": 1200, "seconds": 1.5 }
///
/// `target` is `sidebar` (the leftmost big scroll view, past the rail: the Explorer tree), `grid` (the
/// largest table: a query tab's results; `gridx` scrolls it sideways) or `content` (the largest
/// scroll view of any kind).
extension AppDirector {
    func performAutomationScroll(target: String, distance: CGFloat, seconds: Double) async {
        // `settings` and `manage` scroll the biggest scroll view of that window.
        let windowID: NSUserInterfaceItemIdentifier = switch target {
        case "settings": AppWindowIdentifier.settings
        case "manage": AppWindowIdentifier.manageConnections
        default: AppWindowIdentifier.workspace
        }
        let target = windowID == AppWindowIdentifier.workspace ? target : "content"
        guard let root = NSApp.windows.first(where: { $0.identifier == windowID })?.contentView,
              let scrollView = automationScrollView(target, in: root) else { return }
        let frames = max(Int(seconds * 60), 1)
        for _ in 0..<frames {
            let clip = scrollView.contentView
            var origin = clip.bounds.origin
            if target == "gridx" {
                // A real scroll-wheel event, sent to the scroll view itself, so AppKit also moves
                // the column header as a trackpad would.
                let step = Int32(-distance / CGFloat(frames))
                if let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: 0, wheel2: step, wheel3: 0),
                   let wheel = NSEvent(cgEvent: event) {
                    scrollView.scrollWheel(with: wheel)
                }
                try? await Task.sleep(for: .milliseconds(16))
                continue
            }
            // Within the document, as a trackpad settles: past either end the clip view would be
            // left overscrolled, which no person can hold.
            let maxY = max((scrollView.documentView?.frame.height ?? 0) - clip.bounds.height, 0)
            origin.y = min(max(origin.y + distance / CGFloat(frames), 0), maxY)
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
        case "grid", "gridx":
            return placed.filter { $0.0.documentView is NSTableView }
                .max { $0.1.width * $0.1.height < $1.1.width * $1.1.height }?.0
        default:
            return placed.max { $0.1.width * $0.1.height < $1.1.width * $1.1.height }?.0
        }
    }
}
#endif
