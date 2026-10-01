import SwiftUI

/// Universal sidebar row matching macOS Finder sidebar aesthetics.
/// All sidebar items use this single component. The `depth` parameter controls
/// indentation, and `isExpanded` controls the disclosure chevron.
/// The selection highlight only covers the content area (from icon to trailing
/// edge), not the indentation space — matching Finder behavior where deeper items
/// have narrower highlights. When selected, the icon turns accent blue.
struct SidebarRow<Trailing: View>: View {

    enum Icon {
        case system(String)
        case asset(String)
        case none
    }

    let depth: Int
    let icon: Icon
    let label: String
    /// Optional pre-built `Text` that overrides the default `Text(label)`
    /// rendering — used for namespace dimming ("Schema." in tertiary +
    /// "name" in primary) without bypassing the row's typography.
    var labelText: Text? = nil
    var subtitle: String? = nil
    var isExpanded: Binding<Bool>? = nil
    var isSelected: Bool = false
    var iconColor: Color = ColorTokens.Sidebar.symbol
    var labelColor: Color = ColorTokens.Text.primary
    var labelFont: Font = SidebarRowConstants.labelFont
    var accentColor: Color = ColorTokens.accent
    var count: Int? = nil
    @ViewBuilder var trailing: () -> Trailing

    init(
        depth: Int,
        icon: Icon,
        label: String,
        labelText: Text? = nil,
        subtitle: String? = nil,
        isExpanded: Binding<Bool>? = nil,
        isSelected: Bool = false,
        iconColor: Color = ColorTokens.Sidebar.symbol,
        labelColor: Color = ColorTokens.Text.primary,
        labelFont: Font = SidebarRowConstants.labelFont,
        accentColor: Color = ColorTokens.accent,
        count: Int? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.depth = depth
        self.icon = icon
        self.label = label
        self.labelText = labelText
        self.subtitle = subtitle
        self.isExpanded = isExpanded
        self.isSelected = isSelected
        self.iconColor = iconColor
        self.labelColor = labelColor
        self.labelFont = labelFont
        self.accentColor = accentColor
        self.count = count
        self.trailing = trailing
    }

    @Environment(\.sidebarDensity) var density
    @Environment(\.sidebarUsesDuotoneIcons) var usesDuotoneIcons
    @Environment(\.sidebarContextMenuActive) private var isContextMenuActive
    @State var isHovering = false

    private var densityVerticalPadding: CGFloat {
        switch density {
        case .compact: return SpacingTokens.nano
        case .small: return SpacingTokens.xxs
        case .medium: return SpacingTokens.xxs2
        case .large: return SpacingTokens.xxs3
        }
    }

    var showChevron: Bool { isExpanded != nil }
    var expanded: Bool { isExpanded?.wrappedValue ?? false }

    /// Icon color changes to accent when selected (Finder behavior).
    var resolvedIconColor: Color {
        isSelected ? accentColor : iconColor
    }
    @ViewBuilder
    private var highlightFill: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: SidebarRowConstants.hoverCornerRadius, style: .continuous)
                .fill(ColorTokens.Sidebar.selectedFill)
        } else if isContextMenuActive {
            RoundedRectangle(cornerRadius: SidebarRowConstants.hoverCornerRadius, style: .continuous)
                .fill(ColorTokens.Sidebar.contextFill)
        } else if isHovering {
            RoundedRectangle(cornerRadius: SidebarRowConstants.hoverCornerRadius, style: .continuous)
                .fill(ColorTokens.Sidebar.hoverFill)
        } else {
            Color.clear
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Indentation — outside the highlight area
            if depth > 0 {
                Color.clear
                    .frame(width: CGFloat(depth) * SidebarRowConstants.indentStep)
            }

            // Quiet style: one icon slot. A folder's symbol becomes a disclosure on hover.
            HStack(alignment: .center, spacing: SidebarRowConstants.iconTextSpacing) {
                iconView

                if let subtitle {
                    VStack(alignment: .leading, spacing: 1) {
                        labelTextView
                        Text(subtitle)
                            .font(SidebarRowConstants.trailingFont)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                            .lineLimit(1)
                    }
                } else {
                    labelTextView
                }

                Spacer(minLength: SpacingTokens.xxxs)

                // Always shown, quietly (round 16): a count that appeared on hover blinked
                // whenever the row was rebuilt under the pointer.
                if let count, count > 0 {
                    Text("\(count)")
                        .font(SidebarRowConstants.trailingFont)
                        .foregroundStyle(ColorTokens.Text.quaternary)
                        .accessibilityLabel("\(count) items")
                }
                trailing()
            }
            .padding(.leading, SidebarRowConstants.rowLeadingPadding)
            .padding(.trailing, SidebarRowConstants.rowTrailingPadding)
            .padding(.vertical, densityVerticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Only the fill animates, so hover and selection ease in without moving the row.
            .background(
                highlightFill
                    .animation(.easeOut(duration: 0.12), value: isHovering)
                    .animation(.easeOut(duration: 0.16), value: isSelected)
            )
            .contentShape(RoundedRectangle(cornerRadius: SidebarRowConstants.hoverCornerRadius, style: .continuous))
            .onHover { hovering in
                isHovering = hovering
            }
        }
        .padding(.horizontal, SidebarRowConstants.rowOuterHorizontalPadding)
        .buttonStyle(.plain)
        .focusable(false)
        .accessibilityValue(showChevron ? (expanded ? "Expanded" : "Collapsed") : "")
    }

    @ViewBuilder
    private var labelTextView: some View {
        (labelText ?? Text(label).foregroundStyle(labelColor))
            .font(densityLabelFont)
            .lineLimit(1)
    }

}

extension SidebarRow where Trailing == EmptyView {
    init(
        depth: Int,
        icon: Icon,
        label: String,
        labelText: Text? = nil,
        subtitle: String? = nil,
        isExpanded: Binding<Bool>? = nil,
        isSelected: Bool = false,
        iconColor: Color = ColorTokens.Sidebar.symbol,
        labelColor: Color = ColorTokens.Text.primary,
        labelFont: Font = SidebarRowConstants.labelFont,
        accentColor: Color = ColorTokens.accent
    ) {
        self.depth = depth
        self.icon = icon
        self.label = label
        self.labelText = labelText
        self.subtitle = subtitle
        self.isExpanded = isExpanded
        self.isSelected = isSelected
        self.iconColor = iconColor
        self.labelColor = labelColor
        self.labelFont = labelFont
        self.accentColor = accentColor
        self.count = nil
        self.trailing = { EmptyView() }
    }
}
