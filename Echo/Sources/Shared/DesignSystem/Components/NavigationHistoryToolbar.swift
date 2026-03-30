import SwiftUI
#if os(macOS)
import AppKit
#endif

// MARK: - Simple single-value tracking

/// Adds back/forward toolbar buttons and automatically tracks changes to
/// a single selection binding.
struct NavigationHistoryToolbar<Value: Hashable>: ViewModifier {
    @Binding var selection: Value?
    @Bindable var history: NavigationHistory<Value>
    @State private var isRestoring = false

    func body(content: Content) -> some View {
        content
            .onMouseNavigation(
                canGoBack: history.canGoBack,
                canGoForward: history.canGoForward,
                onBack: goBack,
                onForward: goForward
            )
            .onChange(of: selection) { oldValue, _ in
                guard !isRestoring, let oldValue else { return }
                history.push(oldValue)
            }
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    ToolbarNavigationButtons(
                        canGoBack: history.canGoBack,
                        canGoForward: history.canGoForward,
                        onBack: goBack,
                        onForward: goForward
                    )
                }
            }
    }

    private func goBack() {
        guard let current = selection,
              let target = history.goBack(from: current) else { return }
        isRestoring = true
        selection = target
        Task { isRestoring = false }
    }

    private func goForward() {
        guard let current = selection,
              let target = history.goForward(from: current) else { return }
        isRestoring = true
        selection = target
        Task { isRestoring = false }
    }
}

// MARK: - Composite state tracking

/// Adds back/forward toolbar buttons with custom snapshot/restore logic
struct CompositeNavigationHistoryToolbar<State: Hashable>: ViewModifier {
    @Bindable var history: NavigationHistory<State>
    var snapshot: () -> State
    var restore: (State) -> Void

    func body(content: Content) -> some View {
        content
            .onMouseNavigation(
                canGoBack: history.canGoBack,
                canGoForward: history.canGoForward,
                onBack: goBack,
                onForward: goForward
            )
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    ToolbarNavigationButtons(
                        canGoBack: history.canGoBack,
                        canGoForward: history.canGoForward,
                        onBack: goBack,
                        onForward: goForward
                    )
                }
            }
    }

    private func goBack() {
        guard let target = history.goBack(from: snapshot()) else { return }
        restore(target)
    }

    private func goForward() {
        guard let target = history.goForward(from: snapshot()) else { return }
        restore(target)
    }
}

// MARK: - Mouse navigation support

#if os(macOS)
private struct MouseNavigationModifier: ViewModifier {
    var canGoBack: Bool
    var canGoForward: Bool
    var onBack: () -> Void
    var onForward: () -> Void

    func body(content: Content) -> some View {
        content.background(MouseNavigationCapture(
            canGoBack: canGoBack,
            canGoForward: canGoForward,
            onBack: onBack,
            onForward: onForward
        ))
    }
}

private struct MouseNavigationCapture: NSViewRepresentable {
    var canGoBack: Bool
    var canGoForward: Bool
    var onBack: () -> Void
    var onForward: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        // We use an NSView to get access to the window and reliably attach a monitor
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.update(
            canGoBack: canGoBack,
            canGoForward: canGoForward,
            onBack: onBack,
            onForward: onForward,
            window: nsView.window
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    class Coordinator {
        private var canGoBack = false
        private var canGoForward = false
        private var onBack: () -> Void = {}
        private var onForward: () -> Void = {}
        private var monitor: Any?
        private weak var window: NSWindow?

        func update(canGoBack: Bool, canGoForward: Bool, onBack: @escaping () -> Void, onForward: @escaping () -> Void, window: NSWindow?) {
            self.canGoBack = canGoBack
            self.canGoForward = canGoForward
            self.onBack = onBack
            self.onForward = onForward
            
            if self.window !== window {
                self.window = window
                setupMonitor()
            }
        }

        private func setupMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            guard let window else { return }
            
            // Monitor local events for this window
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.otherMouseUp, .otherMouseDown]) { [weak self] event in
                guard let self, 
                      let window = self.window,
                      event.window === window else {
                    return event
                }
                
                // Button 3 = Back, Button 4 = Forward (Standard HID)
                if event.buttonNumber == 3 {
                    if self.canGoBack {
                        if event.type == .otherMouseUp {
                            self.onBack()
                        }
                        return nil // Consume both down and up
                    }
                } else if event.buttonNumber == 4 {
                    if self.canGoForward {
                        if event.type == .otherMouseUp {
                            self.onForward()
                        }
                        return nil // Consume both down and up
                    }
                }
                
                return event
            }
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}
#endif

// MARK: - View extensions

extension View {
    @ViewBuilder
    fileprivate func onMouseNavigation(
        canGoBack: Bool,
        canGoForward: Bool,
        onBack: @escaping () -> Void,
        onForward: @escaping () -> Void
    ) -> some View {
        #if os(macOS)
        modifier(MouseNavigationModifier(
            canGoBack: canGoBack,
            canGoForward: canGoForward,
            onBack: onBack,
            onForward: onForward
        ))
        #else
        self
        #endif
    }

    func navigationHistoryToolbar<Value: Hashable>(
        _ selection: Binding<Value?>,
        history: NavigationHistory<Value>
    ) -> some View {
        modifier(NavigationHistoryToolbar(
            selection: selection,
            history: history
        ))
    }

    func compositeNavigationHistoryToolbar<State: Hashable>(
        history: NavigationHistory<State>,
        snapshot: @escaping () -> State,
        restore: @escaping (State) -> Void
    ) -> some View {
        modifier(CompositeNavigationHistoryToolbar(
            history: history,
            snapshot: snapshot,
            restore: restore
        ))
    }
}
