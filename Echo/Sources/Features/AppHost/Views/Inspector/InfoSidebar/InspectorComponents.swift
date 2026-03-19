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

// MARK: - SQL Block

struct InspectorSQLBlock: View {
    let sql: String
    let onOpenInTab: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            HStack {
                Text("SQL")
                    .font(TypographyTokens.caption2)
                    .foregroundStyle(ColorTokens.Text.secondary)
                Spacer()
                Button {
                    copyToGeneralPasteboard(sql)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(TypographyTokens.compact)
                }
                .buttonStyle(.plain)
                .foregroundStyle(ColorTokens.Text.tertiary)
                .help("Copy SQL")

                Button {
                    onOpenInTab()
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(TypographyTokens.compact)
                }
                .buttonStyle(.plain)
                .foregroundStyle(ColorTokens.accent)
                .help("Open in Query Tab")
            }

            Text(sql)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(ColorTokens.Text.primary)
                .lineLimit(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SpacingTokens.xs)
                .background(
                    RoundedRectangle(cornerRadius: SpacingTokens.xs2, style: .continuous)
                        .fill(ColorTokens.Text.secondary.opacity(colorScheme == .dark ? 0.12 : 0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: SpacingTokens.xs2, style: .continuous)
                                .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.18), lineWidth: 0.6)
                        )
                )
                .textSelection(.enabled)
                .contextMenu {
                    Button { copyToGeneralPasteboard(sql) } label: {
                        Label("Copy SQL", systemImage: "doc.on.doc")
                    }
                    Button { onOpenInTab() } label: {
                        Label("Open in Query Tab", systemImage: "arrow.up.right.square")
                    }
                }
        }
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
