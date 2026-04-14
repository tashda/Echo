import Foundation
import SwiftUI

enum TableStructureSection: String, CaseIterable, Identifiable {
    case columns, indexes, constraints, relations, partitions, inheritance
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .columns: return "Columns"
        case .indexes: return "Indexes"
        case .constraints: return "Constraints"
        case .relations: return "Relations"
        case .partitions: return "Partitions"
        case .inheritance: return "Inheritance"
        }
    }
    var displayTitle: String { displayName }
    var icon: String {
        switch self {
        case .columns: return "tablecells"
        case .indexes: return "bolt.horizontal"
        case .constraints: return "shield.lefthalf.filled"
        case .relations: return "arrow.triangle.merge"
        case .partitions: return "square.split.2x2"
        case .inheritance: return "arrow.triangle.branch"
        }
    }

    /// Sections available for a given database dialect.
    static func sections(for databaseType: DatabaseType) -> [TableStructureSection] {
        switch databaseType {
        case .postgresql:
            return [.columns, .indexes, .constraints, .relations, .partitions, .inheritance]
        case .microsoftSQL:
            return [.columns, .indexes, .constraints, .relations]
        default:
            return [.columns, .indexes, .constraints, .relations]
        }
    }
}

@MainActor @Observable
final class TableStructureEditorViewModel {
    var columns: [ColumnModel] = []
    var indexes: [IndexModel] = []
    var uniqueConstraints: [UniqueConstraintModel] = []
    var foreignKeys: [ForeignKeyModel] = []
    var dependencies: [DependencyModel] = []
    var checkConstraints: [CheckConstraintModel] = []
    var primaryKey: PrimaryKeyModel?
    var tableProperties: TableStructureDetails.TableProperties?
    var requestedSection: TableStructureSection?

    var isLoading: Bool = false
    var isApplying: Bool = false
    var lastError: String?
    var lastSuccessMessage: String?

    /// nil = not yet checked, true = has data, false = no data
    var partitionsAvailable: Bool?
    var inheritanceAvailable: Bool?

    let schemaName: String
    let tableName: String
    let databaseType: DatabaseType

    internal private(set) var session: DatabaseSession
    internal var originalPrimaryKeySnapshot: PrimaryKeyModel.Snapshot?
    internal var removedPrimaryKeyName: String?
    @ObservationIgnored var activityEngine: ActivityEngine?
    @ObservationIgnored var connectionSessionID: UUID?

    /// Update the session to point at a different database connection.
    /// Always triggers a reload since the previous session may have returned empty results.
    func updateSession(_ newSession: DatabaseSession) {
        session = newSession
        Task { await reload() }
    }

    var dialectGenerator: SQLDialectGenerator {
        switch databaseType {
        case .microsoftSQL:
            return SQLServerDialectGenerator(schema: schemaName, database: "")
        case .mysql:
            return MySQLDialectGenerator(schema: schemaName)
        default:
            return PostgreSQLDialectGenerator(schema: schemaName)
        }
    }

    init(schemaName: String, tableName: String, details: TableStructureDetails, session: DatabaseSession, databaseType: DatabaseType = .postgresql) {
        self.schemaName = schemaName
        self.tableName = tableName
        self.session = session
        self.databaseType = databaseType
        apply(details: details)
        // When initialized with empty placeholder details, start in loading state
        // so the view shows a spinner immediately instead of an empty state flash.
        if details.columns.isEmpty {
            isLoading = true
        }
    }

    func focusSection(_ section: TableStructureSection) {
        requestedSection = section
    }

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

    func applyChanges() async {
        lastError = nil
        lastSuccessMessage = nil
        let statements = generateStatements()
        guard !statements.isEmpty else { return }
        isApplying = true
        defer { isApplying = false }
        let handle = activityEngine?.begin("Alter \(tableName)", connectionSessionID: connectionSessionID)
        let dialect = dialectGenerator
        do {
            for statement in [dialect.beginTransaction()] + statements + [dialect.commitTransaction()] {
                _ = try await session.executeUpdate(statement)
            }
            let refreshed = try await session.getTableStructureDetails(schema: schemaName, table: tableName)
            apply(details: refreshed)
            lastSuccessMessage = "Structure updated"
            handle?.succeed()
        } catch {
            _ = try? await session.executeUpdate(dialect.rollbackTransaction())
            lastError = error.localizedDescription
            handle?.fail(error.localizedDescription)
        }
    }

    var hasPendingChanges: Bool {
        if columns.contains(where: { $0.isDirty }) { return true }
        if indexes.contains(where: { $0.isDirty }) { return true }
        if uniqueConstraints.contains(where: { $0.isDirty }) { return true }
        if foreignKeys.contains(where: { $0.isDirty }) { return true }
        if checkConstraints.contains(where: { $0.isDirty }) { return true }
        if primaryKey?.isDirty == true { return true }
        if removedPrimaryKeyName != nil { return true }
        return false
    }

    @discardableResult
    func addColumn() -> ColumnModel {
        let defaultType: String = switch databaseType {
        case .mysql: "varchar(255)"
        case .microsoftSQL: "nvarchar(255)"
        default: "text"
        }
        let model = ColumnModel(original: nil, name: "new_column", dataType: defaultType, isNullable: true, defaultValue: nil, generatedExpression: nil, isIdentity: false, identitySeed: nil, identityIncrement: nil, identityGeneration: nil, collation: nil, characterSet: nil, comment: nil, isUnsigned: false, isZerofill: false, ordinalPosition: nil)
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
        let initialColumns = availableColumns.prefix(1).map { IndexModel.Column(name: $0.name, sortOrder: .ascending, isIncluded: false) }
        let defaultType = databaseType == .microsoftSQL ? "nonclustered" : "btree"
        let model = IndexModel(original: nil, name: baseName, columns: initialColumns, isUnique: unique, filterCondition: "", indexType: defaultType)
        indexes.append(model)
        return model
    }

    func removeIndex(_ index: IndexModel) {
        if let position = indexes.firstIndex(where: { $0.id == index.id }) {
            if indexes[position].isNew { indexes.remove(at: position) } else { indexes[position].isDeleted = true }
        }
    }

    func rebuildIndex(_ index: IndexModel) async {
        guard !index.isNew else { return }
        lastError = nil
        lastSuccessMessage = nil
        isApplying = true
        defer { isApplying = false }
        let handle = activityEngine?.begin("Rebuild \(index.name)", connectionSessionID: connectionSessionID)
        do {
            _ = try await session.rebuildIndex(schema: schemaName, table: tableName, index: index.name)
            lastSuccessMessage = "Index \"\(index.name)\" rebuilt successfully"
            handle?.succeed()
        } catch {
            lastError = "Failed to rebuild index: \(error.localizedDescription)"
            handle?.fail(error.localizedDescription)
        }
    }

    @discardableResult
    func addUniqueConstraint() -> UniqueConstraintModel {
        let model = UniqueConstraintModel(original: nil, name: "uq_\(tableName)_\(uniqueConstraints.count + 1)", columns: [], isDeferrable: false, isInitiallyDeferred: false)
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
        let model = ForeignKeyModel(original: nil, name: "fk_\(tableName)_\(foreignKeys.count + 1)", columns: [], referencedSchema: schemaName, referencedTable: tableName, referencedColumns: [], onUpdate: nil, onDelete: nil, isDeferrable: false, isInitiallyDeferred: false)
        foreignKeys.append(model)
        return model
    }

    @discardableResult
    func addCheckConstraint() -> CheckConstraintModel {
        let model = CheckConstraintModel(original: nil, name: "ck_\(tableName)_\(checkConstraints.count + 1)", expression: "")
        checkConstraints.append(model)
        return model
    }

    func removeCheckConstraint(_ constraint: CheckConstraintModel) {
        if let position = checkConstraints.firstIndex(where: { $0.id == constraint.id }) {
            if checkConstraints[position].isNew { checkConstraints.remove(at: position) } else { checkConstraints[position].isDeleted = true }
        }
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
