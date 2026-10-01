import SwiftUI
import EchoSense
import AppKit

extension SQLAutoCompletionController {

    // MARK: Content

    func updatePanelContent() {
        let view = AutoCompletionListView(
            suggestions: flatSuggestions,
            selectedID: selectedSuggestion?.id,
            isChoosing: isChoosing,
            typed: typedText,
            nameFont: textView?.theme.font.font ?? .monospacedSystemFont(ofSize: SQLEditorTheme.defaultFontSize, weight: .regular),
            cardCornerRadius: textView?.displayOptions.cardCornerRadius ?? LayoutTokens.Workspace.cardCornerRadius,
            statusMessage: Self.statusMessage(isMetadataLimited: textView?.completionEngine.isMetadataLimited == true),
            onSelect: { [weak self] suggestion in self?.accept(suggestion) }
        )
        let host: NSHostingView<AutoCompletionListView>
        if let hostingView {
            hostingView.rootView = view
            host = hostingView
        } else {
            host = NSHostingView(rootView: view)
            host.sizingOptions = [.intrinsicContentSize]
            panel.contentView = host
            hostingView = host
        }
        host.layoutSubtreeIfNeeded()
        let size = host.fittingSize
        panel.setContentSize(NSSize(width: ceil(size.width), height: ceil(size.height)))
    }

    /// What the user has typed of the word being completed, for highlighting.
    var typedText: String {
        guard let textView, let range = anchorRange else { return "" }
        let string = textView.string as NSString
        guard range.location != NSNotFound, NSMaxRange(range) <= string.length else { return "" }
        let typed = string.substring(with: range)
        return typed.split(separator: ".").last.map(String.init) ?? typed
    }

    static func statusMessage(isMetadataLimited: Bool) -> String? {
        isMetadataLimited ? "Limited metadata — showing keywords and history" : nil
    }

    // MARK: Position

    /// Places the panel under the word, with the names lined up with the typed text; above the
    /// line when there is no room below. Returns false when the caret can't be located.
    @discardableResult
    func positionPanel() -> Bool {
        guard let textView, let window = textView.window, let range = anchorRange,
              let caretRect = caretRectForRange(range) else { return false }
        let screenRect = window.convertToScreen(textView.convert(caretRect, to: nil))
        let size = panel.frame.size
        let nameInset = LayoutTokens.EchoSense.padding + LayoutTokens.EchoSense.rowHorizontalPadding
            + LayoutTokens.EchoSense.badgeSize + LayoutTokens.EchoSense.rowSpacing
        var origin = NSPoint(x: screenRect.minX - nameInset, y: screenRect.maxY - size.height)
        if let visible = window.screen?.visibleFrame {
            if origin.y < visible.minY {
                origin.y = screenRect.maxY + caretRect.height + LayoutTokens.EchoSense.caretGap * 2
            }
            origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
        }
        panel.setFrameOrigin(origin)
        return true
    }

    /// The caret's line rect in the text view, moved just below the line.
    func caretRectForRange(_ range: NSRange) -> NSRect? {
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return nil }

        var queryRange = range
        if queryRange.length == 0 && queryRange.location > 0 {
            queryRange = NSRange(location: max(queryRange.location - 1, 0), length: 1)
        }

        var glyphRange = layoutManager.glyphRange(forCharacterRange: queryRange, actualCharacterRange: nil)
        if glyphRange.length == 0 && glyphRange.location > 0 {
            glyphRange = NSRange(location: max(glyphRange.location - 1, 0), length: 1)
        }

        var caretRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        caretRect.origin.x += textView.textContainerInset.width
        caretRect.origin.y += textView.textContainerInset.height
        caretRect.origin.y += caretRect.height
        caretRect.origin.y += LayoutTokens.EchoSense.caretGap

        caretRect.size.width = max(caretRect.width, 2)
        caretRect.size.height = max(caretRect.height, 18)
        return caretRect
    }

    // MARK: Showing and dismissing

    func attachPanel() {
        guard let window = textView?.window else { return }
        if panel.parent !== window {
            panel.parent?.removeChildWindow(panel)
            window.addChildWindow(panel, ordered: .above)
        }
        panel.orderFront(nil)
        installDismissal(for: window)
    }

    func detachPanel() {
        removeDismissal()
        panel.parent?.removeChildWindow(panel)
        panel.orderOut(nil)
    }

    /// The popup closes on a click anywhere but itself and when its window stops being key, as
    /// the system popover did. It follows the editor's scrolling while the word stays in view.
    private func installDismissal(for window: NSWindow) {
        guard dismissalMonitor == nil else { return }
        dismissalMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self, event.window !== self.panel else { return }
                self.hide()
            }
            return event
        }
        let center = NotificationCenter.default
        var observers = [center.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.hide() }
        }]
        if let clipView = textView?.enclosingScrollView?.contentView {
            clipView.postsBoundsChangedNotifications = true
            observers.append(center.addObserver(forName: NSView.boundsDidChangeNotification, object: clipView, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.followScroll() }
            })
        }
        dismissalObservers = observers
    }

    private func followScroll() {
        guard let textView, let range = anchorRange, let caretRect = caretRectForRange(range),
              textView.visibleRect.intersects(caretRect.offsetBy(dx: 0, dy: -caretRect.height)) else {
            hide()
            return
        }
        positionPanel()
    }

    private func removeDismissal() {
        if let dismissalMonitor { NSEvent.removeMonitor(dismissalMonitor) }
        dismissalMonitor = nil
        dismissalObservers.forEach(NotificationCenter.default.removeObserver)
        dismissalObservers = []
    }
}
