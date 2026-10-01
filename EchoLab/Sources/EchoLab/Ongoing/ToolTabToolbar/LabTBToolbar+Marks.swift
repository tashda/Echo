import SwiftUI

/// Revision 2 of round 37.5: the tab's symbol drawn without any glass around it (TT8 to TT22).
extension LabTBToolbar {
    var markSpacing: CGFloat {
        switch look.tie {
        case .tray, .iconTray, .tucked: SpacingTokens.xxs
        case .watermark, .badge: SpacingTokens.none
        default: SpacingTokens.xs
        }
    }

    /// The symbol, in the colour and size set, or the tie's own.
    func symbol(font: Font? = nil, color: Color? = nil) -> some View {
        Image(systemName: tab.symbol)
            .font(font ?? look.symbolSize.font)
            .foregroundStyle(color ?? look.symbolColour.color(tab))
            .help(tab.title)
            .accessibilityLabel("Buttons for \\(tab.title)")
    }

    /// What stands before the buttons for the plain-symbol ties.
    @ViewBuilder
    var symbolMark: some View {
        switch look.tie {
        case .bare, .underline:
            symbol()
        case .bareTint, .tintBoth:
            symbol(color: tab.tint)
        case .tucked:
            symbol(font: TypographyTokens.compact).padding(.trailing, -SpacingTokens.xxxs)
        case .hairline:
            HStack(spacing: SpacingTokens.xs) {
                symbol()
                Rectangle().fill(ColorTokens.Separator.primary).frame(width: 1, height: SpacingTokens.md)
            }
        case .chevron:
            HStack(spacing: SpacingTokens.xxs) {
                symbol()
                Image(systemName: "chevron.compact.right").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
            }
        case .outline:
            symbol(font: TypographyTokens.detail)
                .frame(width: LayoutTokens.Toolbar.glyph - SpacingTokens.xxs, height: LayoutTokens.Toolbar.glyph - SpacingTokens.xxs)
                .overlay(Circle().strokeBorder(ColorTokens.Separator.primary, lineWidth: 1))
        case .engraved:
            Image(systemName: tab.symbol)
                .font(look.symbolSize.font.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.tertiary.shadow(.inner(color: ColorTokens.Text.primary.opacity(0.35), radius: 0.6, y: 0.6)))
                .help(tab.title)
        case .flash:
            symbol().opacity(flashOpacity)
        case .hover:
            if isHovering {
                HStack(spacing: SpacingTokens.xxs) {
                    symbol()
                    Text(tab.title).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary).fixedSize()
                }
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else {
                Circle().fill(tab.tint).frame(width: SpacingTokens.xxs2, height: SpacingTokens.xxs2).transition(.opacity)
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    var trailingMark: some View {
        if look.tie == .after { symbol() }
    }

    @ViewBuilder
    var watermark: some View {
        if look.tie == .watermark {
            Image(systemName: tab.symbol)
                .font(TypographyTokens.title2.weight(.semibold))
                .foregroundStyle(look.symbolColour.color(tab).opacity(0.22))
                .offset(x: -SpacingTokens.md)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    var badge: some View {
        if look.tie == .badge {
            Image(systemName: tab.symbol)
                .font(TypographyTokens.compact.weight(.semibold))
                .foregroundStyle(look.symbolColour.color(tab))
                .frame(width: SpacingTokens.md, height: SpacingTokens.md)
                .background(Circle().fill(ColorTokens.Workspace.card).shadow(ShadowTokens.railSelection))
                .offset(x: -SpacingTokens.xxs, y: -SpacingTokens.xxs)
                .help(tab.title)
        }
    }

    @ViewBuilder
    var underline: some View {
        if look.tie == .underline {
            Capsule().fill(tab.tint).frame(height: SpacingTokens.xxxs).padding(.horizontal, SpacingTokens.sm).offset(y: SpacingTokens.xxs)
        }
    }

    /// TT21: show the symbol, then let it fade.
    func flash() {
        guard look.tie == .flash else { return }
        flashOpacity = 1
        withAnimation(.easeOut(duration: 0.8).delay(1.2)) { flashOpacity = 0 }
    }
}
