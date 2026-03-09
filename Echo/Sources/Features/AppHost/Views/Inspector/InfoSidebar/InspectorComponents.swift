import SwiftUI

struct InspectorFieldRow: View {
    let field: ForeignKeyInspectorContent.Field
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(field.label.uppercased())
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(field.value.isEmpty ? "—" : field.value)
                .font(.callout.weight(.medium))
                .foregroundStyle(ColorTokens.Text.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
                .padding(.vertical, SpacingTokens.xs)
                .padding(.horizontal, SpacingTokens.xs2)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.secondary.opacity(colorScheme == .dark ? 0.18 : 0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.18), lineWidth: 0.6)
                        )
                )
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
    let content: ForeignKeyInspectorContent
    let depth: Int
    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            InspectorPanelView(content: content, depth: depth + 1)
                .padding(.top, SpacingTokens.xs2)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(content.title)
                    .font(.subheadline.weight(.semibold))
                if let subtitle = content.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct InspectorEmptyState: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SpacingTokens.lg)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
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
