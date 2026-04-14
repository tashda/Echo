import SwiftUI
#if os(macOS)
import AppKit

private struct MiddleClickGestureModifier: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content.background(MiddleClickCapture(onMiddleClick: action))
    }
}

private struct MiddleClickCapture: NSViewRepresentable {
    let onMiddleClick: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onMiddleClick: onMiddleClick)
    }

    func makeNSView(context: Context) -> MiddleClickReceiverView {
        let view = MiddleClickReceiverView()
        view.onSuperviewChanged = { superview in
            if let superview {
                context.coordinator.attach(to: superview)
            } else {
                context.coordinator.detach()
            }
        }
        return view
    }

    func updateNSView(_ nsView: MiddleClickReceiverView, context: Context) {
        context.coordinator.onMiddleClick = onMiddleClick
        if let superview = nsView.superview {
            context.coordinator.attach(to: superview)
        } else {
            context.coordinator.detach()
        }
    }

    @MainActor
    final class Coordinator {
        var onMiddleClick: () -> Void
        private weak var attachedView: NSView?
        private nonisolated(unsafe) var monitor: Any?

        init(onMiddleClick: @escaping () -> Void) {
            self.onMiddleClick = onMiddleClick
        }

        func attach(to view: NSView) {
            guard attachedView !== view else { return }
            detach()
            attachedView = view
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.otherMouseUp]) { [weak self] event in
                guard let self,
                      let attachedView = self.attachedView,
                      event.window === attachedView.window else {
                    return event
                }

                let location = attachedView.convert(event.locationInWindow, from: nil)
                if attachedView.bounds.contains(location) {
                    self.onMiddleClick()
                    return nil
                }

                return event
            }
        }

        func detach() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
            attachedView = nil
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}

private final class MiddleClickReceiverView: NSView {
    var onSuperviewChanged: ((NSView?) -> Void)?

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        onSuperviewChanged?(superview)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

extension View {
    func onMiddleClick(perform action: @escaping () -> Void) -> some View {
        modifier(MiddleClickGestureModifier(action: action))
    }
}
#else
extension View {
    func onMiddleClick(perform action: @escaping () -> Void) -> some View {
        self
    }
}
#endif
