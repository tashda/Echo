import SwiftUI
#if os(macOS)
import AppKit

struct PreferenceBasedPopover: View {
    let content: AnyView
    @Binding var isPresented: Bool
    let anchorIndex: Int
    @Environment(\.breadcrumbAnchors) private var breadcrumbAnchors

    var body: some View {
        if isPresented, let targetAnchorInfo = breadcrumbAnchors.first(where: { $0.index == anchorIndex }) {
            GeometryReader { geometry in
                Color.clear.background(NativePopover(content: content, isPresented: $isPresented, anchorRect: geometry[targetAnchorInfo.anchor]))
            }
        } else { EmptyView() }
    }
}

struct PreferenceBasedControllerPopover: View {
    let controller: NSViewController
    @Binding var isPresented: Bool
    let anchorIndex: Int
    @Environment(\.breadcrumbAnchors) private var breadcrumbAnchors

    var body: some View {
        if isPresented, let targetAnchorInfo = breadcrumbAnchors.first(where: { $0.index == anchorIndex }) {
            GeometryReader { geometry in
                Color.clear.background(NativePopoverController(controller: controller, isPresented: $isPresented, anchorRect: geometry[targetAnchorInfo.anchor]))
            }
        } else { EmptyView() }
    }
}

final class PopoverAnchorView: NSView {
    var onWindowReady: ((NSView) -> Void)?
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); guard window != nil else { return }; onWindowReady?(self) }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

@MainActor
struct NativePopover: NSViewRepresentable {
    let content: AnyView
    @Binding var isPresented: Bool
    let anchorRect: CGRect

    func makeNSView(context: Context) -> NSView {
        let view = PopoverAnchorView()
        view.onWindowReady = { [weak view] _ in guard let view else { return }; context.coordinator.anchorView = view; context.coordinator.tryPresentIfNeeded() }
        context.coordinator.anchorView = view; return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onClose = { isPresented = false }
        context.coordinator.isPresented = isPresented; context.coordinator.anchorRect = anchorRect; context.coordinator.content = content; context.coordinator.tryPresentIfNeeded()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor
    class Coordinator: NSObject, NSPopoverDelegate {
        weak var anchorView: NSView?; var popover: NSPopover?; var onClose: (() -> Void)?; var isPresented = false; var anchorRect: CGRect = .zero; var content: AnyView?
        func popoverDidClose(_ n: Notification) { popover = nil; onClose?() }
        func tryPresentIfNeeded() {
            guard let anchorView, isPresented, anchorView.window != nil, !anchorRect.isEmpty, !anchorRect.isNull, popover == nil, let content else {
                if !isPresented { popover?.performClose(nil); popover = nil }
                return
            }
            let p = NSPopover(); let h = NSHostingController(rootView: content); p.contentViewController = h; p.behavior = .semitransient; p.animates = true
            p.appearance = anchorView.effectiveAppearance; h.view.appearance = anchorView.effectiveAppearance; p.delegate = self
            p.show(relativeTo: anchorRect, of: anchorView, preferredEdge: .minY); self.popover = p
        }
    }
}

@MainActor
struct NativePopoverController: NSViewRepresentable {
    let controller: NSViewController
    @Binding var isPresented: Bool
    let anchorRect: CGRect

    func makeNSView(context: Context) -> NSView {
        let view = PopoverAnchorView()
        view.onWindowReady = { [weak view] _ in guard let view else { return }; context.coordinator.anchorView = view; context.coordinator.tryPresentIfNeeded() }
        context.coordinator.anchorView = view; return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onClose = { isPresented = false }
        context.coordinator.isPresented = isPresented; context.coordinator.anchorRect = anchorRect; context.coordinator.controller = controller; context.coordinator.tryPresentIfNeeded()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor
    class Coordinator: NSObject, NSPopoverDelegate {
        weak var anchorView: NSView?; var popover: NSPopover?; var onClose: (() -> Void)?; var isPresented = false; var anchorRect: CGRect = .zero; var controller: NSViewController?
        func popoverDidClose(_ n: Notification) { popover = nil; onClose?() }
        func tryPresentIfNeeded() {
            guard let anchorView, isPresented, anchorView.window != nil, !anchorRect.isEmpty, !anchorRect.isNull, popover == nil, let controller else {
                if !isPresented { popover?.performClose(nil); popover = nil }
                return
            }
            let p = NSPopover(); p.contentViewController = controller; p.behavior = .semitransient; p.animates = true
            p.appearance = anchorView.effectiveAppearance; controller.view.appearance = anchorView.effectiveAppearance; p.delegate = self
            p.show(relativeTo: anchorRect, of: anchorView, preferredEdge: .minY); self.popover = p
        }
    }
}
#endif
