import SwiftUI
#if os(macOS)
import AppKit
#endif

extension QueryTabButton {
#if os(macOS)
    var macTabFillGradient: LinearGradient? {
        if let appearance {
            if isDropTarget {
                return appearance.dropTabFill
            }

            if isActive {
                return effectiveHovering ? appearance.activeTabHoverFill : appearance.activeTabFill
            }

            if shouldTreatAsHover {
                return appearance.hoverTabFill
            }

            return nil
        }
        if isDropTarget {
            return tabDropHighlightGradient
        }

        if isActive {
            return effectiveHovering ? activeHoverGradient : activeIdleGradient
        }

        if shouldTreatAsHover {
            return inactiveHoverGradient
        }

        return nil
    }

    var activeIdleGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(colors: [
                ColorTokens.TabStrip.ActiveTab.Dark.top,
                ColorTokens.TabStrip.ActiveTab.Dark.bottom
            ], startPoint: .top, endPoint: .bottom)
        }
        return LinearGradient(colors: [
            ColorTokens.TabStrip.ActiveTab.Light.top,
            ColorTokens.TabStrip.ActiveTab.Light.bottom
        ], startPoint: .top, endPoint: .bottom)
    }

    var activeHoverGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(colors: [
                ColorTokens.TabStrip.ActiveTab.Dark.hoverTop,
                ColorTokens.TabStrip.ActiveTab.Dark.hoverBottom
            ], startPoint: .top, endPoint: .bottom)
        }
        return LinearGradient(colors: [
            ColorTokens.TabStrip.ActiveTab.Light.hoverTop,
            ColorTokens.TabStrip.ActiveTab.Light.hoverBottom
        ], startPoint: .top, endPoint: .bottom)
    }

    var inactiveHoverGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(colors: [
                ColorTokens.TabStrip.InactiveHover.Dark.top,
                ColorTokens.TabStrip.InactiveHover.Dark.bottom
            ], startPoint: .top, endPoint: .bottom)
        }
        return LinearGradient(colors: [
            ColorTokens.TabStrip.InactiveHover.Light.top,
            ColorTokens.TabStrip.InactiveHover.Light.bottom
        ], startPoint: .top, endPoint: .bottom)
    }

    var macTabBorderColor: Color? {
        if let appearance {
            if isDropTarget {
                return appearance.dropTabBorder
            }

            if isActive {
                return effectiveHovering ? appearance.activeTabHoverBorder : appearance.activeTabBorder
            }

            if shouldTreatAsHover {
                return appearance.hoverTabBorder
            }

            return nil
        }
        if isDropTarget {
            return tabDropBorderColor
        }

        if isActive {
            return colorScheme == .dark ? ColorTokens.TabStrip.Border.activeDark : ColorTokens.TabStrip.Border.activeLight
        }

        if shouldTreatAsHover {
            return colorScheme == .dark ? ColorTokens.TabStrip.Border.hoverDark : ColorTokens.TabStrip.Border.hoverLight
        }

        return nil
    }

    var effectiveHovering: Bool {
        isHovering || isBeingDragged
    }

    var shouldTreatAsHover: Bool {
        !isActive && effectiveHovering && !isDropTarget
    }
#endif

    var tabDropHighlightGradient: LinearGradient {
#if os(macOS)
        if let appearance {
            return appearance.dropTabFill
        }
        if colorScheme == .dark {
            return LinearGradient(colors: [ColorTokens.TabStrip.DropTarget.Dark.top, ColorTokens.TabStrip.DropTarget.Dark.bottom], startPoint: .top, endPoint: .bottom)
        } else {
            return LinearGradient(colors: [ColorTokens.TabStrip.DropTarget.Light.top, ColorTokens.TabStrip.DropTarget.Light.bottom], startPoint: .top, endPoint: .bottom)
        }
#else
        LinearGradient(colors: [ColorTokens.accent.opacity(0.4), ColorTokens.accent.opacity(0.28)], startPoint: .top, endPoint: .bottom)
#endif
    }

    var tabBorderColor: Color {
#if os(macOS)
        Color.clear
#else
        return ColorTokens.TabStrip.Border.inactive
#endif
    }

    var tabDropBorderColor: Color {
#if os(macOS)
        if let appearance {
            return appearance.dropTabBorder
        }
        if colorScheme == .dark {
            return ColorTokens.TabStrip.Border.dropDark
        } else {
            return ColorTokens.TabStrip.Border.dropLight
        }
#else
        return ColorTokens.accent.opacity(0.6)
#endif
    }

    var hoverHighlightColor: Color {
#if os(macOS)
        if let appearance {
            return appearance.hoverTabBorder
        }
        return colorScheme == .dark ? ColorTokens.TabStrip.Highlight.dark : ColorTokens.TabStrip.Highlight.light
#else
        return ColorTokens.TabStrip.Highlight.light
#endif
    }

    var shouldShowHoverOutline: Bool {
#if os(macOS)
        false
#else
        return false
#endif
    }

    var tabShadowColor: Color {
#if os(macOS)
        if let appearance {
            return isActive ? appearance.shadowColor : Color.clear
        }

        if !isActive { return Color.clear }
        return colorScheme == .dark ? ColorTokens.TabStrip.Shadow.dark : ColorTokens.TabStrip.Shadow.light
#else
        return Color.black.opacity(isActive ? 0.2 : 0)
#endif
    }

    var tabShadowRadius: CGFloat { isActive ? 2.5 : 0 }
    var tabShadowYOffset: CGFloat { isActive ? 1.2 : 0 }
}
