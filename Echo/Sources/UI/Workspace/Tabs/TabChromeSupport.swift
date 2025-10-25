import SwiftUI
import EchoSense
#if os(macOS)
import AppKit
#endif

#if os(macOS)
struct TabChromePalette {
    let baseFill: LinearGradient
    let baseStroke: Color
    let baseShadow: Color
    let activeTabFill: LinearGradient
    let activeTabHoverFill: LinearGradient
    let inactiveTabFill: LinearGradient
    let hoverTabFill: LinearGradient
    let dropTabFill: LinearGradient
    let activeTabBorder: Color
    let activeTabHoverBorder: Color
    let hoverTabBorder: Color
    let inactiveTabBorder: Color
    let dropTabBorder: Color
    let activeTitle: Color
    let inactiveTitle: Color
    let activeIcon: Color
    let inactiveIcon: Color
    let closeForeground: Color
    let closeHoverForeground: Color
    let closeHoverBackground: Color
    let shadowColor: Color
    let actionButtonFill: LinearGradient
    let actionButtonFillHover: LinearGradient
    let actionButtonFillInactive: LinearGradient
    let actionButtonBorder: Color
    let actionButtonIcon: Color
    let separatorGradient: LinearGradient

    init(theme: AppColorTheme, accent: NSColor, fallbackScheme: ColorScheme) {
        _ = fallbackScheme
        let baseBackground = theme.surfaceBackground.nsColor.usingColorSpace(.deviceRGB) ?? theme.surfaceBackground.nsColor
        let selection = theme.editorSelection.nsColor.usingColorSpace(.deviceRGB) ?? theme.editorSelection.nsColor
        let textColor = theme.surfaceForeground.nsColor.usingColorSpace(.deviceRGB) ?? theme.surfaceForeground.nsColor
        let accentColor = (theme.accent?.nsColor ?? accent).usingColorSpace(.deviceRGB) ?? accent
        let toneIsDark = theme.tone == .dark

        let neutralBase = blend(baseBackground, with: toneIsDark ? .black : .white, amount: toneIsDark ? 0.05 : 0.04)
        let baseTop = lighten(neutralBase, by: toneIsDark ? 0.02 : 0.03)
        let baseBottom = darken(neutralBase, by: toneIsDark ? 0.06 : 0.05)
        baseFill = LinearGradient(colors: [Color(nsColor: baseTop), Color(nsColor: baseBottom)], startPoint: .top, endPoint: .bottom)
        let baseStrokeColor = darken(neutralBase, by: toneIsDark ? 0.14 : 0.10).withAlphaComponent(toneIsDark ? 0.45 : 0.26)
        baseStroke = Color(nsColor: baseStrokeColor)
        baseShadow = toneIsDark ? Color.black.opacity(0.28) : Color.black.opacity(0.08)

        let softenedAccent = blend(accentColor, with: baseBackground, amount: toneIsDark ? 0.68 : 0.72)
        let activeTop = lighten(softenedAccent, by: toneIsDark ? 0.05 : 0.08)
        let activeBottom = darken(softenedAccent, by: toneIsDark ? 0.10 : 0.12)
        activeTabFill = LinearGradient(colors: [Color(nsColor: activeTop), Color(nsColor: activeBottom)], startPoint: .top, endPoint: .bottom)

        let activeHoverTop = lighten(softenedAccent, by: toneIsDark ? 0.08 : 0.11)
        let activeHoverBottom = darken(softenedAccent, by: toneIsDark ? 0.08 : 0.10)
        activeTabHoverFill = LinearGradient(colors: [Color(nsColor: activeHoverTop), Color(nsColor: activeHoverBottom)], startPoint: .top, endPoint: .bottom)

        let inactiveTop = lighten(baseBackground, by: toneIsDark ? 0.05 : 0.04)
        let inactiveBottom = darken(baseBackground, by: toneIsDark ? 0.08 : 0.05)
        inactiveTabFill = LinearGradient(colors: [Color(nsColor: inactiveTop), Color(nsColor: inactiveBottom)], startPoint: .top, endPoint: .bottom)

        let softenedSelection = blend(selection, with: baseBackground, amount: toneIsDark ? 0.6 : 0.7)
        let hoverTop = lighten(softenedSelection, by: toneIsDark ? 0.06 : 0.08)
        let hoverBottom = darken(softenedSelection, by: toneIsDark ? 0.08 : 0.09)
        hoverTabFill = LinearGradient(colors: [Color(nsColor: hoverTop), Color(nsColor: hoverBottom)], startPoint: .top, endPoint: .bottom)

        let dropAccent = blend(accentColor, with: softenedAccent, amount: 0.25)
        let dropTop = lighten(dropAccent, by: toneIsDark ? 0.12 : 0.16)
        let dropBottom = darken(dropAccent, by: toneIsDark ? 0.18 : 0.20)
        dropTabFill = LinearGradient(colors: [Color(nsColor: dropTop), Color(nsColor: dropBottom)], startPoint: .top, endPoint: .bottom)

        let activeBorderColor = darken(softenedAccent, by: toneIsDark ? 0.14 : 0.12).withAlphaComponent(toneIsDark ? 0.55 : 0.48)
        activeTabBorder = Color(nsColor: activeBorderColor)
        let activeHoverBorderColor = darken(softenedAccent, by: toneIsDark ? 0.10 : 0.10).withAlphaComponent(toneIsDark ? 0.65 : 0.55)
        activeTabHoverBorder = Color(nsColor: activeHoverBorderColor)
        let hoverBorderColor = darken(softenedSelection, by: toneIsDark ? 0.10 : 0.08).withAlphaComponent(toneIsDark ? 0.55 : 0.38)
        hoverTabBorder = Color(nsColor: hoverBorderColor)
        inactiveTabBorder = Color.clear
        let dropBorderColor = darken(dropAccent, by: toneIsDark ? 0.22 : 0.24).withAlphaComponent(toneIsDark ? 1.0 : 0.92)
        dropTabBorder = Color(nsColor: dropBorderColor)

        let titleActive = lighten(textColor, by: toneIsDark ? 0.12 : -0.05)
        let titleInactive = lighten(textColor, by: toneIsDark ? 0.24 : 0.18)
        activeTitle = Color(nsColor: titleActive)
        inactiveTitle = Color(nsColor: titleInactive)
        activeIcon = activeTitle
        inactiveIcon = inactiveTitle.opacity(0.9)

        let closeBase = blend(textColor, with: baseBackground, amount: 0.35)
        closeForeground = Color(nsColor: closeBase)
        closeHoverForeground = Color(nsColor: lighten(closeBase, by: toneIsDark ? 0.12 : 0.18))
        closeHoverBackground = Color(nsColor: blend(selection, with: baseBackground, amount: toneIsDark ? 0.4 : 0.6)).opacity(0.6)
        shadowColor = toneIsDark ? Color.black.opacity(0.4) : Color.black.opacity(0.18)

        let actionBase = blend(baseBackground, with: accentColor, amount: toneIsDark ? 0.18 : 0.12)
        actionButtonFill = LinearGradient(colors: [
            Color(nsColor: lighten(actionBase, by: toneIsDark ? 0.06 : 0.08)),
            Color(nsColor: darken(actionBase, by: toneIsDark ? 0.08 : 0.06))
        ], startPoint: .top, endPoint: .bottom)
        actionButtonFillHover = LinearGradient(colors: [
            Color(nsColor: lighten(actionBase, by: toneIsDark ? 0.10 : 0.12)),
            Color(nsColor: darken(actionBase, by: toneIsDark ? 0.12 : 0.10))
        ], startPoint: .top, endPoint: .bottom)
        actionButtonFillInactive = LinearGradient(colors: [
            Color(nsColor: lighten(baseBackground, by: toneIsDark ? 0.04 : 0.02)),
            Color(nsColor: darken(baseBackground, by: toneIsDark ? 0.04 : 0.03))
        ], startPoint: .top, endPoint: .bottom)
        actionButtonBorder = Color(nsColor: darken(actionBase, by: toneIsDark ? 0.18 : 0.14)).opacity(toneIsDark ? 0.75 : 0.45)
        actionButtonIcon = Color(nsColor: lighten(textColor, by: toneIsDark ? 0.22 : 0.12))

        let separatorTop = lighten(baseBackground, by: toneIsDark ? 0.12 : 0.04)
        let separatorBottom = darken(baseBackground, by: toneIsDark ? 0.18 : 0.10)
        separatorGradient = LinearGradient(
            colors: [
                Color(nsColor: separatorTop).opacity(toneIsDark ? 0.55 : 0.62),
                Color(nsColor: separatorBottom).opacity(toneIsDark ? 0.72 : 0.74)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private func clamp(_ value: CGFloat) -> CGFloat { min(max(value, 0), 1) }

private func lighten(_ color: NSColor, by amount: CGFloat) -> NSColor {
    let rgb = color.usingColorSpace(.deviceRGB) ?? color
    return NSColor(red: clamp(rgb.redComponent + amount),
                   green: clamp(rgb.greenComponent + amount),
                   blue: clamp(rgb.blueComponent + amount),
                   alpha: rgb.alphaComponent)
}

private func darken(_ color: NSColor, by amount: CGFloat) -> NSColor {
    let rgb = color.usingColorSpace(.deviceRGB) ?? color
    return NSColor(red: clamp(rgb.redComponent - amount),
                   green: clamp(rgb.greenComponent - amount),
                   blue: clamp(rgb.blueComponent - amount),
                   alpha: rgb.alphaComponent)
}

private func blend(_ color: NSColor, with other: NSColor, amount: CGFloat) -> NSColor {
    let t = clamp(amount)
    let rgb1 = color.usingColorSpace(.deviceRGB) ?? color
    let rgb2 = other.usingColorSpace(.deviceRGB) ?? other
    return NSColor(
        red: rgb1.redComponent * (1 - t) + rgb2.redComponent * t,
        green: rgb1.greenComponent * (1 - t) + rgb2.greenComponent * t,
        blue: rgb1.blueComponent * (1 - t) + rgb2.blueComponent * t,
        alpha: rgb1.alphaComponent * (1 - t) + rgb2.alphaComponent * t
    )
}

struct TabStripBackground: View {
    enum Style {
        case standard(ColorScheme)
        case themed(TabChromePalette)
    }

    var style: Style
    var height: CGFloat = 24
    var cornerRadius: CGFloat = 15

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        shape
            .fill(baseFill)
            .overlay(topEdgeOverlay)
            .overlay(bottomEdgeOverlay)
            .frame(height: height)
            .allowsHitTesting(false)
    }

    private var baseFill: AnyShapeStyle {
        switch style {
        case .standard(let scheme):
            let color = scheme == .dark ? Color(white: 0.22) : Color(white: 0.90)
            return AnyShapeStyle(color)
        case .themed(let palette):
            return AnyShapeStyle(palette.baseFill)
        }
    }

    @ViewBuilder
    private var topEdgeOverlay: some View {
        if case .themed(let palette) = style {
            shape.stroke(palette.baseStroke, lineWidth: tabHairlineWidth())
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var bottomEdgeOverlay: some View {
        EmptyView()
    }
}

struct SafariTabBarBackground: View {
    var body: some View {
        LinearGradient(colors: [Color.white.opacity(0.16), Color.black.opacity(0.14)], startPoint: .top, endPoint: .bottom)
            .allowsHitTesting(false)
    }
}

struct SafariTabBarTopEdge: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.45))
            .frame(height: tabHairlineWidth())
    }
}

private struct MiddleClickGestureModifier: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content.background(MiddleClickCapture(onMiddleClick: action))
    }
}

private struct MiddleClickCapture: NSViewRepresentable {
    let onMiddleClick: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onMiddleClick: onMiddleClick)
    }

    func makeNSView(context: Context) -> MiddleClickReceiverView {
        let view = MiddleClickReceiverView()
        view.onSuperviewChanged = { superview in
            if let superview {
                context.coordinator.attach(to: superview)
            } else {
                context.coordinator.detach()
            }
        }
        return view
    }

    func updateNSView(_ nsView: MiddleClickReceiverView, context: Context) {
        context.coordinator.onMiddleClick = onMiddleClick
        if let superview = nsView.superview {
            context.coordinator.attach(to: superview)
        } else {
            context.coordinator.detach()
        }
    }

    @MainActor
    final class Coordinator {
        var onMiddleClick: () -> Void
        private weak var attachedView: NSView?
        private nonisolated(unsafe) var monitor: Any?

        init(onMiddleClick: @escaping () -> Void) {
            self.onMiddleClick = onMiddleClick
        }

        func attach(to view: NSView) {
            guard attachedView !== view else { return }
            detach()
            attachedView = view
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.otherMouseUp]) { [weak self] event in
                guard let self,
                      let attachedView = self.attachedView,
                      event.window === attachedView.window else {
                    return event
                }

                let location = attachedView.convert(event.locationInWindow, from: nil)
                if attachedView.bounds.contains(location) {
                    self.onMiddleClick()
                    return nil
                }

                return event
            }
        }

        func detach() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
            attachedView = nil
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}

private final class MiddleClickReceiverView: NSView {
    var onSuperviewChanged: ((NSView?) -> Void)?

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        onSuperviewChanged?(superview)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

extension View {
    func onMiddleClick(perform action: @escaping () -> Void) -> some View {
        modifier(MiddleClickGestureModifier(action: action))
    }
}
#else
struct TabChromePalette {}

struct TabStripBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
            .fill(Color(white: 0.92))
            .allowsHitTesting(false)
    }
}

struct SafariTabBarBackground: View {
    var body: some View { Color.clear }
}

struct SafariTabBarTopEdge: View {
    var body: some View { Color.clear.frame(height: 0) }
}

extension View {
    func onMiddleClick(perform action: @escaping () -> Void) -> some View {
        self
    }
}
#endif
