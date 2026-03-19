import SwiftUI
#if os(macOS)
import AppKit
#endif

#if os(macOS)
struct ExplorerSidebarFocusResetter: NSViewRepresentable {
    @Binding var isSearchFieldFocused: Bool

    func makeNSView(context: Context) -> FocusResetView {
        FocusResetView()
    }

    func updateNSView(_ nsView: FocusResetView, context: Context) {
        nsView.onDismiss = { [binding = $isSearchFieldFocused] in
            Task { @MainActor in
                guard binding.wrappedValue else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    binding.wrappedValue = false
                }
            }
        }
        nsView.isSearchFieldFocused = isSearchFieldFocused
    }

    @MainActor
    final class FocusResetView: NSView {
        var onDismiss: (() -> Void)?
        var isSearchFieldFocused: Bool = false {
            didSet { updateMonitor() }
        }

        private var monitor: Any?

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            translatesAutoresizingMaskIntoConstraints = false
            wantsLayer = false
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            updateMonitor()
        }

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            if newWindow == nil {
                removeMonitor()
            }
            super.viewWillMove(toWindow: newWindow)
        }

        @MainActor deinit {
            removeMonitor()
        }

        private func updateMonitor() {
            guard window != nil else {
                removeMonitor()
                return
            }

            if isSearchFieldFocused {
                installMonitorIfNeeded()
            } else {
                removeMonitor()
            }
        }

        private func installMonitorIfNeeded() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
                guard let self else { return event }
                guard let window = self.window else {
                    self.onDismiss?()
                    return event
                }

                if event.window !== window {
                    self.onDismiss?()
                    return event
                }

                let locationInWindow = event.locationInWindow
                let locationInView = self.convert(locationInWindow, from: nil)
                if !self.bounds.contains(locationInView) {
                    self.onDismiss?()
                }

                return event
            }
        }

        private func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }
    }
}
#else
struct ExplorerSidebarFocusResetter: View {
    @Binding var isSearchFieldFocused: Bool
    var body: some View {
        EmptyView()
    }
}
#endif
