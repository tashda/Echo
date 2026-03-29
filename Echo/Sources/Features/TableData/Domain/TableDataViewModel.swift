import Foundation
import Observation

@Observable
final class TableDataViewModel {
    let schemaName: String
    let tableName: String
    let databaseType: DatabaseType

    @ObservationIgnored private(set) var session: DatabaseSession
    @ObservationIgnored var connectionSession: ConnectionSession?
    @ObservationIgnored var activityEngine: ActivityEngine?
    @ObservationIgnored var connectionSessionID: UUID?

    // MARK: - Data State

    var columns: [TableDataColumn] = []
    var rows: [[String?]] = []
    var primaryKeyColumns: [String] = []
    var isLoading = false
    var isLoadingMore = false
    var hasMoreRows = true
    var totalLoadedRows = 0
    var errorMessage: String?

    let pageSize = 200
    var currentOffset = 0

    // MARK: - Edit State

    var isEditMode = false
    var pendingEdits: [CellEdit] = []

    var hasPendingEdits: Bool { !pendingEdits.isEmpty }

    var canEdit: Bool { !primaryKeyColumns.isEmpty }

    // MARK: - Init

    init(
        schemaName: String,
        tableName: String,
        databaseType: DatabaseType,
        session: DatabaseSession
    ) {
        self.schemaName = schemaName
        self.tableName = tableName
        self.databaseType = databaseType
        self.session = session
    }

    // MARK: - Actions

    func toggleEditMode() {
        if isEditMode && hasPendingEdits {
            discardChanges()
        }
        isEditMode.toggle()
    }

    func updateSession(_ newSession: DatabaseSession) {
        session = newSession
    }

    func discardChanges() {
        // Restore original values in the rows array
        for edit in pendingEdits {
            guard edit.rowIndex < rows.count, edit.columnIndex < columns.count else { continue }
            rows[edit.rowIndex][edit.columnIndex] = edit.oldValue
        }
        pendingEdits.removeAll()
    }

    func estimatedMemoryUsageBytes() -> Int {
        let rowBytes = rows.count * columns.count * 32
        return rowBytes + 64 * 1024
    }

    // MARK: - Identifier Quoting

    func quoteIdentifier(_ name: String) -> String {
        switch databaseType {
        case .microsoftSQL:
            let escaped = name.replacingOccurrences(of: "]", with: "]]")
            return "[\(escaped)]"
        case .mysql:
            let escaped = name.replacingOccurrences(of: "`", with: "``")
            return "`\(escaped)`"
        default:
            let escaped = name.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
    }

    var qualifiedTableName: String {
        let table = quoteIdentifier(tableName)
        if databaseType == .sqlite || schemaName.isEmpty {
            return table
        }
        let schema = quoteIdentifier(schemaName)
        return "\(schema).\(table)"
    }
}
