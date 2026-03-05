import SwiftUI

#if os(macOS)
import AppKit

extension TopBarNavigatorOverlay {
    func disableImplicitAnimations(for view: NSView) {
        var animations = view.animations
        animations["frameOrigin"] = NSNull()
        animations["frameSize"] = NSNull()
        animations["bounds"] = NSNull()
        animations["position"] = NSNull()
        view.animations = animations
    }

    func disableImplicitFrameAnimationsRecursively(in view: NSView) {
        disableImplicitAnimations(for: view)
        for subview in view.subviews {
            disableImplicitFrameAnimationsRecursively(in: subview)
        }
    }

    func findToolbarView(in window: NSWindow) -> NSView? {
        guard let titlebarContainer = window.contentView?.superview else { return nil }
        var views: [NSView] = [titlebarContainer]

        while let view = views.popLast() {
            let className = String(describing: type(of: view))
            if className.contains("NSTitlebarContainerView") {
                views.append(contentsOf: view.subviews)
                continue
            }
            if className.contains("NSToolbarView") {
                return view
            }
            views.append(contentsOf: view.subviews)
        }

        return nil
    }
}
#endif
