import Foundation

struct TableDataColumn: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let dataType: String
    let isPrimaryKey: Bool
}

struct CellEdit: Identifiable {
    let id = UUID()
    let rowIndex: Int
    let columnIndex: Int
    let oldValue: String?
    var newValue: String?
}
