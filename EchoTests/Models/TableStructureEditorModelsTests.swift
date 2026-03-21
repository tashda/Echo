import Testing
import Foundation
@testable import Echo

@MainActor
@Suite("TableStructureEditorModels")
struct TableStructureEditorModelsTests {

    typealias ColumnModel = TableStructureEditorViewModel.ColumnModel
    typealias IndexModel = TableStructureEditorViewModel.IndexModel
    typealias UniqueConstraintModel = TableStructureEditorViewModel.UniqueConstraintModel
    typealias ForeignKeyModel = TableStructureEditorViewModel.ForeignKeyModel
    typealias PrimaryKeyModel = TableStructureEditorViewModel.PrimaryKeyModel
    typealias CheckConstraintModel = TableStructureEditorViewModel.CheckConstraintModel

    // MARK: - ColumnModel: isNew

    @Test func columnModelIsNewWhenNoOriginal() {
        let col = ColumnModel(original: nil, name: "id", dataType: "integer", isNullable: false)
        #expect(col.isNew == true)
    }

    @Test func columnModelIsNotNewWhenOriginalExists() {
        let snapshot = ColumnModel.Snapshot(name: "id", dataType: "integer", isNullable: false, defaultValue: nil, generatedExpression: nil)
        let col = ColumnModel(original: snapshot, name: "id", dataType: "integer", isNullable: false)
        #expect(col.isNew == false)
    }

    // MARK: - ColumnModel: isDirty

    @Test func columnModelNewIsDirty() {
        let col = ColumnModel(original: nil, name: "id", dataType: "integer", isNullable: false)
        #expect(col.isDirty == true)
    }

    @Test func columnModelDeletedIsDirty() {
        let snapshot = ColumnModel.Snapshot(name: "id", dataType: "integer", isNullable: false, defaultValue: nil, generatedExpression: nil)
        var col = ColumnModel(original: snapshot, name: "id", dataType: "integer", isNullable: false)
        col.isDeleted = true
        #expect(col.isDirty == true)
    }

    @Test func columnModelUnchangedIsNotDirty() {
        let snapshot = ColumnModel.Snapshot(name: "id", dataType: "integer", isNullable: false, defaultValue: nil, generatedExpression: nil)
        let col = ColumnModel(original: snapshot, name: "id", dataType: "integer", isNullable: false)
        #expect(col.isDirty == false)
    }

    // MARK: - ColumnModel: hasRename

    @Test func columnModelHasRenameWhenNameChanged() {
        let snapshot = ColumnModel.Snapshot(name: "old_name", dataType: "text", isNullable: true, defaultValue: nil, generatedExpression: nil)
        let col = ColumnModel(original: snapshot, name: "new_name", dataType: "text", isNullable: true)
        #expect(col.hasRename == true)
        #expect(col.isDirty == true)
    }

    @Test func columnModelHasRenameNewColumnReturnsFalse() {
        let col = ColumnModel(original: nil, name: "whatever", dataType: "text", isNullable: true)
        #expect(col.hasRename == false)
    }

    @Test func columnModelHasRenameUnchangedReturnsFalse() {
        let snapshot = ColumnModel.Snapshot(name: "name", dataType: "text", isNullable: true, defaultValue: nil, generatedExpression: nil)
        let col = ColumnModel(original: snapshot, name: "name", dataType: "text", isNullable: true)
        #expect(col.hasRename == false)
    }

    // MARK: - ColumnModel: hasTypeChange

    @Test func columnModelHasTypeChangeWhenTypeChanged() {
        let snapshot = ColumnModel.Snapshot(name: "col", dataType: "integer", isNullable: true, defaultValue: nil, generatedExpression: nil)
        let col = ColumnModel(original: snapshot, name: "col", dataType: "bigint", isNullable: true)
        #expect(col.hasTypeChange == true)
        #expect(col.isDirty == true)
    }

    @Test func columnModelHasTypeChangeNewColumnReturnsFalse() {
        let col = ColumnModel(original: nil, name: "col", dataType: "text", isNullable: true)
        #expect(col.hasTypeChange == false)
    }

    @Test func columnModelHasTypeChangeUnchangedReturnsFalse() {
        let snapshot = ColumnModel.Snapshot(name: "col", dataType: "text", isNullable: true, defaultValue: nil, generatedExpression: nil)
        let col = ColumnModel(original: snapshot, name: "col", dataType: "text", isNullable: true)
        #expect(col.hasTypeChange == false)
    }

    // MARK: - ColumnModel: hasNullabilityChange

    @Test func columnModelHasNullabilityChangeWhenChanged() {
        let snapshot = ColumnModel.Snapshot(name: "col", dataType: "text", isNullable: true, defaultValue: nil, generatedExpression: nil)
        let col = ColumnModel(original: snapshot, name: "col", dataType: "text", isNullable: false)
        #expect(col.hasNullabilityChange == true)
        #expect(col.isDirty == true)
    }

    @Test func columnModelHasNullabilityChangeNewColumnReturnsFalse() {
        let col = ColumnModel(original: nil, name: "col", dataType: "text", isNullable: false)
        #expect(col.hasNullabilityChange == false)
    }

    // MARK: - ColumnModel: hasDefaultChange

    @Test func columnModelHasDefaultChangeWhenChanged() {
        let snapshot = ColumnModel.Snapshot(name: "col", dataType: "text", isNullable: true, defaultValue: "hello", generatedExpression: nil)
        let col = ColumnModel(original: snapshot, name: "col", dataType: "text", isNullable: true, defaultValue: "world")
        #expect(col.hasDefaultChange == true)
        #expect(col.isDirty == true)
    }

    @Test func columnModelHasDefaultChangeAddedDefault() {
        let snapshot = ColumnModel.Snapshot(name: "col", dataType: "text", isNullable: true, defaultValue: nil, generatedExpression: nil)
        let col = ColumnModel(original: snapshot, name: "col", dataType: "text", isNullable: true, defaultValue: "newdefault")
        #expect(col.hasDefaultChange == true)
    }

    @Test func columnModelHasDefaultChangeRemovedDefault() {
        let snapshot = ColumnModel.Snapshot(name: "col", dataType: "text", isNullable: true, defaultValue: "old", generatedExpression: nil)
        let col = ColumnModel(original: snapshot, name: "col", dataType: "text", isNullable: true, defaultValue: nil)
        #expect(col.hasDefaultChange == true)
    }

    @Test func columnModelHasDefaultChangeNewColumnWithDefault() {
        let col = ColumnModel(original: nil, name: "col", dataType: "text", isNullable: true, defaultValue: "val")
        #expect(col.hasDefaultChange == true)
    }

    @Test func columnModelHasDefaultChangeNewColumnWithoutDefault() {
        let col = ColumnModel(original: nil, name: "col", dataType: "text", isNullable: true, defaultValue: nil)
        #expect(col.hasDefaultChange == false)
    }

    // MARK: - ColumnModel: hasExpressionChange

    @Test func columnModelHasExpressionChangeWhenChanged() {
        let snapshot = ColumnModel.Snapshot(name: "col", dataType: "text", isNullable: true, defaultValue: nil, generatedExpression: "old_expr")
        let col = ColumnModel(original: snapshot, name: "col", dataType: "text", isNullable: true, defaultValue: nil, generatedExpression: "new_expr")
        #expect(col.hasExpressionChange == true)
        #expect(col.isDirty == true)
    }

    @Test func columnModelHasExpressionChangeNewColumnWithExpression() {
        let col = ColumnModel(original: nil, name: "col", dataType: "text", isNullable: true, defaultValue: nil, generatedExpression: "expr")
        #expect(col.hasExpressionChange == true)
    }

    @Test func columnModelHasExpressionChangeNewColumnWithoutExpression() {
        let col = ColumnModel(original: nil, name: "col", dataType: "text", isNullable: true, defaultValue: nil, generatedExpression: nil)
        #expect(col.hasExpressionChange == false)
    }

    // MARK: - ColumnModel: referenceName

    @Test func columnModelReferenceNameUsesOriginalWhenExists() {
        let snapshot = ColumnModel.Snapshot(name: "original_name", dataType: "text", isNullable: true, defaultValue: nil, generatedExpression: nil)
        let col = ColumnModel(original: snapshot, name: "new_name", dataType: "text", isNullable: true)
        #expect(col.referenceName == "original_name")
    }

    @Test func columnModelReferenceNameUsesCurrentWhenNew() {
        let col = ColumnModel(original: nil, name: "current_name", dataType: "text", isNullable: true)
        #expect(col.referenceName == "current_name")
    }

    // MARK: - ColumnModel: multiple changes

    @Test func columnModelMultipleChangesIsDirty() {
        let snapshot = ColumnModel.Snapshot(name: "col", dataType: "integer", isNullable: true, defaultValue: nil, generatedExpression: nil)
        let col = ColumnModel(original: snapshot, name: "new_col", dataType: "bigint", isNullable: false, defaultValue: "0")
        #expect(col.hasRename == true)
        #expect(col.hasTypeChange == true)
        #expect(col.hasNullabilityChange == true)
        #expect(col.hasDefaultChange == true)
        #expect(col.isDirty == true)
    }

    // MARK: - IndexModel: isNew

    @Test func indexModelIsNewWhenNoOriginal() {
        let idx = IndexModel(original: nil, name: "idx_test", columns: [], isUnique: false, filterCondition: "")
        #expect(idx.isNew == true)
    }

    @Test func indexModelIsNotNewWhenOriginalExists() {
        let snapshot = IndexModel.Snapshot(name: "idx_test", columns: [], isUnique: false, filterCondition: nil)
        let idx = IndexModel(original: snapshot, name: "idx_test", columns: [], isUnique: false, filterCondition: "")
        #expect(idx.isNew == false)
    }

    // MARK: - IndexModel: isDirty

    @Test func indexModelNewIsDirty() {
        let idx = IndexModel(original: nil, name: "idx_test", columns: [], isUnique: false, filterCondition: "")
        #expect(idx.isDirty == true)
    }

    @Test func indexModelDeletedIsDirty() {
        let snapshot = IndexModel.Snapshot(name: "idx_test", columns: [], isUnique: false, filterCondition: nil)
        var idx = IndexModel(original: snapshot, name: "idx_test", columns: [], isUnique: false, filterCondition: "")
        idx.isDeleted = true
        #expect(idx.isDirty == true)
    }

    @Test func indexModelUnchangedIsNotDirty() {
        let snapshot = IndexModel.Snapshot(name: "idx_test", columns: [], isUnique: false, filterCondition: nil, indexType: "btree")
        let idx = IndexModel(original: snapshot, name: "idx_test", columns: [], isUnique: false, filterCondition: "")
        #expect(idx.isDirty == false)
    }

    @Test func indexModelNameChangeIsDirty() {
        let snapshot = IndexModel.Snapshot(name: "idx_old", columns: [], isUnique: false, filterCondition: nil)
        let idx = IndexModel(original: snapshot, name: "idx_new", columns: [], isUnique: false, filterCondition: "")
        #expect(idx.isDirty == true)
    }

    @Test func indexModelUniqueChangeIsDirty() {
        let snapshot = IndexModel.Snapshot(name: "idx_test", columns: [], isUnique: false, filterCondition: nil)
        let idx = IndexModel(original: snapshot, name: "idx_test", columns: [], isUnique: true, filterCondition: "")
        #expect(idx.isDirty == true)
    }

    @Test func indexModelFilterChangeIsDirty() {
        let snapshot = IndexModel.Snapshot(name: "idx_test", columns: [], isUnique: false, filterCondition: nil)
        let idx = IndexModel(original: snapshot, name: "idx_test", columns: [], isUnique: false, filterCondition: "WHERE active = true")
        #expect(idx.isDirty == true)
    }

    @Test func indexModelColumnCountChangeIsDirty() {
        let colSnap = IndexModel.Column.Snapshot(name: "col1", sortOrder: .ascending)
        let snapshot = IndexModel.Snapshot(name: "idx_test", columns: [colSnap], isUnique: false, filterCondition: nil)
        let idx = IndexModel(original: snapshot, name: "idx_test", columns: [], isUnique: false, filterCondition: "")
        #expect(idx.isDirty == true)
    }

    @Test func indexModelColumnSortOrderChangeIsDirty() {
        let colSnap = IndexModel.Column.Snapshot(name: "col1", sortOrder: .ascending)
        let snapshot = IndexModel.Snapshot(name: "idx_test", columns: [colSnap], isUnique: false, filterCondition: nil)
        let col = IndexModel.Column(name: "col1", sortOrder: .descending)
        let idx = IndexModel(original: snapshot, name: "idx_test", columns: [col], isUnique: false, filterCondition: "")
        #expect(idx.isDirty == true)
    }

    @Test func indexModelColumnNameChangeIsDirty() {
        let colSnap = IndexModel.Column.Snapshot(name: "col1", sortOrder: .ascending)
        let snapshot = IndexModel.Snapshot(name: "idx_test", columns: [colSnap], isUnique: false, filterCondition: nil)
        let col = IndexModel.Column(name: "col2", sortOrder: .ascending)
        let idx = IndexModel(original: snapshot, name: "idx_test", columns: [col], isUnique: false, filterCondition: "")
        #expect(idx.isDirty == true)
    }

    // MARK: - IndexModel.Column: SortOrder

    @Test func indexColumnSortOrderDisplayName() {
        #expect(IndexModel.Column.SortOrder.ascending.displayName == "Ascending")
        #expect(IndexModel.Column.SortOrder.descending.displayName == "Descending")
    }

    @Test func indexColumnSortOrderSqlKeyword() {
        #expect(IndexModel.Column.SortOrder.ascending.sqlKeyword == "ASC")
        #expect(IndexModel.Column.SortOrder.descending.sqlKeyword == "DESC")
    }

    @Test func indexColumnSortOrderAllCases() {
        #expect(IndexModel.Column.SortOrder.allCases.count == 2)
    }

    // MARK: - IndexModel: effectiveFilterCondition

    @Test func indexModelEffectiveFilterConditionNonEmpty() {
        let idx = IndexModel(original: nil, name: "idx", columns: [], isUnique: false, filterCondition: "WHERE x > 0")
        #expect(idx.effectiveFilterCondition == "WHERE x > 0")
    }

    @Test func indexModelEffectiveFilterConditionEmptyString() {
        let idx = IndexModel(original: nil, name: "idx", columns: [], isUnique: false, filterCondition: "")
        #expect(idx.effectiveFilterCondition == nil)
    }

    @Test func indexModelEffectiveFilterConditionWhitespace() {
        let idx = IndexModel(original: nil, name: "idx", columns: [], isUnique: false, filterCondition: "   ")
        #expect(idx.effectiveFilterCondition == nil)
    }

    // MARK: - UniqueConstraintModel: isNew

    @Test func uniqueConstraintIsNewWhenNoOriginal() {
        let uc = UniqueConstraintModel(original: nil, name: "uq_test", columns: ["col1"])
        #expect(uc.isNew == true)
    }

    @Test func uniqueConstraintIsNotNewWhenOriginalExists() {
        let snapshot = UniqueConstraintModel.Snapshot(name: "uq_test", columns: ["col1"])
        let uc = UniqueConstraintModel(original: snapshot, name: "uq_test", columns: ["col1"])
        #expect(uc.isNew == false)
    }

    // MARK: - UniqueConstraintModel: isDirty

    @Test func uniqueConstraintNewIsDirty() {
        let uc = UniqueConstraintModel(original: nil, name: "uq_test", columns: ["col1"])
        #expect(uc.isDirty == true)
    }

    @Test func uniqueConstraintDeletedIsDirty() {
        let snapshot = UniqueConstraintModel.Snapshot(name: "uq_test", columns: ["col1"])
        var uc = UniqueConstraintModel(original: snapshot, name: "uq_test", columns: ["col1"])
        uc.isDeleted = true
        #expect(uc.isDirty == true)
    }

    @Test func uniqueConstraintUnchangedIsNotDirty() {
        let snapshot = UniqueConstraintModel.Snapshot(name: "uq_test", columns: ["col1", "col2"])
        let uc = UniqueConstraintModel(original: snapshot, name: "uq_test", columns: ["col1", "col2"])
        #expect(uc.isDirty == false)
    }

    @Test func uniqueConstraintNameChangeIsDirty() {
        let snapshot = UniqueConstraintModel.Snapshot(name: "uq_old", columns: ["col1"])
        let uc = UniqueConstraintModel(original: snapshot, name: "uq_new", columns: ["col1"])
        #expect(uc.isDirty == true)
    }

    @Test func uniqueConstraintColumnsChangeIsDirty() {
        let snapshot = UniqueConstraintModel.Snapshot(name: "uq_test", columns: ["col1"])
        let uc = UniqueConstraintModel(original: snapshot, name: "uq_test", columns: ["col1", "col2"])
        #expect(uc.isDirty == true)
    }

    // MARK: - ForeignKeyModel: isNew

    @Test func foreignKeyIsNewWhenNoOriginal() {
        let fk = ForeignKeyModel(
            original: nil, name: "fk_test", columns: ["col1"],
            referencedSchema: "public", referencedTable: "other",
            referencedColumns: ["id"], onUpdate: nil, onDelete: nil
        )
        #expect(fk.isNew == true)
    }

    @Test func foreignKeyIsNotNewWhenOriginalExists() {
        let snapshot = ForeignKeyModel.Snapshot(
            name: "fk_test", columns: ["col1"],
            referencedSchema: "public", referencedTable: "other",
            referencedColumns: ["id"], onUpdate: nil, onDelete: nil
        )
        let fk = ForeignKeyModel(
            original: snapshot, name: "fk_test", columns: ["col1"],
            referencedSchema: "public", referencedTable: "other",
            referencedColumns: ["id"], onUpdate: nil, onDelete: nil
        )
        #expect(fk.isNew == false)
    }

    // MARK: - ForeignKeyModel: isDirty

    @Test func foreignKeyNewIsDirty() {
        let fk = ForeignKeyModel(
            original: nil, name: "fk_test", columns: ["col1"],
            referencedSchema: "public", referencedTable: "other",
            referencedColumns: ["id"]
        )
        #expect(fk.isDirty == true)
    }

    @Test func foreignKeyDeletedIsDirty() {
        let snapshot = ForeignKeyModel.Snapshot(
            name: "fk_test", columns: ["col1"],
            referencedSchema: "public", referencedTable: "other",
            referencedColumns: ["id"], onUpdate: nil, onDelete: nil
        )
        var fk = ForeignKeyModel(
            original: snapshot, name: "fk_test", columns: ["col1"],
            referencedSchema: "public", referencedTable: "other",
            referencedColumns: ["id"]
        )
        fk.isDeleted = true
        #expect(fk.isDirty == true)
    }

    @Test func foreignKeyUnchangedIsNotDirty() {
        let snapshot = ForeignKeyModel.Snapshot(
            name: "fk_test", columns: ["col1"],
            referencedSchema: "public", referencedTable: "other",
            referencedColumns: ["id"], onUpdate: "CASCADE", onDelete: "SET NULL"
        )
        let fk = ForeignKeyModel(
            original: snapshot, name: "fk_test", columns: ["col1"],
            referencedSchema: "public", referencedTable: "other",
            referencedColumns: ["id"], onUpdate: "CASCADE", onDelete: "SET NULL"
        )
        #expect(fk.isDirty == false)
    }

    @Test func foreignKeyNameChangeIsDirty() {
        let snapshot = ForeignKeyModel.Snapshot(
            name: "fk_old", columns: ["col1"],
            referencedSchema: "public", referencedTable: "other",
            referencedColumns: ["id"], onUpdate: nil, onDelete: nil
        )
        let fk = ForeignKeyModel(
            original: snapshot, name: "fk_new", columns: ["col1"],
            referencedSchema: "public", referencedTable: "other",
            referencedColumns: ["id"]
        )
        #expect(fk.isDirty == true)
    }

    @Test func foreignKeyColumnsChangeIsDirty() {
        let snapshot = ForeignKeyModel.Snapshot(
            name: "fk_test", columns: ["col1"],
            referencedSchema: "public", referencedTable: "other",
            referencedColumns: ["id"], onUpdate: nil, onDelete: nil
        )
        let fk = ForeignKeyModel(
            original: snapshot, name: "fk_test", columns: ["col1", "col2"],
            referencedSchema: "public", referencedTable: "other",
            referencedColumns: ["id"]
        )
        #expect(fk.isDirty == true)
    }

    @Test func foreignKeyReferencedSchemaChangeIsDirty() {
        let snapshot = ForeignKeyModel.Snapshot(
            name: "fk_test", columns: ["col1"],
            referencedSchema: "public", referencedTable: "other",
            referencedColumns: ["id"], onUpdate: nil, onDelete: nil
        )
        let fk = ForeignKeyModel(
            original: snapshot, name: "fk_test", columns: ["col1"],
            referencedSchema: "private", referencedTable: "other",
            referencedColumns: ["id"]
        )
        #expect(fk.isDirty == true)
    }

    @Test func foreignKeyReferencedTableChangeIsDirty() {
        let snapshot = ForeignKeyModel.Snapshot(
            name: "fk_test", columns: ["col1"],
            referencedSchema: "public", referencedTable: "old_table",
            referencedColumns: ["id"], onUpdate: nil, onDelete: nil
        )
        let fk = ForeignKeyModel(
            original: snapshot, name: "fk_test", columns: ["col1"],
            referencedSchema: "public", referencedTable: "new_table",
            referencedColumns: ["id"]
        )
        #expect(fk.isDirty == true)
    }

    @Test func foreignKeyOnUpdateChangeIsDirty() {
        let snapshot = ForeignKeyModel.Snapshot(
            name: "fk_test", columns: ["col1"],
            referencedSchema: "public", referencedTable: "other",
            referencedColumns: ["id"], onUpdate: nil, onDelete: nil
        )
        let fk = ForeignKeyModel(
            original: snapshot, name: "fk_test", columns: ["col1"],
            referencedSchema: "public", referencedTable: "other",
            referencedColumns: ["id"], onUpdate: "CASCADE"
        )
        #expect(fk.isDirty == true)
    }

    @Test func foreignKeyOnDeleteChangeIsDirty() {
        let snapshot = ForeignKeyModel.Snapshot(
            name: "fk_test", columns: ["col1"],
            referencedSchema: "public", referencedTable: "other",
            referencedColumns: ["id"], onUpdate: nil, onDelete: nil
        )
        let fk = ForeignKeyModel(
            original: snapshot, name: "fk_test", columns: ["col1"],
            referencedSchema: "public", referencedTable: "other",
            referencedColumns: ["id"], onDelete: "RESTRICT"
        )
        #expect(fk.isDirty == true)
    }

    // MARK: - PrimaryKeyModel: isNew

    @Test func primaryKeyIsNewWhenNoOriginal() {
        let pk = PrimaryKeyModel(original: nil, name: "pk_test", columns: ["id"])
        #expect(pk.isNew == true)
    }

    @Test func primaryKeyIsNotNewWhenOriginalExists() {
        let snapshot = PrimaryKeyModel.Snapshot(name: "pk_test", columns: ["id"])
        let pk = PrimaryKeyModel(original: snapshot, name: "pk_test", columns: ["id"])
        #expect(pk.isNew == false)
    }

    // MARK: - PrimaryKeyModel: isDirty

    @Test func primaryKeyNewIsDirty() {
        let pk = PrimaryKeyModel(original: nil, name: "pk_test", columns: ["id"])
        #expect(pk.isDirty == true)
    }

    @Test func primaryKeyUnchangedIsNotDirty() {
        let snapshot = PrimaryKeyModel.Snapshot(name: "pk_test", columns: ["id"])
        let pk = PrimaryKeyModel(original: snapshot, name: "pk_test", columns: ["id"])
        #expect(pk.isDirty == false)
    }

    @Test func primaryKeyNameChangeIsDirty() {
        let snapshot = PrimaryKeyModel.Snapshot(name: "pk_old", columns: ["id"])
        let pk = PrimaryKeyModel(original: snapshot, name: "pk_new", columns: ["id"])
        #expect(pk.isDirty == true)
    }

    @Test func primaryKeyColumnsChangeIsDirty() {
        let snapshot = PrimaryKeyModel.Snapshot(name: "pk_test", columns: ["id"])
        let pk = PrimaryKeyModel(original: snapshot, name: "pk_test", columns: ["id", "tenant_id"])
        #expect(pk.isDirty == true)
    }

    @Test func primaryKeyColumnsOrderChangeIsDirty() {
        let snapshot = PrimaryKeyModel.Snapshot(name: "pk_test", columns: ["a", "b"])
        let pk = PrimaryKeyModel(original: snapshot, name: "pk_test", columns: ["b", "a"])
        #expect(pk.isDirty == true)
    }

    // MARK: - ColumnModel: identity changes

    @Test func columnModelHasIdentityChangeWhenIdentityAdded() {
        let snapshot = ColumnModel.Snapshot(name: "id", dataType: "integer", isNullable: false, defaultValue: nil, generatedExpression: nil, isIdentity: false, identitySeed: nil, identityIncrement: nil, identityGeneration: nil, collation: nil)
        let col = ColumnModel(original: snapshot, name: "id", dataType: "integer", isNullable: false, isIdentity: true, identitySeed: 1, identityIncrement: 1)
        #expect(col.hasIdentityChange == true)
    }

    @Test func columnModelHasIdentityChangeWhenSeedChanged() {
        let snapshot = ColumnModel.Snapshot(name: "id", dataType: "integer", isNullable: false, defaultValue: nil, generatedExpression: nil, isIdentity: true, identitySeed: 1, identityIncrement: 1, identityGeneration: nil, collation: nil)
        let col = ColumnModel(original: snapshot, name: "id", dataType: "integer", isNullable: false, isIdentity: true, identitySeed: 100, identityIncrement: 1)
        #expect(col.hasIdentityChange == true)
    }

    @Test func columnModelHasIdentityChangeUnchanged() {
        let snapshot = ColumnModel.Snapshot(name: "id", dataType: "integer", isNullable: false, defaultValue: nil, generatedExpression: nil, isIdentity: true, identitySeed: 1, identityIncrement: 1, identityGeneration: nil, collation: nil)
        let col = ColumnModel(original: snapshot, name: "id", dataType: "integer", isNullable: false, isIdentity: true, identitySeed: 1, identityIncrement: 1)
        #expect(col.hasIdentityChange == false)
    }

    // MARK: - ColumnModel: collation changes

    @Test func columnModelHasCollationChangeWhenChanged() {
        let snapshot = ColumnModel.Snapshot(name: "name", dataType: "text", isNullable: true, defaultValue: nil, generatedExpression: nil, isIdentity: false, identitySeed: nil, identityIncrement: nil, identityGeneration: nil, collation: nil)
        let col = ColumnModel(original: snapshot, name: "name", dataType: "text", isNullable: true, collation: "en_US.utf8")
        #expect(col.hasCollationChange == true)
    }

    @Test func columnModelHasCollationChangeUnchanged() {
        let snapshot = ColumnModel.Snapshot(name: "name", dataType: "text", isNullable: true, defaultValue: nil, generatedExpression: nil, isIdentity: false, identitySeed: nil, identityIncrement: nil, identityGeneration: nil, collation: "en_US.utf8")
        let col = ColumnModel(original: snapshot, name: "name", dataType: "text", isNullable: true, collation: "en_US.utf8")
        #expect(col.hasCollationChange == false)
    }

    @Test func columnModelIdentityChangeMakesDirty() {
        let snapshot = ColumnModel.Snapshot(name: "id", dataType: "integer", isNullable: false, defaultValue: nil, generatedExpression: nil, isIdentity: false, identitySeed: nil, identityIncrement: nil, identityGeneration: nil, collation: nil)
        let col = ColumnModel(original: snapshot, name: "id", dataType: "integer", isNullable: false, isIdentity: true, identitySeed: 1, identityIncrement: 1)
        #expect(col.isDirty == true)
    }

    @Test func columnModelCollationChangeMakesDirty() {
        let snapshot = ColumnModel.Snapshot(name: "name", dataType: "text", isNullable: true, defaultValue: nil, generatedExpression: nil, isIdentity: false, identitySeed: nil, identityIncrement: nil, identityGeneration: nil, collation: nil)
        let col = ColumnModel(original: snapshot, name: "name", dataType: "text", isNullable: true, collation: "en_US.utf8")
        #expect(col.isDirty == true)
    }

    // MARK: - IndexModel: isIncluded & indexType changes

    @Test func indexModelIsIncludedColumnChangeIsDirty() {
        let colSnap = IndexModel.Column.Snapshot(name: "col1", sortOrder: .ascending, isIncluded: false)
        let snapshot = IndexModel.Snapshot(name: "idx_test", columns: [colSnap], isUnique: false, filterCondition: nil, indexType: nil)
        let col = IndexModel.Column(name: "col1", sortOrder: .ascending, isIncluded: true)
        let idx = IndexModel(original: snapshot, name: "idx_test", columns: [col], isUnique: false, filterCondition: "", indexType: "")
        #expect(idx.isDirty == true)
    }

    @Test func indexModelIndexTypeChangeIsDirty() {
        let snapshot = IndexModel.Snapshot(name: "idx_test", columns: [], isUnique: false, filterCondition: nil, indexType: "btree")
        let idx = IndexModel(original: snapshot, name: "idx_test", columns: [], isUnique: false, filterCondition: "", indexType: "gin")
        #expect(idx.isDirty == true)
    }

    @Test func indexModelIndexTypeUnchangedIsNotDirty() {
        let snapshot = IndexModel.Snapshot(name: "idx_test", columns: [], isUnique: false, filterCondition: nil, indexType: "btree")
        let idx = IndexModel(original: snapshot, name: "idx_test", columns: [], isUnique: false, filterCondition: "", indexType: "btree")
        #expect(idx.isDirty == false)
    }

    // MARK: - UniqueConstraintModel: deferrable

    @Test func uniqueConstraintDeferrableChangeIsDirty() {
        let snapshot = UniqueConstraintModel.Snapshot(name: "uq_test", columns: ["col1"], isDeferrable: false, isInitiallyDeferred: false)
        let uc = UniqueConstraintModel(original: snapshot, name: "uq_test", columns: ["col1"], isDeferrable: true, isInitiallyDeferred: false)
        #expect(uc.isDirty == true)
    }

    @Test func uniqueConstraintDeferrableUnchangedIsNotDirty() {
        let snapshot = UniqueConstraintModel.Snapshot(name: "uq_test", columns: ["col1"], isDeferrable: true, isInitiallyDeferred: true)
        let uc = UniqueConstraintModel(original: snapshot, name: "uq_test", columns: ["col1"], isDeferrable: true, isInitiallyDeferred: true)
        #expect(uc.isDirty == false)
    }

    // MARK: - ForeignKeyModel: deferrable

    @Test func foreignKeyDeferrableChangeIsDirty() {
        let snapshot = ForeignKeyModel.Snapshot(
            name: "fk_test", columns: ["col1"],
            referencedSchema: "public", referencedTable: "other",
            referencedColumns: ["id"], onUpdate: nil, onDelete: nil,
            isDeferrable: false, isInitiallyDeferred: false
        )
        let fk = ForeignKeyModel(
            original: snapshot, name: "fk_test", columns: ["col1"],
            referencedSchema: "public", referencedTable: "other",
            referencedColumns: ["id"], isDeferrable: true, isInitiallyDeferred: true
        )
        #expect(fk.isDirty == true)
    }

    @Test func foreignKeyDeferrableUnchangedIsNotDirty() {
        let snapshot = ForeignKeyModel.Snapshot(
            name: "fk_test", columns: ["col1"],
            referencedSchema: "public", referencedTable: "other",
            referencedColumns: ["id"], onUpdate: nil, onDelete: nil,
            isDeferrable: true, isInitiallyDeferred: true
        )
        let fk = ForeignKeyModel(
            original: snapshot, name: "fk_test", columns: ["col1"],
            referencedSchema: "public", referencedTable: "other",
            referencedColumns: ["id"], isDeferrable: true, isInitiallyDeferred: true
        )
        #expect(fk.isDirty == false)
    }

    // MARK: - PrimaryKeyModel: deferrable

    @Test func primaryKeyDeferrableChangeIsDirty() {
        let snapshot = PrimaryKeyModel.Snapshot(name: "pk_test", columns: ["id"], isDeferrable: false, isInitiallyDeferred: false)
        let pk = PrimaryKeyModel(original: snapshot, name: "pk_test", columns: ["id"], isDeferrable: true, isInitiallyDeferred: true)
        #expect(pk.isDirty == true)
    }

    @Test func primaryKeyDeferrableUnchangedIsNotDirty() {
        let snapshot = PrimaryKeyModel.Snapshot(name: "pk_test", columns: ["id"], isDeferrable: true, isInitiallyDeferred: true)
        let pk = PrimaryKeyModel(original: snapshot, name: "pk_test", columns: ["id"], isDeferrable: true, isInitiallyDeferred: true)
        #expect(pk.isDirty == false)
    }

    // MARK: - CheckConstraintModel

    @Test func checkConstraintIsNewWhenNoOriginal() {
        let cc = CheckConstraintModel(original: nil, name: "chk_age", expression: "age >= 0")
        #expect(cc.isNew == true)
    }

    @Test func checkConstraintIsNotNewWhenOriginalExists() {
        let snapshot = CheckConstraintModel.Snapshot(name: "chk_age", expression: "age >= 0")
        let cc = CheckConstraintModel(original: snapshot, name: "chk_age", expression: "age >= 0")
        #expect(cc.isNew == false)
    }

    @Test func checkConstraintNewIsDirty() {
        let cc = CheckConstraintModel(original: nil, name: "chk_age", expression: "age >= 0")
        #expect(cc.isDirty == true)
    }

    @Test func checkConstraintDeletedIsDirty() {
        let snapshot = CheckConstraintModel.Snapshot(name: "chk_age", expression: "age >= 0")
        var cc = CheckConstraintModel(original: snapshot, name: "chk_age", expression: "age >= 0")
        cc.isDeleted = true
        #expect(cc.isDirty == true)
    }

    @Test func checkConstraintUnchangedIsNotDirty() {
        let snapshot = CheckConstraintModel.Snapshot(name: "chk_age", expression: "age >= 0")
        let cc = CheckConstraintModel(original: snapshot, name: "chk_age", expression: "age >= 0")
        #expect(cc.isDirty == false)
    }

    @Test func checkConstraintNameChangeIsDirty() {
        let snapshot = CheckConstraintModel.Snapshot(name: "chk_old", expression: "age >= 0")
        let cc = CheckConstraintModel(original: snapshot, name: "chk_new", expression: "age >= 0")
        #expect(cc.isDirty == true)
    }

    @Test func checkConstraintExpressionChangeIsDirty() {
        let snapshot = CheckConstraintModel.Snapshot(name: "chk_age", expression: "age >= 0")
        let cc = CheckConstraintModel(original: snapshot, name: "chk_age", expression: "age >= 18")
        #expect(cc.isDirty == true)
    }
}
