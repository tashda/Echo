import SwiftUI

#if os(macOS)
extension QueryResultsSection {
    var statisticsView: some View {
        QueryPerformanceReportView(
            title: "Query Statistics",
            connectionName: connection.connectionName,
            databaseName: activeDatabaseName ?? connection.database,
            query: query
        )
    }
}
#endif
