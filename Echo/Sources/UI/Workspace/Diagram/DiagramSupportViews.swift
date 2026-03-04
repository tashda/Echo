import SwiftUI

#if os(macOS)
import AppKit

struct CommandScrollZoomCapture: NSViewRepresentable {
    let onZoom: (CGFloat) -> Void

    func makeNSView(context: Context) -> ZoomCaptureView {
        let view = ZoomCaptureView()
        view.onZoom = onZoom
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        return view
    }

    func updateNSView(_ nsView: ZoomCaptureView, context: Context) {
        nsView.onZoom = onZoom
    }

    @MainActor
    final class ZoomCaptureView: NSView {
        var onZoom: ((CGFloat) -> Void)?
        private var scrollMonitor: Any?

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            translatesAutoresizingMaskIntoConstraints = false
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil {
                installMonitorIfNeeded()
            }
        }

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            if newWindow == nil {
                removeMonitor()
            }
            super.viewWillMove(toWindow: newWindow)
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }

        deinit {
            Task { @MainActor [weak self] in
                self?.removeMonitor()
            }
        }

        private func installMonitorIfNeeded() {
            guard scrollMonitor == nil else { return }
            scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self,
                      let window = self.window,
                      event.window === window,
                      event.modifierFlags.contains(.command) else {
                    return event
                }
                self.onZoom?(event.scrollingDeltaY)
                return nil
            }
        }

        private func removeMonitor() {
            if let monitor = scrollMonitor {
                NSEvent.removeMonitor(monitor)
                scrollMonitor = nil
            }
        }
    }
}
#else
struct CommandScrollZoomCapture: View {
    let onZoom: (CGFloat) -> Void
    var body: some View { Color.clear }
}
#endif
