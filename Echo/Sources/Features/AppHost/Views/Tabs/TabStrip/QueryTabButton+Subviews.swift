import SwiftUI
#if os(macOS)
import AppKit
#endif

extension QueryTabButton {
    @ViewBuilder
    var tabBackground: some View {
#if os(macOS)
        if isLifted {
            // A dragged tab hides the tabs it passes: the strip's own grey under it, then the
            // front tab's plate (or the hover fill), as Safari's tabs do (TABS-2.13).
            ZStack {
                tabShape.fill(ColorTokens.TabStrip.Background.plate)
                if isActive {
                    TabRaisedPlate()
                } else if let gradient = macTabFillGradient {
                    tabShape.fill(gradient)
                }
            }
        } else if let gradient = macTabFillGradient {
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

    /// The icon a dragged tab carries over the others, where the strip's layer draws it.
    @ViewBuilder
    var liftedIcon: some View {
        if !tab.isPinned {
            TabIconGlyph(symbol: tab.iconName, mark: tab.homeMark, isActive: isActive, isRunning: tab.query?.isExecuting == true)
                .padding(.leading, TabLabelLayout.iconInset(title: displayedTitle, width: finalWidth,
                                                            hasPages: showsPagesInTab, isIconOnly: isIconOnly))
                .opacity(isIconOnly && isHovering ? 0 : 1)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    var closeButtonArea: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(TypographyTokens.compact.weight(.bold))
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

    var closeButtonSize: CGFloat { SpacingTokens.sm2 }

#if !os(macOS)
    var tabFillGradient: LinearGradient {
        LinearGradient(colors: [Color.white.opacity(0.75), Color.white.opacity(0.6)], startPoint: .top, endPoint: .bottom)
    }
#endif
}
