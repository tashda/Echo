import SwiftUI

/// Universal sidebar row matching macOS Finder sidebar aesthetics.
///
/// All sidebar items use this single component. The `depth` parameter controls
/// indentation, and `isExpanded` controls the disclosure chevron.
///
/// The selection highlight only covers the content area (from chevron to trailing
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
        self.trailing = trailing
    }

    @Environment(\.sidebarDensity) private var density
    @Environment(\.sidebarContextMenuActive) private var isContextMenuActive
    @State private var isHovering = false

    private var densityVerticalPadding: CGFloat {
        switch density {
        case .compact: return 2
        case .small: return 3
        case .medium: return 4
        case .large: return 6
        }
    }

    private var densityIconFrameWidth: CGFloat {
        switch density {
        case .compact: return 14
        case .small: return 16
        case .medium: return 18
        case .large: return 20
        }
    }

    private var densityIconFrameHeight: CGFloat {
        switch density {
        case .compact: return 12
        case .small: return 14
        case .medium: return 16
        case .large: return 18
        }
    }

    private var densityIconFont: Font {
        switch density {
        case .compact: return Font.system(size: 11, weight: .regular)
        case .small: return Font.system(size: 12, weight: .regular)
        case .medium: return Font.system(size: 14, weight: .regular)
        case .large: return Font.system(size: 16, weight: .regular)
        }
    }

    private var densityLabelFont: Font {
        switch density {
        case .compact: return Font.system(size: 10, weight: .regular)
        case .small: return Font.system(size: 11, weight: .regular)
        case .medium: return Font.system(size: 13, weight: .regular)
        case .large: return Font.system(size: 15, weight: .regular)
        }
    }

    private var showChevron: Bool { isExpanded != nil }
    private var expanded: Bool { isExpanded?.wrappedValue ?? false }

    /// Icon color changes to accent when selected (Finder behavior).
    private var resolvedIconColor: Color {
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

            // Content — inside the highlight area
            HStack(alignment: .center, spacing: SidebarRowConstants.iconTextSpacing) {
                // Fixed-width disclosure column — always present for icon alignment
                ZStack(alignment: .center) {
                    if showChevron {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                            .font(SidebarRowConstants.chevronFont)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                }
                .frame(width: SidebarRowConstants.chevronWidth)

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

                trailing()
            }
            .padding(.leading, SidebarRowConstants.rowLeadingPadding)
            .padding(.trailing, SidebarRowConstants.rowTrailingPadding)
            .padding(.vertical, densityVerticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(highlightFill)
            .contentShape(RoundedRectangle(cornerRadius: SidebarRowConstants.hoverCornerRadius, style: .continuous))
            .onHover { hovering in
                isHovering = hovering
            }
        }
        .padding(.horizontal, SidebarRowConstants.rowOuterHorizontalPadding)
        .buttonStyle(.plain)
        .focusable(false)
    }

    @ViewBuilder
    private var labelTextView: some View {
        (labelText ?? Text(label).foregroundStyle(labelColor))
            .font(densityLabelFont)
            .lineLimit(1)
    }

    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .system(let name):
            Image(systemName: name)
                .font(densityIconFont)
                .imageScale(.medium)
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(resolvedIconColor)
                .frame(width: densityIconFrameWidth, height: densityIconFrameHeight)
        case .asset(let name):
            Image(name)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(resolvedIconColor)
                .frame(width: densityIconFrameWidth, height: densityIconFrameHeight)
        case .none:
            EmptyView()
        }
    }
}

// MARK: - Convenience initializer (no trailing content)

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
        self.trailing = { EmptyView() }
    }
}
