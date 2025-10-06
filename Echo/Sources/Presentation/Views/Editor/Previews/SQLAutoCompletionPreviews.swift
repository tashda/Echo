#if DEBUG && canImport(SwiftUI)
import SwiftUI
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
    private let resetID = UUID()

    var body: some View {
        AutoCompletionListView(
            suggestions: data,
            selectedID: data[1].id,
            onSelect: { _ in },
            detailResetID: resetID
        )
        .padding(24)
#if os(macOS)
        .background(Color(NSColor.windowBackgroundColor))
#else
        .background(Color(UIColor.systemBackground))
#endif
        .previewDisplayName("AutoCompletion Popover")
        .previewLayout(.sizeThatFits)
    }
}

private struct AutoCompletionDetailPreview: View {
    private let suggestion = SQLAutoCompletionPreviewData.suggestions[1]

    var body: some View {
        AutoCompletionDetailView(suggestion: suggestion)
            .padding()
#if os(macOS)
            .background(Color(NSColor.windowBackgroundColor))
#else
            .background(Color(UIColor.systemBackground))
#endif
            .previewDisplayName("AutoCompletion Detail")
            .previewLayout(.sizeThatFits)
    }
}

struct SQLAutoCompletionPreviews_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AutoCompletionListPreview()
                .environment(\.colorScheme, .light)
            AutoCompletionListPreview()
                .environment(\.colorScheme, .dark)
            AutoCompletionDetailPreview()
                .environment(\.colorScheme, .light)
            AutoCompletionDetailPreview()
                .environment(\.colorScheme, .dark)
        }
    }
}
#endif
