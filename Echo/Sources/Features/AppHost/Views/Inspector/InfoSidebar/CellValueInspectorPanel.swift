import SwiftUI

struct CellValueInspectorPanel: View {
    let content: CellValueInspectorContent

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            Text("Cell Value")
                .font(TypographyTokens.prominent.weight(.semibold))

            GroupBox {
                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                    LabeledContent("Column", value: content.columnName)
                    Divider()
                    LabeledContent("Type", value: content.dataType.isEmpty ? "Unknown" : content.dataType)
                    Divider()
                    LabeledContent("Kind", value: kindLabel)
                }
                .padding(.vertical, SpacingTokens.xs)
            }

            HStack {
                Text("Value")
                    .font(TypographyTokens.detail.weight(.semibold))
                    .foregroundStyle(ColorTokens.Text.secondary)

                Spacer()

                Button {
                    PlatformClipboard.copy(content.rawValue)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .controlSize(.small)
                .buttonStyle(.borderless)
            }

            Text(content.rawValue)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SpacingTokens.sm)
                .background(ColorTokens.Background.secondary, in: RoundedRectangle(cornerRadius: 6))
        }
    }

    private var kindLabel: String {
        switch content.valueKind {
        case .text: return "Text"
        case .numeric: return "Numeric"
        case .boolean: return "Boolean"
        case .temporal: return "Temporal"
        case .binary: return "Binary"
        case .identifier: return "Identifier"
        case .json: return "JSON"
        case .null: return "NULL"
        }
    }
}
