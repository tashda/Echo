import SwiftUI

/// Revision 2 of round 37.2: the header on one line. The pages are in the tab (36.1), so the
/// line holds the name and the controls: picker, search, other actions, then the main action.
extension LabTTHeaderView {
    @ViewBuilder
    var oneLineHeader: some View {
        switch look.header {
        case .glassLine:
            HStack(spacing: SpacingTokens.sm) {
                slimTitle
                Spacer(minLength: SpacingTokens.md)
                controls
            }
            .padding(.leading, SpacingTokens.sm).padding(.trailing, SpacingTokens.xxs)
            .frame(height: SpacingTokens.xl2 - SpacingTokens.xxs)
            .glassEffect(.regular, in: .capsule)
        case .slimLine:
            line(height: SpacingTokens.lg2) { slimTitle }
        case .controlsOnly:
            line(height: SpacingTokens.lg2) {
                Text(tool.subtitle).font(TypographyTokens.detail.monospacedDigit()).foregroundStyle(ColorTokens.Text.secondary)
            }
        default:
            line(height: SpacingTokens.xl2) { title }
        }
    }

    private func line<Leading: View>(height: CGFloat, @ViewBuilder leading: () -> Leading) -> some View {
        HStack(spacing: SpacingTokens.sm) {
            leading()
            Spacer(minLength: SpacingTokens.md)
            controls
        }
        .frame(height: height)
    }

    /// The name and subtitle as one line of text.
    private var slimTitle: some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: tool.symbol).font(TypographyTokens.standard.weight(.semibold)).foregroundStyle(tool.tint)
            Text(tool.name).font(TypographyTokens.standard.weight(.semibold))
            Text(tool.subtitle).font(TypographyTokens.detail.monospacedDigit()).foregroundStyle(ColorTokens.Text.secondary)
        }
        .lineLimit(1)
    }

    private var controls: some View {
        HStack(spacing: SpacingTokens.xs) {
            pickerView
            searchView
            secondaryButtons
            statusView
            primaryButton
        }
    }
}
