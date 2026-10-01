import Foundation

/// Activity Monitor's pages for its engine, in order. The tab shows them (ST2); the view shows
/// the one in `selectedSection`.
extension ActivityMonitorViewModel {
    var pageTitles: [String] {
        switch databaseType {
        case .microsoftSQL: MSSQLActivityMonitorView.MSSQLActivitySection.allCases.map(\.rawValue)
        case .postgresql: PostgresActivityMonitorView.PostgresActivitySection.allCases.map(\.rawValue)
        case .mysql: MySQLActivityMonitorView.MySQLActivitySection.allCases.map(\.rawValue)
        case .sqlite: []
        }
    }

    var currentPage: String? { selectedSection ?? pageTitles.first }
}
