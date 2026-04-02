#if os(macOS)
import AppKit
import SwiftUI

/// Visual overlay for a validation diagnostic — renders an animated glow border
/// around the problematic text range using the warm amber/red palette.
final class ValidationAccessoryView: NSView {
    struct Layout {
        static let padding = NSEdgeInsets(top: 2, left: 4, bottom: 2, right: 4)
        static let cornerRadius: CGFloat = 6
        static let strokeWidth: CGFloat = 1
    }

    /// The diagnostic this overlay represents
    let diagnostic: SQLDiagnostic

    /// Called when the user clicks the glow to see error details
    var onActivate: ((SQLDiagnostic) -> Void)?

    private var trackingArea: NSTrackingArea?
    private var hostingView: NSHostingView<GlowFrameView>?
    private var isHovering = false {
        didSet { refreshRootView() }
    }

    init(diagnostic: SQLDiagnostic) {
        self.diagnostic = diagnostic
        super.init(frame: .zero)
        wantsLayer = false
        setupHostingView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(for textRect: NSRect) {
        let pad = Layout.padding
        let frame = NSRect(
            x: textRect.origin.x - pad.left,
            y: textRect.origin.y - pad.bottom,
            width: textRect.size.width + pad.left + pad.right,
            height: textRect.size.height + pad.top + pad.bottom
        ).integral
        if self.frame != frame {
            self.frame = frame
        }
        needsLayout = true
        isHovering = false
        refreshRootView()
        updateTrackingAreas()
    }

    override func layout() {
        super.layout()
        hostingView?.frame = bounds
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        NSCursor.pointingHand.push()
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        NSCursor.pop()
    }

    override func mouseDown(with event: NSEvent) {
        isHovering = true
        refreshRootView()
        onActivate?(diagnostic)
    }

    override func mouseUp(with event: NSEvent) {
        isHovering = false
    }

    override func removeFromSuperview() {
        super.removeFromSuperview()
        hostingView?.removeFromSuperview()
        hostingView = nil
    }

    private func setupHostingView() {
        let root = GlowFrameView(
            cornerRadius: Layout.cornerRadius,
            baseLineWidth: Layout.strokeWidth,
            isHovering: isHovering,
            palette: GlowFrameView.validationPalette,
            animationInterval: 1.2,
            transitionDuration: 1.0
        )
        let hosting = NSHostingView(rootView: root)
        hosting.translatesAutoresizingMaskIntoConstraints = true
        addSubview(hosting)
        hostingView = hosting
    }

    private func refreshRootView() {
        guard let hostingView else { return }
        hostingView.rootView = GlowFrameView(
            cornerRadius: Layout.cornerRadius,
            baseLineWidth: Layout.strokeWidth,
            isHovering: isHovering,
            palette: GlowFrameView.validationPalette,
            animationInterval: 1.2,
            transitionDuration: 1.0
        )
        hostingView.needsDisplay = true
    }
}

#endif
