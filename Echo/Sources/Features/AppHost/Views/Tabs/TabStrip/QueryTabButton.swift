import SwiftUI
#if os(macOS)
import AppKit
#endif

struct QueryTabButton: View {
    @Bindable var tab: WorkspaceTab
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
    var availableDatabases: [String] = []
    var onSwitchDatabase: ((String) -> Void)?
    /// The width the tab is moving to; its title is laid out at that width at once (round 49, MO9).
    var finalWidth: CGFloat = 0
    /// The tool's pages are in the tab, not on the row under the strip (FP4).
    var pagesInTab = true
    /// Squeezed by the tool tab in front: only its icon shows (FP1).
    var isIconOnly = false

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
        contentRow
        .padding(.leading, tab.isPinned ? 13 : SpacingTokens.xs)
        .padding(.trailing, tab.isPinned ? 13 : SpacingTokens.sm)
        .padding(.vertical, SpacingTokens.xxxs)
        .frame(maxWidth: .infinity, minHeight: WorkspaceChromeMetrics.tabHeight, alignment: tab.isPinned ? .center : .leading)
        .opacity(isIconOnly ? 0 : 1)
        .animation(motion.pageFade, value: isIconOnly)
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

    private var tabContextMenuContent: some View {
        Group {
            Button(action: onPinToggle) {
                Label(tab.isPinned ? "Unpin Tab" : "Pin Tab", systemImage: tab.isPinned ? "pin.slash" : "pin")
            }

            Button(action: onDuplicate) {
                Label("Duplicate Tab", systemImage: "plus.square.on.square")
            }
            .disabled(!canDuplicate)

            if !availableDatabases.isEmpty, let onSwitchDatabase {
                Divider()
                Menu {
                    ForEach(availableDatabases, id: \.self) { dbName in
                        Button {
                            onSwitchDatabase(dbName)
                        } label: {
                            if dbName == tab.activeDatabaseName {
                                Label(dbName, systemImage: "checkmark")
                            } else {
                                Text(dbName)
                            }
                        }
                    }
                } label: {
                    Label("Switch Database", systemImage: "cylinder")
                }
            }

            Divider()

            Button(action: onClose) {
                Label("Close Tab", systemImage: "xmark")
            }

            Button(action: onCloseOthers) {
                Label("Close Other Tabs", systemImage: "xmark.square")
            }
            .disabled(closeOthersDisabled)

            Button(action: onCloseLeft) {
                Label("Close Tabs to the Left", systemImage: "arrow.left.to.line")
            }
            .disabled(closeTabsLeftDisabled)

            Button(action: onCloseRight) {
                Label("Close Tabs to the Right", systemImage: "arrow.right.to.line")
            }
            .disabled(closeTabsRightDisabled)

            if tab.query != nil {
                Divider()
                homeMenuContent
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
                leadingControl
                tabTitleContent
                closeButtonPlaceholder
            }
            .fixedSize()
            // Centred from the width the tab is moving to, at once, so the words never slide (MO9).
            .padding(.leading, centringLead)
            .transaction { $0.animation = nil }
        }
    }

    /// How far a tab without pages moves its icon and title in from the fixed inset to centre them.
    var centringLead: CGFloat {
        guard !isIconOnly, !hasToolPages else { return 0 }
        return TabLabelLayout.iconInset(title: displayedTitle, width: finalWidth, hasPages: false, isIconOnly: false)
            - LayoutTokens.TabPages.iconInset
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
