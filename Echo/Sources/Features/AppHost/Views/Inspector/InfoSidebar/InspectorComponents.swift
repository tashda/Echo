import SwiftUI

struct InspectorFieldRow: View {
    public let field: DatabaseObjectInspectorContent.Field
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
            Text(field.label.uppercased())
                .font(TypographyTokens.caption2)
                .foregroundStyle(ColorTokens.Text.secondary)

            Text(field.value.isEmpty ? "—" : field.value)
                .font(TypographyTokens.callout.weight(.medium))
                .foregroundStyle(ColorTokens.Text.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
                .padding(.vertical, SpacingTokens.xs)
                .padding(.horizontal, SpacingTokens.xs2)
                .background(
                    RoundedRectangle(cornerRadius: SpacingTokens.xs2, style: .continuous)
                        .fill(ColorTokens.Text.secondary.opacity(colorScheme == .dark ? 0.18 : 0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: SpacingTokens.xs2, style: .continuous)
                                .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.18), lineWidth: 0.6)
                        )
                )
                .contentShape(RoundedRectangle(cornerRadius: SpacingTokens.xs2, style: .continuous))
                .contextMenu {
                    Button {
                        copyToGeneralPasteboard(field.value)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
        }
    }
}

struct RelatedInspectorSection: View {
    let content: DatabaseObjectInspectorContent
    let depth: Int
    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            InspectorPanelView(content: content, depth: depth + 1)
                .padding(.top, SpacingTokens.xs2)
        } label: {
            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                Text(content.title)
                    .font(TypographyTokens.subheadline.weight(.semibold))
                if let subtitle = content.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(TypographyTokens.caption)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        }
    }
}

struct InspectorEmptyState: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text(title)
                .font(TypographyTokens.headline)
            Text(message)
                .font(TypographyTokens.subheadline)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SpacingTokens.lg)
        .background(
            RoundedRectangle(cornerRadius: SpacingTokens.md1, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}

func copyToGeneralPasteboard(_ value: String) {
#if os(macOS)
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(value, forType: .string)
#else
    let pasteboard = UIPasteboard.general
    pasteboard.string = value
#endif
}
