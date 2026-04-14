import SwiftUI

extension QueryEditorContainer {
    internal func handleJsonEvent(_ event: QueryResultsTableView.JsonCellEvent) {
        switch event {
        case .selectionChanged(let selection):
            latestJsonSelection = selection
            guard showJsonInInspector else { return }
            if let selection {
                latestForeignKeySelection = nil
                let content = makeJsonInspectorContent(for: selection)
                environmentState.dataInspectorContent = .json(content)
                if autoOpenInspector, !appState.showInfoSidebar {
                    appState.showInfoSidebar = true
                    inspectorAutoOpened = true
                }
            } else {
                // JSON cell deselected — clear JSON content if we still own it
                if case .json = environmentState.dataInspectorContent {
                    environmentState.dataInspectorContent = nil
                }
                // Defer close check to let other handlers (FK) set content first
                deferredInspectorAutoClose()
            }
        case .activate(let selection):
            latestJsonSelection = selection
            guard showJsonInInspector else { return }
            latestForeignKeySelection = nil
            let content = makeJsonInspectorContent(for: selection)
            environmentState.dataInspectorContent = .json(content)
            if !appState.showInfoSidebar {
                appState.showInfoSidebar = true
                inspectorAutoOpened = true
            }
        }
    }

    private func makeJsonInspectorContent(for selection: QueryResultsTableView.JsonSelection) -> JsonInspectorContent {
        let subtitle = jsonRowSummary(for: selection)
        return JsonInspectorContent(
            title: selection.columnName,
            subtitle: subtitle,
            rawJSON: selection.rawValue
        )
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
