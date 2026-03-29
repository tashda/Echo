import SwiftUI

struct CellValueEditorSheet: View {
    let content: CellValueInspectorContent
    let displayedValue: String
    let onSaveToFile: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            TextEditor(text: .constant(displayedValue))
                .font(TypographyTokens.Table.sql)
                .scrollContentBackground(.hidden)
                .background(ColorTokens.Background.primary)
                .textSelection(.enabled)
                .padding(SpacingTokens.sm)
        }
        .frame(minWidth: 680, idealWidth: 760, minHeight: 420, idealHeight: 520)
        .background(ColorTokens.Background.primary)
    }

    private var header: some View {
        HStack(spacing: SpacingTokens.sm) {
            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                Text(content.columnName.isEmpty ? "Cell Value" : content.columnName)
                    .font(TypographyTokens.prominent.weight(.semibold))
                Text(content.dataType.isEmpty ? kindLabel : "\(content.dataType) · \(kindLabel)")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }

            Spacer()

            Button {
                PlatformClipboard.copy(displayedValue)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }

            Button {
                onSaveToFile()
            } label: {
                Label("Save", systemImage: "square.and.arrow.down")
            }

            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.sm)
        .background(ColorTokens.Background.secondary)
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
