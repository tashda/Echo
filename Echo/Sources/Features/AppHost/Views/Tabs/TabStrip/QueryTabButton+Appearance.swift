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
                Color.white.opacity(0.26),
                Color.white.opacity(0.18)
            ], startPoint: .top, endPoint: .bottom)
        }
        return LinearGradient(colors: [
            Color(white: 0.99),
            Color(white: 0.95)
        ], startPoint: .top, endPoint: .bottom)
    }

    var activeHoverGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(colors: [
                Color.white.opacity(0.32),
                Color.white.opacity(0.24)
            ], startPoint: .top, endPoint: .bottom)
        }
        return LinearGradient(colors: [
            Color(white: 1.0),
            Color(white: 0.97)
        ], startPoint: .top, endPoint: .bottom)
    }

    var inactiveHoverGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(colors: [
                Color.white.opacity(0.18),
                Color.white.opacity(0.12)
            ], startPoint: .top, endPoint: .bottom)
        }
        return LinearGradient(colors: [
            Color(white: 0.94),
            Color(white: 0.90)
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
            return colorScheme == .dark ? Color.white.opacity(0.30) : Color(white: 0.86)
        }

        if shouldTreatAsHover {
            return colorScheme == .dark ? Color.white.opacity(0.22) : Color.white.opacity(0.68)
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
            return LinearGradient(colors: [Color.white.opacity(0.24), Color.white.opacity(0.18)], startPoint: .top, endPoint: .bottom)
        } else {
            return LinearGradient(colors: [Color(white: 0.90), Color(white: 0.86)], startPoint: .top, endPoint: .bottom)
        }
#else
        LinearGradient(colors: [Color.accentColor.opacity(0.4), Color.accentColor.opacity(0.28)], startPoint: .top, endPoint: .bottom)
#endif
    }

    var tabBorderColor: Color {
#if os(macOS)
        Color.clear
#else
        return Color.black.opacity(0.1)
#endif
    }

    var tabDropBorderColor: Color {
#if os(macOS)
        if let appearance {
            return appearance.dropTabBorder
        }
        if colorScheme == .dark {
            return Color.white.opacity(0.15)
        } else {
            return Color.black.opacity(0.05)
        }
#else
        return Color.accentColor.opacity(0.6)
#endif
    }

    var hoverHighlightColor: Color {
#if os(macOS)
        if let appearance {
            return appearance.hoverTabBorder
        }
        return colorScheme == .dark ? Color.white.opacity(0.38) : Color.white.opacity(0.55)
#else
        return Color.white.opacity(0.4)
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
        return colorScheme == .dark ? Color.black.opacity(0.28) : Color.black.opacity(0.10)
#else
        return Color.black.opacity(isActive ? 0.2 : 0)
#endif
    }

    var tabShadowRadius: CGFloat { isActive ? 2.5 : 0 }
    var tabShadowYOffset: CGFloat { isActive ? 1.2 : 0 }
}
