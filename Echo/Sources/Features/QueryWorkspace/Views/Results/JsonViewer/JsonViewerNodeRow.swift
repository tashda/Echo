#if os(macOS)
import SwiftUI

struct JsonViewerNodeRow: View {
    let node: JsonOutlineNode
    let parentPath: String
    let depth: Int
    let isExpanded: Bool
    let onToggle: () -> Void

    private var nodePath: String {
        node.jsonPath(parentPath: parentPath)
    }

    var body: some View {
        HStack(spacing: 0) {
            if node.hasChildren {
                containerContent
            } else {
                leafContent
            }
        }
        .padding(.leading, CGFloat(depth) * SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xxxs)
        .contentShape(Rectangle())
        .contextMenu { contextMenuItems }
    }

    // MARK: - Container (Object / Array)

    private var containerContent: some View {
        HStack(spacing: SpacingTokens.xxs) {
            Button(action: onToggle) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(TypographyTokens.compact.weight(.semibold))
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .frame(width: 12, height: 12, alignment: .center)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            keyLabel

            Text(openBracket)
                .font(TypographyTokens.caption2.monospaced())
                .foregroundStyle(ColorTokens.Text.primary)

            if !isExpanded {
                Text("\u{2026}")
                    .font(TypographyTokens.caption2.monospaced())
                    .foregroundStyle(ColorTokens.Text.quaternary)
                Text(closeBracket)
                    .font(TypographyTokens.caption2.monospaced())
                    .foregroundStyle(ColorTokens.Text.primary)
                Text(node.value.summary)
                    .font(TypographyTokens.detail.monospaced())
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .padding(.leading, SpacingTokens.xxs)
            }
        }
    }

    // MARK: - Leaf (String, Number, Bool, Null)

    private var leafContent: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: 12)
            keyLabel
            valueLabel
        }
    }

    // MARK: - Components

    @ViewBuilder
    private var keyLabel: some View {
        if let title = node.key.displayTitle {
            switch node.key {
            case .property:
                Text("\"\(title)\"")
                    .font(TypographyTokens.caption2.monospaced())
                    .foregroundColor(ColorTokens.Status.info)
                Text(": ")
                    .font(TypographyTokens.caption2.monospaced())
                    .foregroundStyle(ColorTokens.Text.secondary)
            case .index:
                Text(title)
                    .font(TypographyTokens.caption2.monospaced())
                    .foregroundStyle(ColorTokens.Text.tertiary)
                Text(": ")
                    .font(TypographyTokens.caption2.monospaced())
                    .foregroundStyle(ColorTokens.Text.secondary)
            case .root:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private var valueLabel: some View {
        switch node.value {
        case .string(let str):
            Text("\"\(str)\"")
                .font(TypographyTokens.caption2.monospaced())
                .foregroundColor(ColorTokens.Status.success)
                .lineLimit(1)
        case .number(let num):
            Text(num)
                .font(TypographyTokens.caption2.monospaced())
                .foregroundColor(ColorTokens.Status.info)
        case .bool(let val):
            Text(val ? "true" : "false")
                .font(TypographyTokens.caption2.monospaced())
                .foregroundColor(ColorTokens.Status.warning)
        case .null:
            Text("null")
                .font(TypographyTokens.caption2.monospaced().italic())
                .foregroundStyle(ColorTokens.Text.secondary)
        case .object, .array:
            EmptyView()
        }
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        Button {
            PlatformClipboard.copy(node.subtitle)
        } label: {
            Label("Copy Value", systemImage: "doc.on.doc")
        }
        Button {
            PlatformClipboard.copy(nodePath)
        } label: {
            Label("Copy Path", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
        }
    }

    // MARK: - Helpers

    private var openBracket: String {
        switch node.value {
        case .object: return "{"
        case .array: return "["
        default: return ""
        }
    }

    private var closeBracket: String {
        switch node.value {
        case .object: return "}"
        case .array: return "]"
        default: return ""
        }
    }
}
#endif
