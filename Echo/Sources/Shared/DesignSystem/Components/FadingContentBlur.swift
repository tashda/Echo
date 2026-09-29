import SwiftUI
import AppKit

/// Blurs the window content directly underneath (rows scrolling under a pinned header), fully
/// blurred at the top and fading to nothing at the bottom, with rounded top corners.
///
/// SwiftUI materials here mostly show their tint instead of blurring the rows, so this is an
/// in-window `NSVisualEffectView`. A visual effect view ignores layer masks, so its mask image
/// carries both the fade and the corners.
struct FadingContentBlur: NSViewRepresentable {
    var topCornerRadius: CGFloat
    /// The share of the height that stays fully blurred before the fade starts.
    var solidFraction: CGFloat

    func makeNSView(context: Context) -> FadingBlurEffectView {
        let view = FadingBlurEffectView()
        view.material = .contentBackground
        view.blendingMode = .withinWindow
        view.state = .active
        view.topCornerRadius = topCornerRadius
        view.solidFraction = solidFraction
        return view
    }

    func updateNSView(_ nsView: FadingBlurEffectView, context: Context) {
        nsView.topCornerRadius = topCornerRadius
        nsView.solidFraction = solidFraction
    }
}

final class FadingBlurEffectView: NSVisualEffectView {
    var topCornerRadius: CGFloat = 0 {
        didSet { if oldValue != topCornerRadius { invalidateMask() } }
    }
    var solidFraction: CGFloat = 0.5 {
        didSet { if oldValue != solidFraction { invalidateMask() } }
    }

    private var maskedSize: CGSize = .zero

    override func layout() {
        super.layout()
        guard bounds.size != maskedSize else { return }
        maskedSize = bounds.size
        maskImage = Self.makeMask(size: bounds.size, cornerRadius: topCornerRadius, solidFraction: solidFraction)
    }

    /// Decoration only: clicks go to the header above it or the rows below.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    private func invalidateMask() {
        maskedSize = .zero
        needsLayout = true
    }

    private static func makeMask(size: CGSize, cornerRadius: CGFloat, solidFraction: CGFloat) -> NSImage? {
        guard size.width > 0, size.height > 0 else { return nil }
        let fadeStart = min(max(solidFraction, 0), 1)
        return NSImage(size: size, flipped: true) { rect in
            let radius = min(cornerRadius, rect.width / 2, rect.height)
            // Taller than the image by the radius, so only the top corners are rounded.
            let shape = NSBezierPath(
                roundedRect: NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height + radius),
                xRadius: radius,
                yRadius: radius
            )
            let gradient = NSGradient(colorsAndLocations:
                (NSColor.black, 0),
                (NSColor.black, fadeStart),
                (NSColor.clear, 1)
            )
            // In a flipped image, 90° runs from the top edge down.
            gradient?.draw(in: shape, angle: 90)
            return true
        }
    }
}
