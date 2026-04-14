#if os(macOS)
import AppKit
import SwiftUI

extension QueryResultsTableView.Coordinator {

    // MARK: - Autoscroll

    /// Called from mouseDragged to evaluate whether autoscroll should start, update, or stop.
    func updateAutoscroll(for event: NSEvent, tableView: NSTableView) {
        guard event.type == .leftMouseDragged, NSEvent.pressedMouseButtons != 0 else {
            stopAutoscroll()
            return
        }
        guard let scrollView = tableView.enclosingScrollView else {
            stopAutoscroll()
            return
        }

        let velocity = computeAutoscrollVelocity(in: tableView)

        if velocity == .zero {
            stopAutoscroll()
        } else {
            autoscrollVelocity = velocity
            startAutoscroll(for: tableView, scrollView: scrollView)
        }
    }

    /// Compute the desired autoscroll velocity based on the current mouse position
    /// relative to the table's visible rect. Works even when called from the timer
    /// (no dependency on NSEvent).
    func computeAutoscrollVelocity(in tableView: NSTableView) -> CGPoint {
        let location = currentMouseLocationInTableView(tableView)
        let visibleRect = tableView.visibleRect
        let padding = autoscrollPadding

        var velocity = CGPoint.zero

        if location.y < visibleRect.minY + padding {
            let distance = max((visibleRect.minY + padding) - location.y, 0)
            velocity.y = -autoscrollSpeed(for: distance, padding: padding)
        } else if location.y > visibleRect.maxY - padding {
            let distance = max(location.y - (visibleRect.maxY - padding), 0)
            velocity.y = autoscrollSpeed(for: distance, padding: padding)
        }

        if location.x < visibleRect.minX + padding {
            let distance = max((visibleRect.minX + padding) - location.x, 0)
            velocity.x = -autoscrollSpeed(for: distance, padding: padding)
        } else if location.x > visibleRect.maxX - padding {
            let distance = max(location.x - (visibleRect.maxX - padding), 0)
            velocity.x = autoscrollSpeed(for: distance, padding: padding)
        }

        return velocity
    }

    /// Returns the current mouse position in the table view's coordinate system,
    /// queried directly from NSEvent (works even without mouseDragged delivery).
    func currentMouseLocationInTableView(_ tableView: NSTableView) -> NSPoint {
        guard let window = tableView.window else { return .zero }
        let screenLocation = NSEvent.mouseLocation
        // Convert from screen to window coordinates.
        let windowRect = window.convertFromScreen(NSRect(origin: screenLocation, size: .zero))
        let windowLocation = windowRect.origin
        // Convert from window to table view coordinates.
        return tableView.convert(windowLocation, from: nil)
    }

    func autoscrollSpeed(for distance: CGFloat, padding: CGFloat) -> CGFloat {
        guard padding > 0 else { return 0 }
        // Beyond the padding zone, accelerate proportionally to distance from the edge.
        let ratio = min(max(distance / (padding * 4), 0), 1)
        let adjusted = pow(ratio, 1.2)
        return adjusted * autoscrollMaxSpeed
    }

    func startAutoscroll(for tableView: NSTableView, scrollView: NSScrollView) {
        // Already running — keep the existing timer.
        if autoscrollTimer != nil { return }

        let interval = defaultAutoscrollInterval

        let timer = Timer(timeInterval: interval, repeats: true) { [weak self, weak tableView] _ in
            Task { @MainActor [weak self, weak tableView] in
                guard let self, let tableView else {
                    self?.stopAutoscroll()
                    return
                }
                self.performAutoscrollStep(in: tableView)
            }
        }
        autoscrollTimer = timer
        autoscrollTimerInterval = interval
        RunLoop.main.add(timer, forMode: .common)
    }

    func stopAutoscroll() {
        autoscrollTimer?.invalidate()
        autoscrollTimer = nil
        autoscrollVelocity = .zero
        autoscrollTimerInterval = defaultAutoscrollInterval
    }

    func performAutoscrollStep(in tableView: NSTableView) {
        guard isDraggingSelection,
              NSEvent.pressedMouseButtons != 0,
              let scrollView = tableView.enclosingScrollView else {
            stopAutoscroll()
            return
        }

        // Recompute velocity from the live mouse position on every tick.
        let velocity = computeAutoscrollVelocity(in: tableView)
        autoscrollVelocity = velocity

        if velocity == .zero {
            // Mouse is back inside the table — stop scrolling and update selection.
            stopAutoscroll()
            processAutoscrollSelection(in: tableView)
            return
        }

        let currentOrigin = scrollView.contentView.bounds.origin
        var origin = currentOrigin
        let documentSize = tableView.bounds.size
        let clipSize = scrollView.contentView.bounds.size

        let maxOriginX = max(documentSize.width - clipSize.width, 0)
        let maxOriginY = max(documentSize.height - clipSize.height, 0)

        let dx = velocity.x * CGFloat(autoscrollTimerInterval)
        let dy = velocity.y * CGFloat(autoscrollTimerInterval)

        origin.x = min(max(origin.x + dx, 0), maxOriginX)
        origin.y = min(max(origin.y + dy, 0), maxOriginY)

        let movedX = abs(origin.x - currentOrigin.x)
        let movedY = abs(origin.y - currentOrigin.y)
        let didScroll = movedX > 0.1 || movedY > 0.1

        guard didScroll else {
            // Hit the scroll boundary — update selection at the edge.
            processAutoscrollSelection(in: tableView)
            return
        }

        scrollView.contentView.scroll(to: origin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
        processAutoscrollSelection(in: tableView)
    }

    func processAutoscrollSelection(in tableView: NSTableView) {
        guard isDraggingSelection, let anchor = selectionAnchor else { return }
        let point = currentMouseLocationInTableView(tableView)
        if isDraggingRowSelection {
            guard let row = resolvedRowForDragSelection(at: point, in: tableView) else { return }
            extendRowSelection(to: row)
            return
        }
        guard let cell = resolvedCell(at: point, in: tableView, allowOutOfBounds: true) else { return }
        let region = SelectedRegion(start: anchor, end: cell)
        if selectionRegion != region {
            setSelectionRegion(region, tableView: tableView)
        }
    }
}
#endif
