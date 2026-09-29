import AppKit

/// The borderless window that carries the EchoSense popup. It replaces the system popover so
/// the popup can use the card material and follow the Card Corners setting (ESR5). It never
/// takes focus: typing stays in the editor, which forwards the arrow keys, Return, Tab and Esc.
@MainActor
final class SQLCompletionPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = true
        animationBehavior = .none
        collectionBehavior = [.transient, .ignoresCycle, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
