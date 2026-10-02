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

            // The front tab's plate is the strip's (round 49, MO2): one shape that glides.
            if isActive { return nil }

            if shouldTreatAsHover {
                return appearance.hoverTabFill
            }

            return nil
        }
        if isDropTarget {
            return tabDropHighlightGradient
        }

        if isActive { return nil }

        if shouldTreatAsHover {
            return inactiveHoverGradient
        }

        return nil
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

            if isActive { return nil }

            if shouldTreatAsHover {
                return appearance.hoverTabBorder
            }

            return nil
        }
        if isDropTarget {
            return tabDropBorderColor
        }

        if isActive { return nil }

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
        // The plate carries the front tab's shadow.
        return Color.clear
#else
        return Color.black.opacity(isActive ? 0.2 : 0)
#endif
    }

    var tabShadowRadius: CGFloat { 0 }
    var tabShadowYOffset: CGFloat { 0 }
}
