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

    private var densityVerticalPadding: CGFloat { density == .large ? 5 : SidebarRowConstants.rowVerticalPadding }
    private var densityIconFrameWidth: CGFloat { density == .large ? 20 : SidebarRowConstants.iconFrameWidth }
    private var densityIconFrameHeight: CGFloat { density == .large ? 18 : SidebarRowConstants.iconFrameHeight }
    private var densityIconFont: Font { density == .large ? Font.system(size: 15, weight: .regular) : SidebarRowConstants.iconFont }
    private var densityLabelFont: Font { density == .large ? Font.system(size: 13, weight: .regular) : labelFont }

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
                    VStack(alignment: .leading, spacing: 0) {
                        Text(label)
                            .font(densityLabelFont)
                            .foregroundStyle(labelColor)
                            .lineLimit(1)
                        Text(subtitle)
                            .font(SidebarRowConstants.trailingFont)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                            .lineLimit(1)
                    }
                } else {
                    Text(label)
                        .font(densityLabelFont)
                        .foregroundStyle(labelColor)
                        .lineLimit(1)
                }

                Spacer(minLength: SpacingTokens.xxxs)

                trailing()
            }
            .padding(.leading, SidebarRowConstants.rowLeadingPadding)
            .padding(.trailing, SidebarRowConstants.rowTrailingPadding)
            .padding(.vertical, densityVerticalPadding)
            .background(highlightFill)
            .contentShape(RoundedRectangle(cornerRadius: SidebarRowConstants.hoverCornerRadius, style: .continuous))
        }
        .padding(.horizontal, SidebarRowConstants.rowOuterHorizontalPadding)
        .buttonStyle(.plain)
        .focusable(false)
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
