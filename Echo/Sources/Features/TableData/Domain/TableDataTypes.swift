import Foundation

struct TableDataColumn: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let dataType: String
    let isPrimaryKey: Bool
}

enum TableDataCellValueMode: String, Sendable, Equatable {
    case literal
    case expression
}

enum TableDataTextTransform: Sendable {
    case uppercase
    case lowercase
    case capitalize

    func apply(to value: String) -> String {
        switch self {
        case .uppercase:
            value.uppercased()
        case .lowercase:
            value.lowercased()
        case .capitalize:
            value.localizedCapitalized
        }
    }
}

struct CellEdit: Identifiable {
    let id = UUID()
    let rowIndex: Int
    let columnIndex: Int
    let oldValue: String?
    var newValue: String?
    var valueMode: TableDataCellValueMode = .literal
}
