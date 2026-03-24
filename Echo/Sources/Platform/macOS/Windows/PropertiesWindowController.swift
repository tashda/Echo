import AppKit
import SwiftUI

/// Presents a SwiftUI properties editor view in a native NSWindow with correct
/// toolbar blur rendering. Supports multiple simultaneous instances.
///
/// This replaces `WindowGroup` for properties editors because `WindowGroup`
/// has a bug where the toolbar renders with an opaque background on initial
/// display instead of the correct transparent blur material.
@MainActor
final class PropertiesWindowController: NSWindowController, NSWindowDelegate {
    /// All currently open property windows, keyed by a caller-chosen string.
    private static var openWindows: [String: PropertiesWindowController] = [:]
    private static let toolbarIdentifier = NSToolbar.Identifier("PropertiesEditorToolbar")

    private let windowKey: String
    private var hostingController: PocketSeparatorHidingHostingController<AnyView>?

    private init(windowKey: String) {
        self.windowKey = windowKey
        super.init(window: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Opens a properties editor window. If a window with the same key is
    /// already open, it is replaced with fresh content.
    static func present<Content: View>(
        key: String,
        title: String,
        size: NSSize = NSSize(width: 900, height: 540),
        @ViewBuilder content: () -> Content
    ) {
        // Close existing window with same key
        if let existing = openWindows[key] {
            existing.window?.close()
            openWindows.removeValue(forKey: key)
        }

        let controller = PropertiesWindowController(windowKey: key)
        let rootView = AnyView(content())
        controller.configureWindow(title: title, size: size, rootView: rootView)

        openWindows[key] = controller

        guard let window = controller.window else { return }
        controller.applyTheme(to: window)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func configureWindow(title: String, size: NSSize, rootView: AnyView) {
        let hosting = PocketSeparatorHidingHostingController(rootView: rootView)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.isReleasedWhenClosed = false
        window.toolbarStyle = .unified
        window.titlebarSeparatorStyle = .none
        window.tabbingMode = .disallowed

        let toolbar = NSToolbar(identifier: Self.toolbarIdentifier)
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        toolbar.sizeMode = .regular
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar

        window.contentViewController = hosting
        window.delegate = self
        applyTheme(to: window)
        bindThemeUpdates(for: window)
        hostingController = hosting
        self.window = window
    }

    func windowWillClose(_ notification: Notification) {
        Self.openWindows.removeValue(forKey: windowKey)
    }

    private func bindThemeUpdates(for window: NSWindow) {
        observeThemeChanges(for: window)
    }

    private func observeThemeChanges(for window: NSWindow) {
        _ = withObservationTracking {
            AppearanceStore.shared.effectiveColorScheme
        } onChange: { [weak self, weak window] in
            Task { @MainActor in
                guard let self, let window else { return }
                self.applyTheme(to: window)
                self.observeThemeChanges(for: window)
            }
        }
    }

    private func applyTheme(to window: NSWindow) {
        let isDark = AppearanceStore.shared.effectiveColorScheme == .dark
        window.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
    }
}
