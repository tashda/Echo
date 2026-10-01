import SwiftUI

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

/// I2 and Folders first: a row in the tree's own style, a spinner where the icon goes and what
/// is loading in grey. No trailing dots (Echo's UI text never has them).
struct LabSCSpinnerRow: View {
    let title: String
    let depth: Int
    let options: LabSCOptions

    var body: some View {
        HStack(spacing: SidebarRowConstants.iconTextSpacing) {
            ProgressView()
                .controlSize(.mini)
                .frame(width: SidebarRowConstants.iconFrameWidth)
            Text(title)
                .font(options.density.labelFont)
                .foregroundStyle(ColorTokens.Text.tertiary)
                .lineLimit(1)
            Spacer(minLength: SpacingTokens.none)
        }
        .padding(.leading, SidebarRowConstants.rowLeadingPadding + SidebarRowConstants.rowOuterHorizontalPadding
                 + CGFloat(depth) * SidebarRowConstants.indentStep)
        .frame(height: options.density.rowSlot)
        .transition(.opacity)
        .accessibilityElement(children: .combine)
    }
}

/// I3: a small spinner centred in a three-row space, with the section's name under it.
struct LabSCCentredSpinner: View {
    let title: String
    let height: CGFloat

    var body: some View {
        VStack(spacing: SpacingTokens.xxs2) {
            ProgressView().controlSize(.small)
            Text(title)
                .font(SidebarRowConstants.trailingFont)
                .foregroundStyle(ColorTokens.Text.tertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading \(title)")
    }
}
