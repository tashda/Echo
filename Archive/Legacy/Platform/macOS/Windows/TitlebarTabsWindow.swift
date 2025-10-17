//  TitlebarTabsWindow.swift
//  Echo
//
//  Created by Codex on 07/10/2025.
//
//  Port of Ghostty's Tahoe titlebar tab styling with Echo-specific hooks.
//
import AppKit
import SwiftUI

final class TitlebarTabsWindow: TransparentTitlebarWindow {
    // MARK: - Public Callbacks

    var onOpenNewTab: (() -> Void)?
    var onToggleTabOverview: (() -> Void)?

    // MARK: - Initialisation

    override init(contentRect: NSRect, styleMask: NSWindow.StyleMask, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: styleMask, backing: backing, defer: flag)
        titleVisibility = .hidden
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - NSWindow Overrides

    override var title: String {
        didSet {}
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        titleVisibility = .hidden
    }

    func resetSidebarInset() {
        // no-op; maintained for backward compatibility with previous layout code
    }
}
