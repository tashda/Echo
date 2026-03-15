import SwiftUI
#if os(macOS)
import AppKit

struct InspectorSplitViewConfigurator: NSViewRepresentable {
    var width: Binding<CGFloat>
    /// The width we want the inspector to be (e.g. 600 for JSON, 300 default).
    var targetWidth: CGFloat
    let minWidth: CGFloat
    let maxWidth: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(width: width, targetWidth: targetWidth, minWidth: minWidth, maxWidth: maxWidth)
    }

    func makeNSView(context: Context) -> ObserverView {
        let view = ObserverView()
        view.coordinator = context.coordinator
        context.coordinator.observedView = view
        return view
    }

    func updateNSView(_ nsView: ObserverView, context: Context) {
        let coord = context.coordinator
        coord.width = width
        coord.minWidth = minWidth
        coord.maxWidth = maxWidth
        coord.observedView = nsView

        let oldTarget = coord.targetWidth
        let targetChanged = abs(oldTarget - targetWidth) > 0.5
        coord.targetWidth = targetWidth

        if targetChanged {
            coord.applyTargetWidth()
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        var width: Binding<CGFloat>
        var targetWidth: CGFloat
        var minWidth: CGFloat
        var maxWidth: CGFloat
        weak var observedView: NSView?

        /// Prevents sync-back from undoing a programmatic resize.
        private var resizeCooldownUntil: ContinuousClock.Instant = .now
        /// Incremented on each target change to invalidate stale scheduled calls.
        private var resizeGeneration: UInt = 0
        /// Tracks whether we have a pending deferred sync-back.
        private var syncScheduled = false

        init(width: Binding<CGFloat>, targetWidth: CGFloat, minWidth: CGFloat, maxWidth: CGFloat) {
            self.width = width; self.targetWidth = targetWidth
            self.minWidth = minWidth; self.maxWidth = maxWidth
        }

        // MARK: - Programmatic Resize

        /// Applies the target width by calling setPosition multiple times
        /// across several run loop iterations to overcome SwiftUI layout overrides.
        func applyTargetWidth() {
            let clampedTarget = max(minWidth, min(maxWidth, targetWidth))
            resizeGeneration &+= 1
            let generation = resizeGeneration

            // Set cooldown immediately to block sync-back
            resizeCooldownUntil = .now + .seconds(1)

            // Fire setPosition at staggered intervals.
            // SwiftUI may override early attempts during its own layout pass,
            // but later attempts (after layout settles) will stick.
            let delays: [Double] = [0.0, 0.05, 0.1, 0.15, 0.25, 0.4, 0.6]
            for delay in delays {
                Task { [weak self] in
                    if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
                    self?.performSetPosition(target: clampedTarget, generation: generation)
                }
            }

            // Clear cooldown after all attempts complete
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(1.0))
                guard let self, self.resizeGeneration == generation else { return }
                self.resizeCooldownUntil = .now
            }
        }

        private func performSetPosition(target: CGFloat, generation: UInt) {
            // Bail if a newer target change has superseded this one
            guard generation == resizeGeneration else { return }

            guard let view = observedView,
                  let (controller, splitView, index) = locateSplitViewInfo(from: view) else { return }

            // Don't resize if the inspector panel is collapsed/hidden
            let item = controller.splitViewItems[index]
            guard !item.isCollapsed else { return }

            let dividerIndex = index - 1
            guard dividerIndex >= 0 else { return }

            let totalWidth = splitView.frame.width
            guard totalWidth > 0 else { return }
            let position = totalWidth - target
            guard position > 0 else { return }

            splitView.setPosition(position, ofDividerAt: dividerIndex)
        }

        // MARK: - Sync-back (reads actual frame for user drags)

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
                  let (controller, splitView, index) = locateSplitViewInfo(from: view) else { return }

            // Configure split view item constraints
            let item = controller.splitViewItems[index]
            if item.minimumThickness != minWidth { item.minimumThickness = minWidth }
            if item.maximumThickness != maxWidth { item.maximumThickness = maxWidth }
            if item.holdingPriority != .defaultLow { item.holdingPriority = .defaultLow }

            // Don't sync back during cooldown — programmatic resize in progress
            guard ContinuousClock.now >= resizeCooldownUntil else { return }

            guard let inspectorView = splitView.subviews[safe: index] else { return }
            let inspectorWidth = max(minWidth, min(maxWidth, inspectorView.frame.width))
            if abs(width.wrappedValue - inspectorWidth) > 0.5 {
                width.wrappedValue = inspectorWidth
            }
        }

        // MARK: - Split View Discovery

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

        override func layout() {
            super.layout()
            coordinator?.scheduleSyncBack()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            coordinator?.scheduleSyncBack()
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}

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
