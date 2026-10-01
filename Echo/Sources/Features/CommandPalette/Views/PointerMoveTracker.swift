import AppKit

/// Tells a real mouse move from a hover event caused by content scrolling under a still pointer,
/// by comparing the pointer's screen position with the last one seen.
@MainActor
final class PointerMoveTracker {
    private var lastLocation: NSPoint?

    func pointerMoved() -> Bool {
        let location = NSEvent.mouseLocation
        defer { lastLocation = location }
        guard let lastLocation else { return false }
        return lastLocation != location
    }
}
