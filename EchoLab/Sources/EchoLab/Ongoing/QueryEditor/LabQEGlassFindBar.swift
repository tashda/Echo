import SwiftUI

/// Round 28.12 rev 2: immersive find bars. The search sits straight on Liquid Glass (no white
/// field); arrows and close are plain glyphs or glass buttons; Replace and the search's scope
/// follow the controls.
struct LabQEGlassFindBar: View {
    let place: LabQEFindBarPlace
    let count: LabQEFindCount
    let replace: LabQEReplaceStyle
    let scope: LabQEFindScope
    let showsReplace: Bool
    var hasSelection = false

    var body: some View {
        switch place {
        case .safari:
            GlassEffectContainer(spacing: SpacingTokens.xs) {
                HStack(spacing: SpacingTokens.xs) {
                    VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                        findRow(withArrows: false)
                        if showsReplace, replace != .ownCapsule { replaceRow }
                    }
                    .padding(.horizontal, SpacingTokens.md).padding(.vertical, SpacingTokens.xs)
                    .frame(minWidth: 150, maxWidth: 300)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpacingTokens.lg, style: .continuous))
                    .layoutPriority(1)
                    if showsReplace, replace == .ownCapsule { replaceCapsule }
                    ForEach(["chevron.left", "chevron.right", "xmark"], id: \.self) { symbol in
                        Image(systemName: symbol).frame(width: SpacingTokens.xl, height: SpacingTokens.xl)
                            .glassEffect(.regular, in: .circle)
                    }
                }
            }
            .font(TypographyTokens.standard)
            .padding(.top, SpacingTokens.sm)
        case .spotlight:
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                findRow(withArrows: false).font(TypographyTokens.headline)
                if showsReplace, replace != .ownCapsule { replaceRow }
                Divider()
                ForEach([(3, "FROM orders AS o"), (10, "UPDATE orders")], id: \.0) { line, text in
                    HStack(spacing: SpacingTokens.sm) {
                        Text(verbatim: "\(line)").monospacedDigit().foregroundStyle(ColorTokens.Text.tertiary).frame(width: SpacingTokens.md, alignment: .trailing)
                        Text(verbatim: text).font(TypographyTokens.code)
                    }
                    .padding(.vertical, SpacingTokens.xxxs).padding(.horizontal, SpacingTokens.xxs)
                    .background(line == 3 ? ColorTokens.accent.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: SpacingTokens.xxs2))
                }
            }
            .font(TypographyTokens.standard)
            .padding(SpacingTokens.md)
            .frame(width: 400)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpacingTokens.lg, style: .continuous))
            .padding(.top, SpacingTokens.xl)
        default:
            HStack(spacing: SpacingTokens.xs) {
                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    findRow(withArrows: true)
                    if showsReplace, replace != .ownCapsule { replaceRow }
                }
                .padding(.horizontal, SpacingTokens.md).padding(.vertical, SpacingTokens.xs)
                .frame(width: width, alignment: .leading)
                .frame(maxWidth: place == .immersiveStrip ? .infinity : nil, alignment: .leading)
                .glassEffect(.regular, in: shape)
                if showsReplace, replace == .ownCapsule { replaceCapsule }
            }
            .font(TypographyTokens.detail)
            .padding(.horizontal, place == .immersiveStrip ? SpacingTokens.xs : SpacingTokens.none)
            .padding(.top, place == .notch ? SpacingTokens.none : SpacingTokens.xs)
            .padding(.bottom, place == .bottomCapsule ? SpacingTokens.md : SpacingTokens.none)
            .padding(.trailing, place == .corner ? SpacingTokens.xs : SpacingTokens.none)
        }
    }

    private var width: CGFloat? {
        switch place {
        case .corner: 240
        case .immersiveStrip: nil
        default: 330
        }
    }

    private var shape: AnyShape {
        place == .notch
            ? AnyShape(UnevenRoundedRectangle(bottomLeadingRadius: SpacingTokens.lg, bottomTrailingRadius: SpacingTokens.lg, style: .continuous))
            : AnyShape(Capsule())
    }

    private func findRow(withArrows: Bool) -> some View {
        HStack(spacing: SpacingTokens.xs) {
            if replace == .expand {
                Image(systemName: showsReplace ? "chevron.down" : "chevron.right").foregroundStyle(ColorTokens.Text.secondary)
            }
            Image(systemName: "magnifyingglass").foregroundStyle(ColorTokens.Text.secondary)
            Text(verbatim: "orders")
            Spacer(minLength: SpacingTokens.sm)
            scopeControl
            Text(verbatim: count == .found ? "2 found" : "1 of 2").foregroundStyle(ColorTokens.Text.secondary)
            if withArrows {
                Image(systemName: "chevron.left")
                Image(systemName: "chevron.right")
                Image(systemName: "xmark").foregroundStyle(ColorTokens.Text.secondary)
            }
        }
    }

    @ViewBuilder
    private var scopeControl: some View {
        switch scope {
        case .editor:
            EmptyView()
        case .selectionAuto:
            Text(verbatim: "in selection").foregroundStyle(ColorTokens.accent)
        case .selectionToggle:
            Image(systemName: "text.badge.checkmark").foregroundStyle(ColorTokens.Text.secondary).help("In Selection")
        case .selectionButton:
            if hasSelection {
                Text(verbatim: "Selection").foregroundStyle(ColorTokens.Text.onFill)
                    .padding(.horizontal, SpacingTokens.xs).padding(.vertical, SpacingTokens.micro)
                    .background(ColorTokens.accent, in: Capsule())
            }
        case .segmented:
            HStack(spacing: SpacingTokens.none) {
                ForEach(["Script", "Statement", "Selection"], id: \.self) { item in
                    Text(verbatim: item).padding(.horizontal, SpacingTokens.xxs2).padding(.vertical, SpacingTokens.micro)
                        .background(item == "Script" ? ColorTokens.Text.primary.opacity(0.1) : .clear, in: Capsule())
                }
            }
            .font(TypographyTokens.detail)
        }
    }

    private var replaceRow: some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: "arrow.2.squarepath").foregroundStyle(ColorTokens.Text.secondary)
            Text(verbatim: "orders_2026").lineLimit(1)
            Spacer(minLength: SpacingTokens.xs)
            pill("Replace")
            pill("Replace All")
        }
    }

    /// Rev 4: Replace and Replace All as tinted pills you can't miss.
    private func pill(_ title: String) -> some View {
        Text(verbatim: title).foregroundStyle(ColorTokens.accent).lineLimit(1).fixedSize()
            .padding(.horizontal, SpacingTokens.xs).padding(.vertical, SpacingTokens.micro)
            .background(ColorTokens.accent.opacity(0.15), in: Capsule())
    }

    private var replaceCapsule: some View {
        replaceRow
            .font(TypographyTokens.detail)
            .padding(.horizontal, SpacingTokens.md).padding(.vertical, SpacingTokens.xs)
            .frame(width: 240)
            .glassEffect(.regular, in: Capsule())
    }
}
