import SwiftUI
import AppKit

/// Intercepts the window close button when there are unsaved changes.
/// Shows a native macOS alert: Discard Changes / Cancel.
struct UnsavedChangesGuard: NSViewRepresentable {
    let hasChanges: Bool
    let onDiscard: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(guard: self)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        Task {
            guard let window = view.window else { return }
            context.coordinator.install(on: window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.parent = self
        Task {
            guard let window = nsView.window else { return }
            context.coordinator.install(on: window)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSWindowDelegate {
        var parent: UnsavedChangesGuard
        private weak var window: NSWindow?
        private weak var originalDelegate: NSWindowDelegate?
        private var isClosingAfterChoice = false

        init(guard parent: UnsavedChangesGuard) {
            self.parent = parent
        }

        func install(on window: NSWindow) {
            guard self.window !== window else { return }
            self.window = window
            if window.delegate !== self {
                originalDelegate = window.delegate
            }
            window.delegate = self
        }

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            if isClosingAfterChoice {
                return originalDelegate?.windowShouldClose?(sender) ?? true
            }
            guard parent.hasChanges else {
                return originalDelegate?.windowShouldClose?(sender) ?? true
            }

            let alert = NSAlert()
            alert.messageText = "You have unsaved changes"
            alert.informativeText = "Your changes will be lost if you close this window."
            alert.alertStyle = .informational
            // First button = default (blue/accent, triggered by Return key)
            alert.addButton(withTitle: "Discard Changes")
            // Second button = cancel (triggered by Escape key)
            let cancelButton = alert.addButton(withTitle: "Cancel")
            cancelButton.keyEquivalent = "\u{1b}" // Escape

            alert.beginSheetModal(for: sender) { [weak self] response in
                guard let self else { return }
                if response == .alertFirstButtonReturn {
                    self.isClosingAfterChoice = true
                    self.parent.onDiscard()
                }
            }
            return false
        }

        func windowDidBecomeKey(_ notification: Notification) {
            originalDelegate?.windowDidBecomeKey?(notification)
        }

        func windowDidResignKey(_ notification: Notification) {
            originalDelegate?.windowDidResignKey?(notification)
        }

        override func responds(to aSelector: Selector!) -> Bool {
            super.responds(to: aSelector) || (originalDelegate?.responds(to: aSelector) ?? false)
        }

        override func forwardingTarget(for aSelector: Selector!) -> Any? {
            if originalDelegate?.responds(to: aSelector) == true {
                return originalDelegate
            }
            return super.forwardingTarget(for: aSelector)
        }
    }
}
