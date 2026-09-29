import SwiftUI
#if os(macOS)
import AppKit
#endif

struct CellValueInspectorPanel: View {
    let content: CellValueInspectorContent
    @State private var showingExpandedEditor = false

    @Environment(ProjectStore.self) private var projectStore

    var body: some View {
        VStack(alignment: .leading, spacing: projectStore.globalSettings.workspaceGutter.points) {
            InspectorCard(title: content.columnName, subtitle: typeLine, systemImage: "character.cursor.ibeam") {
                Button { PlatformClipboard.copy(content.rawValue) } label: { Label("Copy", systemImage: "doc.on.doc") }
                    .help("Copy Value")
                Button { showingExpandedEditor = true } label: { Label("Open in Editor", systemImage: "arrow.up.left.and.arrow.down.right") }
                    .help("Open in Editor")
                Button(action: saveToFile) { Label("Save to File", systemImage: "square.and.arrow.down") }
                    .help("Save to File")
            } content: {
                Text(displayValue)
                    .font(TypographyTokens.code)
                    .italic(content.valueKind == .null)
                    .foregroundStyle(content.valueKind == .null ? ColorTokens.Text.tertiary : ColorTokens.Text.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Row detail (plan I4): every column of the selected cell's row.
            if !content.rowFields.isEmpty {
                InspectorCard(title: content.rowNumber.map { "Row \($0)" } ?? "Row", systemImage: "tablecells") {
                    Button { PlatformClipboard.copy(rowAsText) } label: { Label("Copy Row", systemImage: "doc.on.doc") }
                        .help("Copy Row")
                } content: {
                    ForEach(Array(content.rowFields.enumerated()), id: \.offset) { index, field in
                        InspectorCardRow(label: field.name, value: field.value, isLast: index == content.rowFields.count - 1)
                    }
                }
            }
        }
        .sheet(isPresented: $showingExpandedEditor) {
            CellValueEditorSheet(
                content: content,
                displayedValue: displayValue,
                onSaveToFile: saveToFile
            )
        }
    }

    private var typeLine: String {
        let type = content.dataType.isEmpty ? "Unknown type" : content.dataType
        return "\(type) · \(kindLabel)"
    }

    /// The row as "column<TAB>value" lines.
    private var rowAsText: String {
        content.rowFields.map { "\($0.name)\t\($0.value)" }.joined(separator: "\n")
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
