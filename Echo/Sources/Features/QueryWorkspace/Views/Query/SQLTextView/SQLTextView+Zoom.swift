#if os(macOS)
import AppKit

/// Round 28.8 (ZK0): pinching the editor zooms it a step at a time.
extension SQLTextView {
    override func magnify(with event: NSEvent) {
        if event.phase == .began { pinchAmount = 0 }
        pinchAmount += event.magnification
        let threshold = LayoutTokens.EditorGutter.pinchStepThreshold
        if pinchAmount > threshold {
            onZoomStep?(1)
            pinchAmount = 0
        } else if pinchAmount < -threshold {
            onZoomStep?(-1)
            pinchAmount = 0
        }
    }
}
#endif
