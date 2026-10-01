#if DEBUG && canImport(SwiftUI)
import SwiftUI
import EchoSense
#if os(macOS)
import AppKit
#endif

private enum SQLAutoCompletionPreviewData {
    static let suggestions: [SQLAutoCompletionSuggestion] = [
        SQLAutoCompletionSuggestion(
            id: "table.employees",
            title: "employees",
            subtitle: "public • hr",
            detail: nil,
            insertText: "employees",
            kind: .table,
            origin: .init(database: "hr", schema: "public", object: "employees")
        ),
        SQLAutoCompletionSuggestion(
            id: "column.employee_id",
            title: "employee_id",
            subtitle: "employees • public",
            detail: "Column hr.public.employees.employee_id",
            insertText: "employee_id",
            kind: .column,
            origin: .init(database: "hr", schema: "public", object: "employees", column: "employee_id"),
            dataType: "integer"
        ),
        SQLAutoCompletionSuggestion(
            id: "column.hire_date",
            title: "hire_date",
            subtitle: "employees • public",
            detail: "Column hr.public.employees.hire_date",
            insertText: "hire_date",
            kind: .column,
            origin: .init(database: "hr", schema: "public", object: "employees", column: "hire_date"),
            dataType: "timestamp"
        ),
        SQLAutoCompletionSuggestion(
            id: "function.date_trunc",
            title: "date_trunc",
            subtitle: "public",
            detail: "Function hr.public.date_trunc",
            insertText: "date_trunc",
            kind: .function,
            origin: .init(database: "hr", schema: "public", object: "date_trunc")
        )
    ]
}

private struct AutoCompletionListPreview: View {
    private let data = SQLAutoCompletionPreviewData.suggestions
    var isChoosing = false

    var body: some View {
        AutoCompletionListView(
            suggestions: data,
            selectedID: data[1].id,
            isChoosing: isChoosing,
            typed: "da",
            nameFont: .monospacedSystemFont(ofSize: 13, weight: .regular),
            cardCornerRadius: LayoutTokens.Workspace.cardCornerRadius,
            statusMessage: nil,
            onSelect: { _ in }
        )
        .padding(SpacingTokens.lg)
        .background(ColorTokens.Workspace.canvas)
    }
}

#Preview("EchoSense · typing") { AutoCompletionListPreview() }
#Preview("EchoSense · choosing") { AutoCompletionListPreview(isChoosing: true) }
#endif
