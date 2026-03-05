#if os(macOS)
import AppKit
import SwiftUI

extension QueryResultsTableView.Coordinator {

    // MARK: - Autoscroll

    func updateAutoscroll(for event: NSEvent, tableView: NSTableView) {
        guard event.type == .leftMouseDragged, NSEvent.pressedMouseButtons != 0 else {
            stopAutoscroll()
            return
        }
        lastDragLocationInWindow = event.locationInWindow
        guard let scrollView = tableView.enclosingScrollView else {
            stopAutoscroll()
            return
        }

        let visibleRect = tableView.visibleRect
        let location = tableView.convert(event.locationInWindow, from: nil)

        var velocity = CGPoint.zero
        let padding = autoscrollPadding

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

        autoscrollVelocity = velocity

        if velocity == .zero {
            stopAutoscroll()
        } else {
            let interval = preferredAutoscrollInterval(for: velocity)
            startAutoscroll(for: tableView, scrollView: scrollView, interval: interval)
        }
    }

    func autoscrollSpeed(for distance: CGFloat, padding: CGFloat) -> CGFloat {
        guard padding > 0 else { return 0 }
        let ratio = min(max(distance / padding, 0), 1)
        let adjusted = pow(ratio, 1.2)
        return adjusted * autoscrollMaxSpeed
    }

    func preferredAutoscrollInterval(for velocity: CGPoint) -> TimeInterval {
        let speed = max(abs(velocity.x), abs(velocity.y))
        if speed <= 0 {
            return defaultAutoscrollInterval * 2.5
        }
        let clamped = min(max(speed / autoscrollMaxSpeed, 0), 1)
        let scale = 1 + (1 - clamped) * 1.5
        return defaultAutoscrollInterval * scale
    }

    func startAutoscroll(for tableView: NSTableView, scrollView: NSScrollView, interval: TimeInterval) {
        if let timer = autoscrollTimer {
            if abs(timer.timeInterval - interval) <= 0.0005 {
                return
            }
            timer.invalidate()
            autoscrollTimer = nil
        }

        autoscrollTimerInterval = interval

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
        RunLoop.main.add(timer, forMode: .common)
    }

    func stopAutoscroll() {
        autoscrollTimer?.invalidate()
        autoscrollTimer = nil
        autoscrollVelocity = .zero
        autoscrollTimerInterval = defaultAutoscrollInterval
    }

    func performAutoscrollStep(in tableView: NSTableView) {
        guard autoscrollVelocity != .zero,
              isDraggingCellSelection,
              NSEvent.pressedMouseButtons != 0,
              tableView.window?.isKeyWindow ?? false,
              let scrollView = tableView.enclosingScrollView else {
            stopAutoscroll()
            return
        }

        let currentOrigin = scrollView.contentView.bounds.origin
        var origin = currentOrigin
        let documentSize = tableView.bounds.size
        let clipSize = scrollView.contentView.bounds.size

        let maxOriginX = max(documentSize.width - clipSize.width, 0)
        let maxOriginY = max(documentSize.height - clipSize.height, 0)

        let dx = autoscrollVelocity.x * CGFloat(autoscrollTimerInterval)
        let dy = autoscrollVelocity.y * CGFloat(autoscrollTimerInterval)

        origin.x = min(max(origin.x + dx, 0), maxOriginX)
        origin.y = min(max(origin.y + dy, 0), maxOriginY)

        let movedX = abs(origin.x - currentOrigin.x)
        let movedY = abs(origin.y - currentOrigin.y)
        let didScroll = movedX > 0.1 || movedY > 0.1

        if origin.x <= 0 || origin.x >= maxOriginX { autoscrollVelocity.x = 0 }
        if origin.y <= 0 || origin.y >= maxOriginY { autoscrollVelocity.y = 0 }

        guard didScroll else {
            if autoscrollVelocity == .zero { stopAutoscroll() }
            return
        }

        scrollView.contentView.scroll(to: origin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
        processAutoscrollSelection(in: tableView)

        if autoscrollVelocity == .zero { stopAutoscroll() }
    }

    func processAutoscrollSelection(in tableView: NSTableView) {
        guard isDraggingCellSelection, let anchor = selectionAnchor else { return }
        let point = tableView.convert(lastDragLocationInWindow, from: nil)
        guard let cell = resolvedCell(at: point, in: tableView, allowOutOfBounds: true) else { return }
        let region = SelectedRegion(start: anchor, end: cell)
        if selectionRegion != region {
            setSelectionRegion(region, tableView: tableView)
        }
    }
}
#endif
