//
//  TransparentTitlebarWindow.swift
//  Echo
//
//  Created by Codex on 07/10/2025.
//
//  Derived from Ghostty's TransparentTitlebarTerminalWindow.
//

import AppKit

/// Lightweight window subclass that keeps the titlebar transparent and syncs with a preferred background color.
class TransparentTitlebarWindow: NSWindow {
    var preferredBackgroundColor: NSColor? {
        didSet { syncAppearance() }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        syncAppearance()
    }

    override func becomeMain() {
        super.becomeMain()
        syncAppearance()
    }

    override func update() {
        super.update()
        syncAppearance()
    }

    private func syncAppearance() {
        guard isVisible else { return }
        if let preferredBackgroundColor {
            backgroundColor = preferredBackgroundColor.withAlphaComponent(1)
        }
    }
}
