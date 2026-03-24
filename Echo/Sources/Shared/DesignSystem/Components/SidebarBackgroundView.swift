import SwiftUI
import AppKit

/// An NSVisualEffectView configured to match the native sidebar material.
/// Use this as a `.background()` on views that float over the sidebar
/// (e.g. the icon menu bar) so they blend seamlessly with the sidebar's
/// system-provided vibrancy rather than showing a mismatched color.
struct SidebarBackgroundView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
