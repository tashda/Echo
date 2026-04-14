import SwiftUI
#if os(macOS)
import AppKit

struct SidebarSplitViewObserver: NSViewRepresentable {
    @Binding var width: CGFloat
    func makeCoordinator() -> Coordinator { Coordinator(width: $width) }
    func makeNSView(context: Context) -> ObserverView {
        let view = ObserverView(); view.coordinator = context.coordinator
        context.coordinator.observedView = view
        return view
    }
    func updateNSView(_ nsView: ObserverView, context: Context) {
        context.coordinator.width = $width; context.coordinator.observedView = nsView
    }

    @MainActor
    final class Coordinator: NSObject {
        var width: Binding<CGFloat>
        weak var observedView: NSView?
        private var syncScheduled = false
        init(width: Binding<CGFloat>) { self.width = width }
        func sidebarDidDetach() { if abs(width.wrappedValue) > 0.5 { width.wrappedValue = 0 } }

        func scheduleSyncBack() {
            guard !syncScheduled else { return }
            syncScheduled = true
            Task { [weak self] in
                self?.syncScheduled = false
                self?.performSyncBack()
            }
        }

        private func performSyncBack() {
            guard let view = observedView,
                  let (_, splitView, index) = locateSplitViewInfo(from: view),
                  let sidebarView = splitView.subviews[safe: index] else { return }
            let measuredWidth = max(0, sidebarView.frame.width)
            if abs(width.wrappedValue - measuredWidth) > 0.5 { width.wrappedValue = measuredWidth }
        }

        private func locateSplitViewInfo(from view: NSView) -> (NSSplitViewController, NSSplitView, Int)? {
            var responder: NSResponder? = view
            while let current = responder {
                if let controller = current as? NSSplitViewController {
                    let splitView = controller.splitView
                    for (index, item) in controller.splitViewItems.enumerated() {
                        if item.viewController.view.isDescendant(of: view) || view.isDescendant(of: item.viewController.view) {
                            return (controller, splitView, index)
                        }
                    }
                }
                responder = current.nextResponder
            }
            return nil
        }
    }

    final class ObserverView: NSView {
        weak var coordinator: Coordinator?
        override func layout() { super.layout(); coordinator?.scheduleSyncBack() }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil { coordinator?.sidebarDidDetach() } else { coordinator?.scheduleSyncBack() }
        }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
#endif
