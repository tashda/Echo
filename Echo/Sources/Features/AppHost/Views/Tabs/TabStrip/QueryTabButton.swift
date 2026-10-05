import SwiftUI
#if os(macOS)
import AppKit
#endif

struct QueryTabButton: View {
    @Bindable var tab: WorkspaceTab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
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
    var availableDatabases: [String] = []
    var onSwitchDatabase: ((String) -> Void)?
    /// The width the tab is moving to; its title is laid out at that width at once (round 49, MO9).
    var finalWidth: CGFloat = 0
    /// The tool's pages are in the tab, not on the row under the strip (FP4).
    var pagesInTab = true
    /// Squeezed by the tool tab in front: only its icon shows (FP1).
    var isIconOnly = false
    /// Dragged: drawn above the other tabs with its own plate and icon (TABS-2.13).
    var isLifted = false

    @State var isHovering = false
    @State var isHoveringClose = false
    @State private var isPressed = false

    var shouldShowClose: Bool {
        guard !tab.isPinned else { return false }
#if os(macOS)
        return isHovering
#else
        return true
#endif
    }

#if os(macOS)
    @Environment(\.colorScheme) var colorScheme
#endif
    @Environment(\.echoMotion) var motion
    @Environment(EnvironmentState.self) var environmentState
    @Environment(AppState.self) var appState

    var tabCornerRadius: CGFloat { 15 }

    var tabShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: tabCornerRadius, style: .continuous)
    }

    var hairlineWidth: CGFloat { tabHairlineWidth() }

    var body: some View {
        // Laid over the tab rather than sizing it: a tab narrower than what it holds (a tool tab
        // behind another, or one still growing) keeps it at its leading edge and clips the rest,
        // instead of centring it under its icon.
        Color.clear
        .frame(maxWidth: .infinity, minHeight: WorkspaceChromeMetrics.tabHeight)
        .overlay(alignment: tab.isPinned ? .center : .leading) {
            contentRow
                .padding(.leading, tab.isPinned ? 13 : SpacingTokens.xs)
                .padding(.trailing, tab.isPinned ? 13 : SpacingTokens.sm)
                .padding(.vertical, SpacingTokens.xxxs)
                .opacity(isIconOnly ? 0 : 1)
                .animation(motion.pageFade, value: isIconOnly)
        }
        .overlay(alignment: .leading) { if isLifted { liftedIcon } }
        // An icon-only tab shows its close button in the icon's place while the pointer is on it.
        .overlay { if isIconOnly && shouldShowClose { closeButtonArea } }
        // Nothing the tab holds is wider than the tab while it moves (round 49, MO9).
        .clipShape(tabShape)
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
        // Selects on press rather than on release (round 9, TFIX), so the click counts at once;
        // the strip's drag still reorders. Pressing the close button doesn't select the tab.
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isPressed else { return }
                    isPressed = true
                    if !isHoveringClose { onSelect() }
                }
                .onEnded { _ in isPressed = false }
        )
        .contextMenu {
            tabContextMenuContent
        }
        .onChange(of: shouldShowClose) { _, visible in
            if !visible {
                isHoveringClose = false
            }
        }
    }

    /// Pinned tabs centre their letter; every other tab is left to right from a fixed inset, so
    /// what it says never slides inside it (MO9, anchored).
    @ViewBuilder
    private var contentRow: some View {
        if tab.isPinned {
            HStack(spacing: SpacingTokens.xxxs) {
                leadingControl
                tabTitleContent.frame(maxWidth: .infinity, alignment: .center)
                closeButtonPlaceholder
            }
        } else {
            HStack(spacing: SpacingTokens.xxxs) {
                // The × stays at the tab's leading edge (TABS-2.7); the icon and title are centred
                // from the width the tab is moving to, at once, so the words never slide (MO9).
                leadingControl
                tabTitleContent
                    .padding(.leading, centringLead)
                closeButtonPlaceholder
            }
            .fixedSize()
            .placedAtOnceWhenResized(width: finalWidth, isActive: isActive)
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


    var tabTitleFont: Font {
        if tab.isPinned {
            return TypographyTokens.detail.weight(.semibold)
        }
        return TypographyTokens.detail
    }

}
