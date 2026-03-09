import SwiftUI
#if os(macOS)
import AppKit
#endif

extension QueryTabButton {
    var tabTitleColor: Color {
#if os(macOS)
        if isDropTarget {
            return Color.white
        }
        if let appearance {
            return isActive ? appearance.activeTitle : appearance.inactiveTitle
        }
        if tab.isPinned {
            return Color(nsColor: isActive ? .labelColor : .secondaryLabelColor.withAlphaComponent(0.75))
        }
        return Color(nsColor: isActive ? .labelColor : .secondaryLabelColor)
#else
        if isDropTarget {
            return .white
        }
        return isActive ? .primary : .secondary
#endif
    }

    var closeButtonForeground: Color {
#if os(macOS)
        if let appearance {
            if isDropTarget { return Color.white }
            if isHoveringClose { return appearance.closeHoverForeground }
            if isActive { return appearance.closeForeground }
            return appearance.closeForeground.opacity(0.85)
        }
        if isDropTarget { return Color.white }
        if isHoveringClose {
            return Color(nsColor: .labelColor)
        }
        if isActive {
            return Color(nsColor: .secondaryLabelColor)
        }
        return Color(nsColor: .tertiaryLabelColor)
#else
        return .secondary
#endif
    }

    var closeButtonBackground: Color {
#if os(macOS)
        if let appearance, shouldShowClose, isHoveringClose {
            return appearance.closeHoverBackground
        }
        guard shouldShowClose, isHoveringClose else { return Color.clear }
        if colorScheme == .dark {
            return Color.white.opacity(0.18)
        } else {
            return Color.black.opacity(0.08)
        }
#else
        return Color.black.opacity(0.12)
#endif
    }
}
