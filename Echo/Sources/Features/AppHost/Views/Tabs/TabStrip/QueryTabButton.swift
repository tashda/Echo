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

    @State var isHovering = false
    @State var isHoveringClose = false

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

    var tabCornerRadius: CGFloat { 15 }

    var tabShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: tabCornerRadius, style: .continuous)
    }

    var hairlineWidth: CGFloat { tabHairlineWidth() }

    var body: some View {
        HStack(spacing: SpacingTokens.xxxs) {
            leadingControl

            tabTitleContent
                .frame(maxWidth: .infinity, alignment: .center)

            closeButtonPlaceholder
        }
        .padding(.leading, tab.isPinned ? 13 : SpacingTokens.xs)
        .padding(.trailing, tab.isPinned ? 13 : SpacingTokens.sm)
        .padding(.vertical, SpacingTokens.xxxs)
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

            if let onAddBookmark {
                Divider()
                Button(action: onAddBookmark) {
                    Label("Add to Bookmarks", systemImage: "bookmark")
                }
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

    @ViewBuilder
    private var tabTitleContent: some View {
        if tab.isPinned {
            Text(displayedTitle)
                .font(tabTitleFont)
                .lineLimit(1)
                .foregroundStyle(tabTitleColor)
        } else if let dbName = tab.tabSubtitle ?? tab.activeDatabaseName, !dbName.isEmpty {
            HStack(spacing: SpacingTokens.xxxs) {
                Text(displayedTitle)
                    .font(tabTitleFont)
                    .lineLimit(1)
                    .foregroundStyle(tabTitleColor)

                Text(dbName)
                    .font(TypographyTokens.detail.weight(.medium))
                    .lineLimit(1)
                    .foregroundStyle(tabTitleColor.opacity(0.55))
            }
        } else {
            Text(displayedTitle)
                .font(tabTitleFont)
                .lineLimit(1)
                .foregroundStyle(tabTitleColor)
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
            return TypographyTokens.detail.weight(.semibold)
        }
        return TypographyTokens.detail
    }

}
