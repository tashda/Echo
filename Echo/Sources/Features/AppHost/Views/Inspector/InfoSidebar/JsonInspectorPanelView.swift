import SwiftUI

struct JsonInspectorPanelView: View {
    let content: JsonInspectorContent

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(content.title)
                    .font(.system(.title3, design: .default).weight(.semibold))
                if let subtitle = content.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if content.outline.children.isEmpty {
                JsonInspectorLeafRow(node: content.outline)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(content.outline.children) { child in
                        JsonInspectorNodeRow(node: child, depth: 0)
                    }
                }
            }
        }
        .padding(.top, SpacingTokens.xxs)
        .padding(.bottom, SpacingTokens.xxs)
    }
}

struct JsonInspectorNodeRow: View {
    let node: JsonOutlineNode
    let depth: Int
    @State private var isExpanded: Bool = true

    var body: some View {
        if node.hasChildren {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(node.children) { child in
                        JsonInspectorNodeRow(node: child, depth: depth + 1)
                    }
                }
                .padding(.top, SpacingTokens.xs)
            } label: {
                JsonInspectorRowHeader(title: node.title, subtitle: node.subtitle, depth: depth)
            }
        } else {
            JsonInspectorLeafRow(node: node, depth: depth)
        }
    }
}

struct JsonInspectorRowHeader: View {
    let title: String
    let subtitle: String
    let depth: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(TypographyTokens.standard.weight(.semibold))
            Text(subtitle)
                .font(TypographyTokens.detail)
                .foregroundStyle(.secondary)
        }
        .padding(.leading, CGFloat(depth) * 4)
    }
}

struct JsonInspectorLeafRow: View {
    let node: JsonOutlineNode
    var depth: Int = 0
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title = node.key.displayTitle {
                Text(title.uppercased())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text(node.value.kind.displayName.uppercased())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(node.subtitle.isEmpty ? "—" : node.subtitle)
                .font(.callout.weight(.medium))
                .foregroundStyle(ColorTokens.Text.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
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
                        copyToGeneralPasteboard(node.subtitle)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
        }
        .padding(.leading, CGFloat(depth) * 6)
    }
}
