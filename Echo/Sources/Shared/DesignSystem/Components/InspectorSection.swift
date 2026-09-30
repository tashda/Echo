import SwiftUI

/// One inspector section (plan I2, round 15 "Grouped boxes"): a header (icon, title, actions)
/// over a rounded inset group holding its rows, like System Settings. Sections sit inside the
/// inspector's one card, so there are no stacked shadows.
struct InspectorSection<Content: View, Actions: View>: View {
    let title: String
    var subtitle: String?
    let systemImage: String
    @ViewBuilder var actions: () -> Actions
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xxs2) {
                Image(systemName: systemImage)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    Text(title)
                        .font(TypographyTokens.standard.weight(.semibold))
                        .foregroundStyle(ColorTokens.Text.primary)
                        .textSelection(.enabled)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                }
                Spacer(minLength: SpacingTokens.xs)
                HStack(spacing: SpacingTokens.xxs2) { actions() }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .labelStyle(.iconOnly)
            }
            .padding(.horizontal, SpacingTokens.xxs)
            VStack(alignment: .leading, spacing: SpacingTokens.none) {
                content()
            }
            .padding(.horizontal, LayoutTokens.Inspector.cardPadding)
            .padding(.vertical, SpacingTokens.xxs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ColorTokens.Background.secondary,
                in: .rect(cornerRadius: LayoutTokens.FloatingSurface.rowCornerRadius, style: .continuous)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension InspectorSection where Actions == EmptyView {
    init(title: String, subtitle: String? = nil, systemImage: String, @ViewBuilder content: @escaping () -> Content) {
        self.init(title: title, subtitle: subtitle, systemImage: systemImage, actions: { EmptyView() }, content: content)
    }
}

/// A row in an inspector section: the label left, the selectable value right. Long values wrap; NULL
/// is italic and faint; a link row opens what it names.
struct InspectorSectionRow: View {
    let label: String
    let value: String
    var isLast = false
    var action: (() -> Void)?

    private var isNull: Bool { value == "NULL" }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: LayoutTokens.Inspector.labelValueGap) {
            Text(label)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
                .lineLimit(1)
                .layoutPriority(1)
            Spacer(minLength: SpacingTokens.none)
            valueView
        }
        .padding(.vertical, SpacingTokens.xxs)
        .frame(minHeight: LayoutTokens.Inspector.rowMinHeight)
        .overlay(alignment: .bottom) {
            if !isLast { Divider() }
        }
        .contextMenu {
            Button { copyToGeneralPasteboard(value) } label: { Label("Copy Value", systemImage: "doc.on.doc") }
        }
    }

    @ViewBuilder
    private var valueView: some View {
        let text = Text(value.isEmpty ? "—" : value)
            .font(TypographyTokens.standard.monospacedDigit())
            .italic(isNull)
            .multilineTextAlignment(.trailing)
            .fixedSize(horizontal: false, vertical: true)
        if let action {
            Button(action: action) { text.foregroundStyle(ColorTokens.accent) }
                .buttonStyle(.plain)
        } else {
            text
                .foregroundStyle(isNull ? ColorTokens.Text.tertiary : ColorTokens.Text.primary)
                .textSelection(.enabled)
        }
    }
}
