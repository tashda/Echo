//
//  TerminalWindow.swift
//  Echo
//
//  Created by Codex on 07/10/2025.
//
//  Substantial portions adapted from Ghostty (https://github.com/mitchellh/ghostty)
//  under the MIT License. See NSView+Extensions.swift for license text.
//

import AppKit

/// Minimal base window that provides the plumbing Ghostty relies on to hook into the
/// native tab bar that AppKit creates for `NSTabGroup` windows. Subclasses override the
/// tab bar callbacks to restyle it.
class TerminalWindow: NSWindow {
    /// Identifier attached to the accessory controller that hosts the `NSTabBar`.
    static let tabBarIdentifier = NSUserInterfaceItemIdentifier("_echoTabBar")

    override func awakeFromNib() {
        super.awakeFromNib()

        // Disable automatic AppKit window tabbing so no native tab bar appears.
        tabbingMode = .disallowed
    }

    /// Returns the container that hosts the titlebar hierarchy.
    var titlebarContainer: NSView? {
        guard !styleMask.contains(.fullScreen) else {
            for window in NSApp.windows where window.className == "NSToolbarFullScreenWindow" && window.parent == self {
                return window.contentView?.firstViewFromRoot(withClassName: "NSTitlebarContainerView")
            }
            return nil
        }

        return contentView?.firstViewFromRoot(withClassName: "NSTitlebarContainerView")
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
