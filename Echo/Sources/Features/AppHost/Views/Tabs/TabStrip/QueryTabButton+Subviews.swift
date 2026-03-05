import SwiftUI
#if os(macOS)
import AppKit
#endif

extension QueryTabButton {
    @ViewBuilder
    var tabBackground: some View {
#if os(macOS)
        if let gradient = macTabFillGradient {
            tabShape.fill(gradient)
        } else {
            tabShape.fill(Color.clear)
        }
#else
        tabShape.fill(tabFillGradient)
#endif
    }

    @ViewBuilder
    var tabStroke: some View {
#if os(macOS)
        if isDropTarget {
            tabShape.stroke(tabDropBorderColor, lineWidth: hairlineWidth)
        } else if let color = macTabBorderColor {
            tabShape.stroke(color, lineWidth: hairlineWidth)
        }
#else
        tabShape.stroke(isDropTarget ? tabDropBorderColor : tabBorderColor, lineWidth: hairlineWidth)
#endif
    }

    @ViewBuilder
    var hoverOutline: some View {
#if os(macOS)
        if shouldShowHoverOutline {
            tabShape
                .stroke(hoverHighlightColor, lineWidth: 1.1)
        }
#else
        tabShape
            .stroke(hoverHighlightColor, lineWidth: 1.1)
            .opacity(shouldShowHoverOutline ? 1 : 0)
#endif
    }

    var closeButtonArea: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(TypographyTokens.compact.weight(.semibold))
                .foregroundStyle(closeButtonForeground)
                .frame(width: closeButtonSize, height: closeButtonSize)
                .background(
                    Circle()
                        .fill(closeButtonBackground)
                )
        }
        .buttonStyle(.plain)
        .opacity(shouldShowClose ? 1 : 0)
        .allowsHitTesting(shouldShowClose)
        .contentShape(Circle())
#if os(macOS)
        .help("Close tab")
        .onHover { hovering in
            isHoveringClose = hovering
        }
#endif
        .frame(width: closeButtonSize, height: closeButtonSize, alignment: .leading)
    }

    var closeButtonPlaceholder: some View {
        let width: CGFloat
#if os(macOS)
        if tab.isPinned {
            width = 0
        } else {
            width = closeButtonSize
        }
#else
        width = closeButtonSize
#endif
        return Rectangle()
            .fill(Color.clear)
            .frame(width: width, height: closeButtonSize)
    }

    var closeButtonSize: CGFloat { 16 }

#if !os(macOS)
    var tabFillGradient: LinearGradient {
        LinearGradient(colors: [Color.white.opacity(0.75), Color.white.opacity(0.6)], startPoint: .top, endPoint: .bottom)
    }
#endif
}
