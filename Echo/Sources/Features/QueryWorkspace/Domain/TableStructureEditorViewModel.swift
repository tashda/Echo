import Foundation
import SwiftUI
import Combine

enum TableStructureSection: String, CaseIterable, Identifiable {
    case columns, indexes, relations
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .columns: return "Columns"
        case .indexes: return "Indexes"
        case .relations: return "Relations"
        }
    }
    var displayTitle: String { displayName }
    var icon: String {
        switch self {
        case .columns: return "tablecells"
        case .indexes: return "bolt.horizontal"
        case .relations: return "arrow.triangle.merge"
        }
    }
}

final class TableStructureEditorViewModel: ObservableObject {
    @Published var columns: [ColumnModel] = []
    @Published var indexes: [IndexModel] = []
    @Published var uniqueConstraints: [UniqueConstraintModel] = []
    @Published var foreignKeys: [ForeignKeyModel] = []
    @Published var dependencies: [DependencyModel] = []
    @Published var primaryKey: PrimaryKeyModel?
    @Published var requestedSection: TableStructureSection?

    @Published var isLoading: Bool = false
    @Published var isApplying: Bool = false
    @Published var lastError: String?
    @Published var lastSuccessMessage: String?

    let schemaName: String
    let tableName: String

    internal let session: DatabaseSession
    internal var originalPrimaryKeySnapshot: PrimaryKeyModel.Snapshot?
    internal var removedPrimaryKeyName: String?

    init(schemaName: String, tableName: String, details: TableStructureDetails, session: DatabaseSession) {
        self.schemaName = schemaName
        self.tableName = tableName
        self.session = session
        apply(details: details)
    }

    func focusSection(_ section: TableStructureSection) {
        requestedSection = section
    }

    @MainActor
    func reload() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let details = try await session.getTableStructureDetails(schema: schemaName, table: tableName)
            apply(details: details)
        } catch {
            lastError = error.localizedDescription
        }
    }

    @MainActor
    func applyChanges() async {
        lastError = nil
        lastSuccessMessage = nil
        let statements = generateStatements()
        guard !statements.isEmpty else {
            lastSuccessMessage = "No changes to apply"
            return
        }
        isApplying = true
        defer { isApplying = false }
        do {
            let executionPlan = ["BEGIN;"] + statements + ["COMMIT;"]
            for statement in executionPlan {
                _ = try await session.executeUpdate(statement)
            }
            let refreshed = try await session.getTableStructureDetails(schema: schemaName, table: tableName)
            apply(details: refreshed)
            lastSuccessMessage = "Structure updated"
        } catch {
            _ = try? await session.executeUpdate("ROLLBACK;")
            lastError = error.localizedDescription
        }
    }

    var hasPendingChanges: Bool {
        if columns.contains(where: { $0.isDirty }) { return true }
        if indexes.contains(where: { $0.isDirty }) { return true }
        if uniqueConstraints.contains(where: { $0.isDirty }) { return true }
        if foreignKeys.contains(where: { $0.isDirty }) { return true }
        if primaryKey?.isDirty == true { return true }
        if removedPrimaryKeyName != nil { return true }
        return false
    }

    @discardableResult
    func addColumn() -> ColumnModel {
        let model = ColumnModel(original: nil, name: "new_column", dataType: "text", isNullable: true, defaultValue: nil, generatedExpression: nil)
        columns.append(model)
        return model
    }

    func removeColumn(_ column: ColumnModel) {
        if let index = columns.firstIndex(where: { $0.id == column.id }) {
            if columns[index].isNew { columns.remove(at: index) } else { columns[index].isDeleted = true }
        }
    }

    func updateColumn(_ column: ColumnModel) {
        if let index = columns.firstIndex(where: { $0.id == column.id }) {
            columns[index] = column
        }
    }

    @discardableResult
    func addIndex(unique: Bool = false) -> IndexModel {
        let baseName = unique ? "new_unique" : "new_index"
        let availableColumns = columns.filter { !$0.isDeleted }
        let initialColumns = availableColumns.prefix(1).map { IndexModel.Column(name: $0.name, sortOrder: .ascending) }
        let model = IndexModel(original: nil, name: baseName, columns: initialColumns, isUnique: unique, filterCondition: "")
        indexes.append(model)
        return model
    }

    func removeIndex(_ index: IndexModel) {
        if let position = indexes.firstIndex(where: { $0.id == index.id }) {
            if indexes[position].isNew { indexes.remove(at: position) } else { indexes[position].isDeleted = true }
        }
    }

    @discardableResult
    func addUniqueConstraint() -> UniqueConstraintModel {
        let model = UniqueConstraintModel(original: nil, name: "uq_\(tableName)_\(uniqueConstraints.count + 1)", columns: [])
        uniqueConstraints.append(model)
        return model
    }

    func removeUniqueConstraint(_ constraint: UniqueConstraintModel) {
        if let position = uniqueConstraints.firstIndex(where: { $0.id == constraint.id }) {
            if uniqueConstraints[position].isNew { uniqueConstraints.remove(at: position) } else { uniqueConstraints[position].isDeleted = true }
        }
    }

    @discardableResult
    func addForeignKey() -> ForeignKeyModel {
        let model = ForeignKeyModel(original: nil, name: "fk_\(tableName)_\(foreignKeys.count + 1)", columns: [], referencedSchema: schemaName, referencedTable: tableName, referencedColumns: [], onUpdate: nil, onDelete: nil)
        foreignKeys.append(model)
        return model
    }

    func removeForeignKey(_ fk: ForeignKeyModel) {
        if let position = foreignKeys.firstIndex(where: { $0.id == fk.id }) {
            if foreignKeys[position].isNew { foreignKeys.remove(at: position) } else { foreignKeys[position].isDeleted = true }
        }
    }

    func removePrimaryKey() {
        if removedPrimaryKeyName == nil { removedPrimaryKeyName = originalPrimaryKeySnapshot?.name }
        primaryKey = nil
    }

    func clearPrimaryKeyRemoval() { removedPrimaryKeyName = nil }
}
