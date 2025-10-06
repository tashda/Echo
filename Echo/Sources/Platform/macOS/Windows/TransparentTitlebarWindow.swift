//
//  TransparentTitlebarWindow.swift
//  Echo
//
//  Created by Codex on 07/10/2025.
//
//  Derived from Ghostty's TransparentTitlebarTerminalWindow.
//

import AppKit

/// Provides the transparent titlebar effect Ghostty uses so the window's content color
/// bleeds into the titlebar. Subclasses should call `syncAppearance()` whenever the
/// window's background color changes.
class TransparentTitlebarWindow: TerminalWindow {
    /// The preferred background color for both the window and titlebar.
    var preferredBackgroundColor: NSColor? {
        didSet {
            syncAppearance()
        }
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

    func syncAppearance() {
        guard isVisible else { return }

        if let preferredBackgroundColor {
            backgroundColor = preferredBackgroundColor.withAlphaComponent(1)
        }

        if #available(macOS 26.0, *) {
            applyTahoeAppearance()
        } else {
            applyVenturaAppearance()
        }
    }

    @available(macOS 26.0, *)
    private func applyTahoeAppearance() {
        guard let titlebarView = titlebarContainer?.firstDescendant(withClassName: "NSTitlebarView") else { return }
        titlebarView.wantsLayer = true
        titlebarView.layer?.backgroundColor = preferredBackgroundColor?.cgColor

        titlebarBackgroundView?.isHidden = true
    }

    private func applyVenturaAppearance() {
        guard let titlebarContainer else { return }
        titlebarContainer.wantsLayer = true
        titlebarContainer.layer?.backgroundColor = preferredBackgroundColor?.cgColor
        titlebarBackgroundView?.isHidden = true
    }

    private var titlebarBackgroundView: NSView? {
        titlebarContainer?.firstDescendant(withClassName: "NSTitlebarBackgroundView")
    }
}
