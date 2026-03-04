import SwiftUI

#if os(macOS)
import AppKit

/// A wrapper that presents a popover from a SwiftUI view
struct BreadcrumbPopover: NSViewControllerRepresentable {
    let content: AnyView
    let isPresented: Binding<Bool>
    let sourceView: NSView
    let preferredEdge: NSRectEdge

    func makeNSViewController(context: Context) -> NSViewController {
        let viewController = NSViewController()
        return viewController
    }

    func updateNSViewController(_ nsViewController: NSViewController, context: Context) {
        if isPresented.wrappedValue {
            let popover = NSPopover()
            popover.contentViewController = NSHostingController(rootView: content)
            popover.behavior = .semitransient
            popover.animates = true

            // Style to match Xcode
            popover.appearance = NSApp.effectiveAppearance

            // Show the popover
            popover.show(relativeTo: sourceView.bounds, of: sourceView, preferredEdge: preferredEdge)

            // Store popover reference for cleanup
            context.coordinator.popover = popover
        } else {
            context.coordinator.popover?.performClose(nil)
            context.coordinator.popover = nil
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var popover: NSPopover?
    }
}

#endif

/// SwiftUI wrapper for breadcrumb popover functionality
struct BreadcrumbPopoverWrapper: View {
    let content: AnyView
    let isPresented: Binding<Bool>
    let anchorView: Anchor<CGRect>

    var body: some View {
        #if os(macOS)
        if isPresented.wrappedValue {
            GeometryReader { geometry in
                Color.clear
                    .background(
                        NativeBreadcrumbPopover(
                            content: content,
                            isPresented: isPresented,
                            geometry: geometry,
                            anchorView: anchorView
                        )
                    )
            }
        } else {
            EmptyView()
        }
        #else
        EmptyView()
        #endif
    }
}

#if os(macOS)
private struct NativeBreadcrumbPopover: NSViewRepresentable {
    let content: AnyView
    @Binding var isPresented: Bool
    let geometry: GeometryProxy
    let anchorView: Anchor<CGRect>

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let window = nsView.window else { return }

        if isPresented, context.coordinator.popover == nil {
            let popover = NSPopover()
            popover.contentViewController = NSHostingController(rootView: content)
            popover.behavior = .semitransient
            popover.animates = true
            popover.appearance = NSApp.effectiveAppearance

            // Calculate position
            let anchorRect = geometry[anchorView]
            let viewRect = nsView.convert(anchorRect, to: nil)

            popover.show(relativeTo: viewRect, of: nsView, preferredEdge: .minY)
            context.coordinator.popover = popover
        } else if !isPresented {
            context.coordinator.popover?.performClose(nil)
            context.coordinator.popover = nil
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var popover: NSPopover?
    }
}
#endif