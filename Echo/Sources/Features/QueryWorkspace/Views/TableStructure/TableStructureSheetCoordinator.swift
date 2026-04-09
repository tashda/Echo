import SwiftUI

@MainActor
@Observable
final class TableStructureSheetCoordinator {
    var activeSheet: TableStructureSheet?
    var pendingNewIndex: TableStructureEditorViewModel.IndexModel?
    var pendingNewPrimaryKey: TableStructureEditorViewModel.PrimaryKeyModel?
    var pendingNewUniqueConstraint: TableStructureEditorViewModel.UniqueConstraintModel?
    var pendingNewForeignKey: TableStructureEditorViewModel.ForeignKeyModel?
    var pendingNewCheckConstraint: TableStructureEditorViewModel.CheckConstraintModel?
}

enum TableStructureSheet: Identifiable {
    case index(IndexEditorPresentation)
    case column(ColumnEditorPresentation)
    case primaryKey(PrimaryKeyEditorPresentation)
    case uniqueConstraint(UniqueConstraintEditorPresentation)
    case foreignKey(ForeignKeyEditorPresentation)
    case checkConstraint(CheckConstraintEditorPresentation)
    case newIndex
    case newColumn
    case newPrimaryKey
    case newUniqueConstraint
    case newForeignKey
    case newCheckConstraint
    case bulkColumn(BulkColumnEditorPresentation)

    var id: String {
        switch self {
        case .index(let presentation): "index-\(presentation.indexID)"
        case .column(let presentation): "column-\(presentation.columnID)"
        case .primaryKey: "primaryKey"
        case .uniqueConstraint(let presentation): "uniqueConstraint-\(presentation.constraintID)"
        case .foreignKey(let presentation): "foreignKey-\(presentation.foreignKeyID)"
        case .checkConstraint(let presentation): "checkConstraint-\(presentation.constraintID)"
        case .newIndex: "newIndex"
        case .newColumn: "newColumn"
        case .newPrimaryKey: "newPrimaryKey"
        case .newUniqueConstraint: "newUniqueConstraint"
        case .newForeignKey: "newForeignKey"
        case .newCheckConstraint: "newCheckConstraint"
        case .bulkColumn: "bulkColumn"
        }
    }
}
