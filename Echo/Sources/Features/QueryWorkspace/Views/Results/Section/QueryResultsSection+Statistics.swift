import SwiftUI

#if os(macOS)
extension QueryResultsSection {
    var statisticsView: some View {
        QueryPerformanceReportView(query: query)
    }
}
#endif
