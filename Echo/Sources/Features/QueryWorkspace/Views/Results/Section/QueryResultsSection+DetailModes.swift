import SwiftUI

#if os(macOS)
extension QueryResultsSection {
    var currentDisplayedResultRows: [[String?]] {
        if query.selectedResultSetIndex == 0 {
            return exportedPrimaryRows
        }
        return currentResultSet?.rows ?? []
    }

    var currentDisplayedColumnsForDetail: [ColumnInfo] {
        currentResultSet?.columns ?? query.displayedColumns
    }

    var formRecord: QueryResultDetailRecord? {
        QueryResultDetailBuilder.record(
            columns: currentDisplayedColumnsForDetail,
            rows: currentDisplayedResultRows,
            selectedRowIndex: gridState.selectedRowIndex
        )
    }

    var fieldTypeDescriptors: [QueryResultFieldTypeDescriptor] {
        QueryResultDetailBuilder.fieldTypes(columns: currentDisplayedColumnsForDetail)
    }

    var resultDetailModePicker: some View {
        Picker("Result View", selection: detailModeBinding) {
            ForEach(QueryResultDetailMode.allCases, id: \.self) { mode in
                Text(mode.label).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 260)
        .labelsHidden()
        .controlSize(.small)
        .disabled(currentResultSet == nil)
    }

    var detailModeBinding: Binding<QueryResultDetailMode> {
        Binding(
            get: { gridState.detailMode },
            set: { gridState.detailMode = $0 }
        )
    }

    var formResultsView: some View {
        Group {
            if let record = formRecord {
                QueryResultFormView(
                    record: record,
                    rowCount: currentDisplayedResultRows.count,
                    onMoveToRow: { rowIndex in
                        gridState.selectedRowIndex = QueryResultDetailBuilder.resolvedRowIndex(rowIndex, rowCount: currentDisplayedResultRows.count)
                    }
                )
            } else {
                noRowsReturnedView
            }
        }
    }

    var fieldTypesResultsView: some View {
        Group {
            if fieldTypeDescriptors.isEmpty {
                noRowsReturnedView
            } else {
                QueryResultFieldTypesView(descriptors: fieldTypeDescriptors)
            }
        }
    }
}
#endif
