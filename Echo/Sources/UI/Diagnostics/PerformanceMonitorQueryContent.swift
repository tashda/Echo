import SwiftUI

struct PerformanceMonitorQueryContent: View {
    @Bindable var tab: WorkspaceTab
    @Bindable var query: QueryEditorState

    var body: some View {
        QueryPerformanceReportView(query: query)
    }
}
