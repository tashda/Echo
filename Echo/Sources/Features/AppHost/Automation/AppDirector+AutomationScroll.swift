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
        // `sheet` and `front` scroll the biggest scroll view of the open sheet or the front window.
        let frontRoot = (target == "sheet" || target == "front") ? automationWindow(nil)?.contentView : nil
        let target = (windowID == AppWindowIdentifier.workspace && frontRoot == nil) ? target : "content"
        guard let root = frontRoot ?? NSApp.windows.first(where: { $0.identifier == windowID })?.contentView,
              let scrollView = automationScrollView(target, in: root) else {
            print("automation-scroll no scroll view for '\(target)'"); fflush(stdout); return
        }
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

    /// Resizes the workspace window frame by frame, as dragging its edge does: the right edge moves
    /// `distance` points over `seconds` (negative shrinks it).
    ///
    ///     { "action": "resize", "distance": -400, "seconds": 1.5 }
    func performAutomationResize(distance: CGFloat, seconds: Double) async {
        guard let window = NSApp.windows.first(where: { $0.identifier == AppWindowIdentifier.workspace }) else { return }
        let start = window.frame
        let frames = max(Int(seconds * 60), 1)
        // As a person's drag does (WorkspaceWindowConfigurator): the window is held still while it resizes.
        if ProcessInfo.processInfo.environment["ECHO_RESIZE_UNHELD"] == nil { WindowDragPause.holdStill(window) }
        defer { WindowDragPause.release(window) }
        for step in 1...frames {
            var frame = start
            frame.size.width = max(start.width + distance * CGFloat(step) / CGFloat(frames), window.minSize.width)
            window.setFrame(frame, display: true)
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
