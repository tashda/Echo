import SwiftUI
#if os(macOS)
import AppKit

struct InspectorSplitViewConfigurator: NSViewRepresentable {
    var width: Binding<CGFloat>
    let minWidth: CGFloat
    let maxWidth: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(width: width, minWidth: minWidth, maxWidth: maxWidth)
    }

    func makeNSView(context: Context) -> ObserverView {
        let view = ObserverView()
        view.coordinator = context.coordinator
        context.coordinator.register(observedView: view)
        return view
    }

    func updateNSView(_ nsView: ObserverView, context: Context) {
        context.coordinator.width = width
        context.coordinator.minWidth = minWidth
        context.coordinator.maxWidth = maxWidth
        context.coordinator.register(observedView: nsView)
    }

    @MainActor
    final class Coordinator: NSObject {
        var width: Binding<CGFloat>
        var minWidth: CGFloat
        var maxWidth: CGFloat
        private weak var observedView: NSView?
        private var pendingUpdate = false
        private var lastAppliedWidth: CGFloat?

        init(width: Binding<CGFloat>, minWidth: CGFloat, maxWidth: CGFloat) {
            self.width = width; self.minWidth = minWidth; self.maxWidth = maxWidth
        }

        func register(observedView view: NSView) {
            if observedView !== view { observedView = view }
            scheduleUpdate()
        }

        private func scheduleUpdate() {
            guard !pendingUpdate else { return }
            pendingUpdate = true
            Task { @MainActor [weak self] in
                guard let self, let view = self.observedView else { self?.pendingUpdate = false; return }
                self.pendingUpdate = false
                self.performUpdate(using: view)
            }
        }

        private func performUpdate(using nsView: NSView) {
            guard let (controller, splitView, index) = locateSplitViewInfo(from: nsView) else { return }
            let item = controller.splitViewItems[index]
            if item.minimumThickness != minWidth { item.minimumThickness = minWidth }
            if item.maximumThickness != maxWidth { item.maximumThickness = maxWidth }
            if item.holdingPriority != .defaultLow { item.holdingPriority = .defaultLow }

            guard let inspectorView = splitView.subviews[safe: index] else { return }
            let desiredWidth = clamp(width.wrappedValue)
            let inspectorWidth = clamp(inspectorView.frame.width)
            let previouslyApplied = lastAppliedWidth ?? inspectorWidth

            if abs(desiredWidth - previouslyApplied) > 0.5 {
                if abs(inspectorWidth - desiredWidth) > 0.5 {
                    adjustDividerPosition(splitView: splitView, itemIndex: index, targetWidth: desiredWidth)
                }
                lastAppliedWidth = desiredWidth
            } else {
                if abs(inspectorWidth - desiredWidth) > 0.5 {
                    let clampedInspector = clamp(inspectorWidth)
                    if abs(width.wrappedValue - clampedInspector) > 0.1 { width.wrappedValue = clampedInspector }
                    lastAppliedWidth = clampedInspector
                } else { lastAppliedWidth = desiredWidth }
            }
        }

        private func adjustDividerPosition(splitView: NSSplitView, itemIndex: Int, targetWidth: CGFloat) {
            guard itemIndex > 0 else { return }
            let totalWidth = splitView.bounds.width
            guard totalWidth > 0 else { return }
            let dividerPosition = max(0, min(totalWidth - targetWidth, totalWidth))
            NSAnimationContext.beginGrouping()
            NSAnimationContext.current.duration = 0
            splitView.setPosition(dividerPosition, ofDividerAt: itemIndex - 1)
            NSAnimationContext.endGrouping()
        }

        private func clamp(_ value: CGFloat) -> CGFloat { max(minWidth, min(maxWidth, value)) }

        private func locateSplitViewInfo(from view: NSView) -> (NSSplitViewController, NSSplitView, Int)? {
            var responder: NSResponder? = view
            while let current = responder {
                if let controller = current as? NSSplitViewController {
                    let splitView = controller.splitView
                    for (index, item) in controller.splitViewItems.enumerated() {
                        if item.viewController.view.isDescendant(of: view) || view.isDescendant(of: item.viewController.view) { return (controller, splitView, index) }
                    }
                }
                responder = current.nextResponder
            }
            return nil
        }
    }

    final class ObserverView: NSView {
        weak var coordinator: Coordinator?
        override func layout() { super.layout(); coordinator?.register(observedView: self) }
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); coordinator?.register(observedView: self) }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}

struct SidebarSplitViewObserver: NSViewRepresentable {
    @Binding var width: CGFloat
    func makeCoordinator() -> Coordinator { Coordinator(width: $width) }
    func makeNSView(context: Context) -> ObserverView {
        let view = ObserverView(); view.coordinator = context.coordinator
        context.coordinator.register(observedView: view)
        return view
    }
    func updateNSView(_ nsView: ObserverView, context: Context) {
        context.coordinator.width = $width; context.coordinator.register(observedView: nsView)
    }

    @MainActor
    final class Coordinator: NSObject {
        var width: Binding<CGFloat>
        private weak var observedView: NSView?
        private var pendingUpdate = false
        init(width: Binding<CGFloat>) { self.width = width }
        func register(observedView view: NSView) { if observedView !== view { observedView = view }; scheduleUpdate() }
        func sidebarDidDetach() { if abs(width.wrappedValue) > 0.5 { width.wrappedValue = 0 } }
        private func scheduleUpdate() {
            guard !pendingUpdate else { return }
            pendingUpdate = true
            Task { @MainActor [weak self] in
                guard let self, let view = self.observedView else { self?.pendingUpdate = false; return }
                self.pendingUpdate = false
                self.performUpdate(using: view)
            }
        }
        private func performUpdate(using nsView: NSView) {
            guard let (_, splitView, index) = locateSplitViewInfo(from: nsView), let sidebarView = splitView.subviews[safe: index] else { return }
            let measuredWidth = max(0, sidebarView.frame.width)
            if abs(width.wrappedValue - measuredWidth) > 0.5 { width.wrappedValue = measuredWidth }
        }
        private func locateSplitViewInfo(from view: NSView) -> (NSSplitViewController, NSSplitView, Int)? {
            var responder: NSResponder? = view
            while let current = responder {
                if let controller = current as? NSSplitViewController {
                    let splitView = controller.splitView
                    for (index, item) in controller.splitViewItems.enumerated() {
                        if item.viewController.view.isDescendant(of: view) || view.isDescendant(of: item.viewController.view) { return (controller, splitView, index) }
                    }
                }
                responder = current.nextResponder
            }
            return nil
        }
    }

    final class ObserverView: NSView {
        weak var coordinator: Coordinator?
        override func layout() { super.layout(); coordinator?.register(observedView: self) }
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); if window == nil { coordinator?.sidebarDidDetach() } else { coordinator?.register(observedView: self) } }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
#endif
