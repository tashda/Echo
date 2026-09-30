import SwiftUI

/// One S4 Quiet row that follows the size setting. The selection is inset the same on both
/// sides (Echo pulls every row 8pt left, a leftover of S1's chevron column, so the fill touches
/// the card's left edge but not its right). The count and a spinner share one trailing slot,
/// so loading never adds or removes views beside the label.
struct LabSCRow: View {
    let node: LabSCNode
    let depth: Int
    let isExpanded: Bool
    let isSelected: Bool
    let isLoading: Bool
    let options: LabSCOptions
    let onTap: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: SidebarRowConstants.iconTextSpacing) {
            icon
                .frame(width: SidebarRowConstants.iconFrameWidth)
            label
            Spacer(minLength: SpacingTokens.xxxs)
            trailingSlot
        }
        .padding(.leading, SidebarRowConstants.rowLeadingPadding)
        .padding(.trailing, SidebarRowConstants.rowTrailingPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: options.density.rowSlot - SpacingTokens.micro)
        .background {
            RoundedRectangle(cornerRadius: SidebarRowConstants.hoverCornerRadius, style: .continuous)
                .fill(isSelected ? ColorTokens.Sidebar.selectedFill : isHovering ? ColorTokens.Sidebar.hoverFill : .clear)
                .animation(.easeOut(duration: 0.12), value: isHovering)
        }
        .contentShape(RoundedRectangle(cornerRadius: SidebarRowConstants.hoverCornerRadius, style: .continuous))
        .padding(.leading, CGFloat(depth) * SidebarRowConstants.indentStep)
        .padding(.horizontal, SidebarRowConstants.rowOuterHorizontalPadding)
        .padding(.leading, options.selection == .today ? -(SidebarRowConstants.rowOuterHorizontalPadding + SpacingTokens.xxxs) : SpacingTokens.none)
        .frame(height: options.density.rowSlot)
        .onHover { isHovering = $0 }
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(node.isFolder ? (isExpanded ? "Expanded" : "Collapsed") : "")
    }

    @ViewBuilder
    private var icon: some View {
        if node.isFolder && isHovering {
            Image(systemName: "chevron.right")
                .font(SidebarRowConstants.chevronFont)
                .foregroundStyle(ColorTokens.Text.tertiary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
        } else {
            LabSCSymbol(name: node.symbol, color: node.color, style: options.treeIcons, isCurrent: isSelected,
                        font: options.density.iconFont)
        }
    }

    private var label: some View {
        Group {
            if let prefix = node.prefix {
                Text("\(Text("\(prefix).").foregroundStyle(ColorTokens.Text.tertiary))\(Text(node.title))")
            } else {
                Text(node.title)
            }
        }
        .font(options.density.labelFont)
        .foregroundStyle(ColorTokens.Text.primary)
        .lineLimit(1)
    }

    /// One slot for the spinner or the count, so neither pushes the other.
    private var trailingSlot: some View {
        ZStack(alignment: .trailing) {
            if let count = node.count {
                Text("\(count)")
                    .font(SidebarRowConstants.trailingFont)
                    .foregroundStyle(options.counts == .always ? ColorTokens.Text.quaternary : ColorTokens.Text.tertiary)
                    .opacity(countVisible && !isLoading ? 1 : 0)
            }
            if isLoading {
                ProgressView().controlSize(.mini)
            }
        }
    }

    private var countVisible: Bool {
        switch options.counts {
        case .hover: isHovering
        case .always: true
        case .hidden: false
        }
    }
}

/// A symbol drawn mono (grey, accent when current) or duotone (its colour over a light fill).
struct LabSCSymbol: View {
    let name: String
    let color: Color
    let style: LabSCIconStyle
    var isCurrent = false
    var font: Font = TypographyTokens.standard.weight(.light)

    var body: some View {
        ZStack {
            if style == .duotone, NSImage(systemSymbolName: "\(name).fill", accessibilityDescription: nil) != nil {
                Image(systemName: "\(name).fill")
                    .foregroundStyle(tint.opacity(0.22))
            }
            Image(systemName: name)
                .foregroundStyle(tint)
        }
        .symbolRenderingMode(.monochrome)
        .font(font)
        .accessibilityHidden(true)
    }

    private var tint: Color {
        if isCurrent { return ColorTokens.accent }
        return style == .duotone ? color.mix(with: ColorTokens.Text.secondary, by: ColorTokens.Explorer.colorfulSoftening) : ColorTokens.Sidebar.symbol
    }
}

/// What stands in for rows that are still loading.
struct LabSCLoadingRows: View {
    let style: LabSCLoading
    let depth: Int
    let options: LabSCOptions

    @State private var isVisible = false
    @State private var phase = false

    private static let widths: [CGFloat] = [0.62, 0.44, 0.54]

    var body: some View {
        VStack(spacing: SpacingTokens.none) {
            ForEach(Array(Self.widths.enumerated()), id: \.offset) { _, width in
                row(width: width)
            }
        }
        .opacity(isVisible ? 1 : 0)
        .task {
            // The skeleton waits a moment, so a fast server never flashes it.
            if style == .skeleton { try? await Task.sleep(for: .milliseconds(250)) }
            withAnimation(.easeOut(duration: 0.18)) { isVisible = true }
            withAnimation(.easeInOut(duration: 0.9).repeatForever()) { phase = true }
        }
        .accessibilityLabel("Loading")
    }

    private func row(width: CGFloat) -> some View {
        HStack(spacing: SidebarRowConstants.iconTextSpacing) {
            if style == .skeleton {
                RoundedRectangle(cornerRadius: SpacingTokens.nano, style: .continuous)
                    .frame(width: SidebarRowConstants.iconFrameHeight - SpacingTokens.xxxs, height: SidebarRowConstants.iconFrameHeight - SpacingTokens.xxxs)
                    .frame(width: SidebarRowConstants.iconFrameWidth)
            }
            GeometryReader { proxy in
                Capsule().frame(width: proxy.size.width * width, height: style == .skeleton ? SpacingTokens.xs : SpacingTokens.xs2)
                    .frame(maxHeight: .infinity)
            }
        }
        .foregroundStyle(ColorTokens.Text.quaternary.opacity(style == .skeleton ? (phase ? 0.5 : 0.8) : (phase ? 0.35 : 1)))
        .padding(.leading, SidebarRowConstants.rowLeadingPadding + SidebarRowConstants.rowOuterHorizontalPadding + CGFloat(depth) * SidebarRowConstants.indentStep
                 + (style == .shimmer ? SidebarRowConstants.chevronWidth : SpacingTokens.none))
        .padding(.trailing, SpacingTokens.md)
        .frame(height: options.density.rowSlot)
    }
}
