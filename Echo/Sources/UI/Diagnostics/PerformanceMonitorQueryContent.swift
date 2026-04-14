import SwiftUI

struct PerformanceMonitorQueryContent: View {
    @Bindable var tab: WorkspaceTab
    @Bindable var query: QueryEditorState

    var body: some View {
        QueryPerformanceReportView(
            title: tab.title,
            connectionName: tab.connection.connectionName,
            databaseName: tab.connection.database,
            query: query
        )
    }
}
