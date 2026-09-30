import EchoDesignSystem
import SwiftUI
import TDSSpec

/// Decoded TDS fields as an outline: offset, name, length and value.
struct TDSFieldOutline: View {
    let fields: [TDSField]

    var body: some View {
        OutlineGroup(TDSFieldNode.nodes(fields, path: ""), children: \.children) { node in
            TDSFieldRow(field: node.field)
        }
    }
}

/// A decoded field in the outline.
struct TDSFieldNode: Identifiable {
    let id: String
    let field: TDSField
    let children: [TDSFieldNode]?

    static func nodes(_ fields: [TDSField], path: String) -> [TDSFieldNode] {
        fields.enumerated().map { index, field in
            let id = "\(path)/\(index)"
            return TDSFieldNode(id: id, field: field, children: field.children.isEmpty ? nil : nodes(field.children, path: id))
        }
    }
}

struct TDSFieldRow: View {
    let field: TDSField

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xs) {
            Text(String(format: "+%04d", field.offset)).foregroundStyle(ColorTokens.Text.tertiary)
            Text(field.name)
            if field.length > 0 { Text("\(field.length)B").foregroundStyle(ColorTokens.Text.tertiary) }
            Text(field.value).foregroundStyle(ColorTokens.Text.secondary).textSelection(.enabled).lineLimit(3)
        }
    }
}
