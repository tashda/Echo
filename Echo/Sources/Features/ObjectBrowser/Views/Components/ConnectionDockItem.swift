import AppKit
import SwiftUI

/// A compact connection switcher inside the dock's shared Liquid Glass surface.
/// Connection state is attached to the server icon so selection and status read
/// as a single object rather than unrelated decorations.
struct ConnectionDockItem<Trailing: View>: View {
    let databaseType: DatabaseType
    let title: String
    let helpText: String
    let stateDescription: String
    let isSelected: Bool
    let isColorful: Bool
    let iconTint: Color
    let statusColor: Color?
    let isStatusPulsing: Bool
    let density: SidebarDensity
    let contextMenuBuilder: () -> NSMenu
    @ViewBuilder let trailing: () -> Trailing
    let action: () -> Void

    @Environment(\.sidebarContextMenuActive) private var isContextMenuActive
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: SidebarRowConstants.iconTextSpacing) {
                databaseIcon

                Text(title)
                    .font(labelFont.weight(isSelected ? .semibold : .medium))
                    .foregroundStyle(ColorTokens.Text.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: SpacingTokens.xxxs)

                trailing()
            }
            .padding(.horizontal, SidebarRowConstants.rowLeadingPadding)
            .frame(height: itemHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(highlightFill)
            .contentShape(itemShape)
        }
        .buttonStyle(.plain)
        .help(helpText)
        .accessibilityLabel(title)
        .accessibilityValue(stateDescription)
        .onHover { isHovering = $0 }
        .focusable(false)
        .lazyContextMenu(contextMenuBuilder)
    }

    private var itemShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: isSelected
                ? LayoutTokens.ConnectionDock.cornerRadius
                : SidebarRowConstants.hoverCornerRadius,
            style: .continuous
        )
    }

    private var highlightFill: some View {
        itemShape.fill(backgroundColor)
    }

    private var backgroundColor: Color {
        if isSelected {
            return ColorTokens.Sidebar.selectedFill
        }
        if isContextMenuActive {
            return ColorTokens.Sidebar.contextFill
        }
        if isHovering {
            return ColorTokens.Sidebar.hoverFill
        }
        return .clear
    }

    private var databaseIcon: some View {
        DatabaseTypeIcon(
            databaseType: databaseType,
            tint: iconTint,
            isColorful: isColorful,
            presentation: .sidebar,
            glyphScale: 0.9
        )
        .frame(width: iconSize, height: iconSize)
        .overlay(alignment: .bottomTrailing) {
            if let statusColor {
                PulsingStatusDot(
                    tint: statusColor,
                    isPulsing: isStatusPulsing
                )
                .offset(x: SpacingTokens.xxxs, y: SpacingTokens.xxxs)
            }
        }
    }

    private var itemHeight: CGFloat {
        switch density {
        case .compact: return SpacingTokens.lg
        case .small: return SpacingTokens.lg + SpacingTokens.xxxs
        case .medium: return SpacingTokens.lg + SpacingTokens.xxs
        case .large: return SpacingTokens.xl
        }
    }

    private var iconSize: CGFloat {
        switch density {
        case .compact: return SpacingTokens.sm
        case .small: return SpacingTokens.sm2
        case .medium: return SpacingTokens.xs_plus
        case .large: return SpacingTokens.md1
        }
    }

    private var labelFont: Font {
        switch density {
        case .compact: return TypographyTokens.label
        case .small: return TypographyTokens.detail
        case .medium: return TypographyTokens.caption2
        case .large: return TypographyTokens.standard
        }
    }
}
