import SwiftUI

/// Placeholder rows while a folder's items load (round 16, quiet skeleton; Design/05-components
/// › Explorer tree): an icon square and a text bar per row, at the indent of the rows they stand
/// in for. They appear only after a quarter second, so a fast server never flashes them, and
/// breathe gently instead of sweeping (still with Reduce Motion). The real rows fade in.
struct SkeletonPlaceholderRows: View {
    var count: Int = 3
    let rowHeight: CGFloat
    /// Leading inset, so the placeholders sit at the indent of the rows they stand in for.
    var leadingInset: CGFloat = 0
    /// What's loading, for VoiceOver.
    var accessibilityLabel: String = "Loading"

    /// How long loading may take before the placeholders show.
    static let appearDelay: Duration = .milliseconds(250)

    @Environment(\.echoMotion) private var motion
    @State private var isVisible = false
    @State private var isDimmed = false

    /// Text bar widths, varied so the placeholders read as a list rather than a block.
    private static let barWidths: [CGFloat] = [0.62, 0.44, 0.54, 0.38]

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            ForEach(0..<count, id: \.self) { index in
                HStack(spacing: SidebarRowConstants.iconTextSpacing) {
                    RoundedRectangle(cornerRadius: LayoutTokens.Shimmer.iconCornerRadius, style: .continuous)
                        .frame(width: LayoutTokens.Shimmer.iconSize, height: LayoutTokens.Shimmer.iconSize)
                    GeometryReader { proxy in
                        Capsule()
                            .frame(width: proxy.size.width * Self.barWidths[index % Self.barWidths.count])
                            .frame(maxHeight: .infinity, alignment: .center)
                    }
                    .frame(height: LayoutTokens.Shimmer.barHeight)
                }
                .frame(height: rowHeight)
            }
        }
        .padding(.leading, leadingInset)
        .padding(.trailing, SpacingTokens.lg)
        .foregroundStyle(ColorTokens.Sidebar.hoverFill)
        .opacity(isVisible ? (isDimmed ? 0.55 : 1) : 0)
        .task {
            try? await Task.sleep(for: Self.appearDelay)
            withAnimation(motion.hover) { isVisible = true }
            guard motion.allowsLoopingEffects else { return }
            withAnimation(.easeInOut(duration: motion.pulseHalfPeriod).repeatForever()) { isDimmed = true }
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
    }
}

/// One row saying what is loading (round 16, folders first): a spinner where the icon goes and
/// the words in grey, at the indent of the rows it stands in for.
struct SidebarSpinnerRow: View {
    let depth: Int
    let title: String

    @Environment(\.sidebarDensity) private var density

    var body: some View {
        HStack(spacing: SidebarRowConstants.iconTextSpacing) {
            ProgressView()
                .controlSize(.mini)
                .frame(width: SidebarRowConstants.iconFrameWidth)
            Text(title)
                .font(labelFont)
                .foregroundStyle(ColorTokens.Text.tertiary)
                .lineLimit(1)
            Spacer(minLength: SpacingTokens.none)
        }
        .padding(.leading, CGFloat(depth) * SidebarRowConstants.indentStep + SidebarRowConstants.rowLeadingPadding)
        .padding(.horizontal, SidebarRowConstants.rowOuterHorizontalPadding)
        .frame(maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var labelFont: Font {
        switch density {
        case .compact: TypographyTokens.label
        case .small: TypographyTokens.detail
        case .medium: TypographyTokens.standard
        case .large: TypographyTokens.prominent
        }
    }
}
