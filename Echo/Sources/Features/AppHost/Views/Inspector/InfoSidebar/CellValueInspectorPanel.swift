import SwiftUI
#if os(macOS)
import AppKit
#endif

struct CellValueInspectorPanel: View {
    let content: CellValueInspectorContent
    @State private var showingExpandedEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            Text("Cell Value")
                .font(TypographyTokens.prominent.weight(.semibold))

            GroupBox {
                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                    PropertyRow(title: "Column") {
                        Text(content.columnName)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                    Divider()
                    PropertyRow(title: "Type") {
                        Text(content.dataType.isEmpty ? "Unknown" : content.dataType)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                    Divider()
                    PropertyRow(title: "Kind") {
                        Text(kindLabel)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
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

                Button {
                    showingExpandedEditor = true
                } label: {
                    Label("Open in Editor", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                .controlSize(.small)
                .buttonStyle(.borderless)

                Button {
                    saveToFile()
                } label: {
                    Label("Save to File", systemImage: "square.and.arrow.down")
                }
                .controlSize(.small)
                .buttonStyle(.borderless)
            }

            Text(displayValue)
                .font(TypographyTokens.code)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SpacingTokens.sm)
                .background(ColorTokens.Background.secondary, in: RoundedRectangle(cornerRadius: 6))
        }
        .sheet(isPresented: $showingExpandedEditor) {
            CellValueEditorSheet(
                content: content,
                displayedValue: displayValue,
                onSaveToFile: saveToFile
            )
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

    private var displayValue: String {
        CellValueEditorContentFormatter.displayValue(for: content)
    }

    private func saveToFile() {
#if os(macOS)
        let panel = NSSavePanel()
        panel.allowedContentTypes = CellValueEditorContentFormatter.contentTypes(for: content)
        panel.nameFieldStringValue = CellValueEditorContentFormatter.suggestedFileName(for: content)
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? displayValue.write(to: url, atomically: true, encoding: .utf8)
#endif
    }
}
