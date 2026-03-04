import SwiftUI
#if os(macOS)
import AppKit
#endif

struct QueryTabButton: View {
    @ObservedObject var tab: WorkspaceTab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let onAddBookmark: (() -> Void)?
    let onPinToggle: () -> Void
    let onDuplicate: () -> Void
    let onCloseOthers: () -> Void
    let onCloseLeft: () -> Void
    let onCloseRight: () -> Void
    let canDuplicate: Bool
    let closeOthersDisabled: Bool
    let closeTabsLeftDisabled: Bool
    let closeTabsRightDisabled: Bool
    let isDropTarget: Bool
    let isBeingDragged: Bool
    let appearance: TabChromePalette?
    let onHoverChanged: (Bool) -> Void

    @State private var isHovering = false
    @State private var isHoveringClose = false

    private var shouldShowClose: Bool {
        guard !tab.isPinned else { return false }
#if os(macOS)
        return isHovering
#else
        return true
#endif
    }

#if os(macOS)
    @Environment(\.colorScheme) private var colorScheme
#endif

    private var tabCornerRadius: CGFloat { 15 }

    private var tabShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: tabCornerRadius, style: .continuous)
    }

    private var hairlineWidth: CGFloat { tabHairlineWidth() }

    var body: some View {
        HStack(spacing: 3) {
            leadingControl

            Text(displayedTitle)
                .font(tabTitleFont)
                .lineLimit(1)
                .foregroundStyle(tabTitleColor)
                .frame(maxWidth: .infinity, alignment: .center)

            closeButtonPlaceholder
        }
        .padding(.horizontal, tab.isPinned ? 13 : 18)
        .padding(.vertical, 3)
        .frame(minHeight: 24)
        .background(tabBackground)
        .overlay(tabStroke)
        .overlay(hoverOutline)
        .shadow(color: tabShadowColor, radius: tabShadowRadius, y: tabShadowYOffset)
        .contentShape(tabShape)
#if os(macOS)
        .onHover { hovering in
            isHovering = hovering
            if !hovering { isHoveringClose = false }
            onHoverChanged(hovering)
        }
        .onMiddleClick(perform: onClose)
#endif
        .onTapGesture {
            onSelect()
        }
        .contextMenu {
            Button(tab.isPinned ? "Unpin Tab" : "Pin Tab", action: onPinToggle)

            Button("Duplicate Tab", action: onDuplicate)
                .disabled(!canDuplicate)

            Divider()

            Button("Close Tab", action: onClose)

            Button("Close Other Tabs", action: onCloseOthers)
                .disabled(closeOthersDisabled)

            Button("Close Tabs to the Left", action: onCloseLeft)
                .disabled(closeTabsLeftDisabled)

            Button("Close Tabs to the Right", action: onCloseRight)
                .disabled(closeTabsRightDisabled)

            if let onAddBookmark {
                Divider()
                Button("Add to Bookmarks", action: onAddBookmark)
            }
        }
        .onChange(of: shouldShowClose) { _, visible in
            if !visible {
                isHoveringClose = false
            }
        }
    }

    private var leadingControl: some View {
        Group {
            if tab.isPinned {
                closeButtonPlaceholder
            } else {
                closeButtonArea
            }
        }
    }

    private var displayedTitle: String {
        let trimmed = tab.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if tab.isPinned {
            if let first = trimmed.first {
                return String(first).uppercased()
            }
            return "•"
        }
        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    private var tabTitleFont: Font {
        if tab.isPinned {
            return .system(size: 11, weight: .semibold)
        }
        return .system(size: 11)
    }

    @ViewBuilder
    private var tabBackground: some View {
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
    private var tabStroke: some View {
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
    private var hoverOutline: some View {
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

#if os(macOS)
    private var macTabFillGradient: LinearGradient? {
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

    private var activeIdleGradient: LinearGradient {
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

    private var activeHoverGradient: LinearGradient {
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

    private var inactiveHoverGradient: LinearGradient {
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

    private var macTabBorderColor: Color? {
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

    private var effectiveHovering: Bool {
        isHovering || isBeingDragged
    }

    private var shouldTreatAsHover: Bool {
        !isActive && effectiveHovering && !isDropTarget
    }
#else
    private var tabFillGradient: LinearGradient {
        LinearGradient(colors: [Color.white.opacity(0.75), Color.white.opacity(0.6)], startPoint: .top, endPoint: .bottom)
    }
#endif

    private var tabDropHighlightGradient: LinearGradient {
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

    private var tabBorderColor: Color {
#if os(macOS)
        Color.clear
#else
        return Color.black.opacity(0.1)
#endif
    }

    private var tabDropBorderColor: Color {
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

    private var hoverHighlightColor: Color {
#if os(macOS)
        if let appearance {
            return appearance.hoverTabBorder
        }
        return colorScheme == .dark ? Color.white.opacity(0.38) : Color.white.opacity(0.55)
#else
        return Color.white.opacity(0.4)
#endif
    }

    private var shouldShowHoverOutline: Bool {
#if os(macOS)
        false
#else
        return false
#endif
    }

    private var tabShadowColor: Color {
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

    private var tabShadowRadius: CGFloat { isActive ? 2.5 : 0 }
    private var tabShadowYOffset: CGFloat { isActive ? 1.2 : 0 }

    private var tabTitleColor: Color {
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

    private var closeButtonForeground: Color {
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

    private var closeButtonBackground: Color {
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

    private var closeButtonArea: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .semibold))
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

    private var closeButtonPlaceholder: some View {
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

    private var closeButtonSize: CGFloat { 16 }
}


