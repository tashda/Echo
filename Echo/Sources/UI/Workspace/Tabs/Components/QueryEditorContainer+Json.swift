import SwiftUI

extension QueryEditorContainer {
    internal func handleJsonEvent(_ event: QueryResultsTableView.JsonCellEvent) {
        switch event {
        case .selectionChanged(let selection):
            latestJsonSelection = selection
            if let selection {
                let content = makeJsonInspectorContent(for: selection)
                workspaceSessionStore.dataInspectorContent = .json(content)
            } else if case .json = workspaceSessionStore.dataInspectorContent {
                workspaceSessionStore.dataInspectorContent = nil
            }
        case .activate(let selection):
            latestJsonSelection = selection
            let content = makeJsonInspectorContent(for: selection)
            workspaceSessionStore.dataInspectorContent = .json(content)
        }
    }

    private func makeJsonInspectorContent(for selection: QueryResultsTableView.JsonSelection) -> JsonInspectorContent {
        let outline = selection.jsonValue.toOutlineNode()
        let subtitle = jsonRowSummary(for: selection)
        return JsonInspectorContent(title: selection.columnName, subtitle: subtitle, outline: outline)
    }

    private func jsonRowSummary(for selection: QueryResultsTableView.JsonSelection) -> String {
        if let descriptor = primaryKeyDescriptor(for: selection) {
            return descriptor
        }
        return "Row \(selection.displayedRowIndex + 1)"
    }

    private func primaryKeyDescriptor(for selection: QueryResultsTableView.JsonSelection) -> String? {
        guard let index = query.displayedColumns.firstIndex(where: { $0.isPrimaryKey }),
              index < query.displayedColumns.count else {
            return nil
        }
        let column = query.displayedColumns[index]
        guard let raw = query.valueForDisplay(row: selection.sourceRowIndex, column: index) else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return "\(column.name): \(trimmed)"
    }
}
