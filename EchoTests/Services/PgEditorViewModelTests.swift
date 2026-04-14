import Testing
import Foundation
@testable import Echo

// MARK: - TriggerEditorViewModel Tests

@Suite("TriggerEditorViewModel")
struct TriggerEditorViewModelTests {

    // MARK: - Init & Editing State

    @Test func newTriggerIsNotEditing() {
        let vm = TriggerEditorViewModel(connectionSessionID: UUID(), schemaName: "public", tableName: "orders", existingTriggerName: nil, dialect: PostgresTriggerDialect())
        #expect(vm.isEditing == false)
        #expect(vm.triggerName == "")
    }

    @Test func existingTriggerIsEditing() {
        let vm = TriggerEditorViewModel(connectionSessionID: UUID(), schemaName: "public", tableName: "orders", existingTriggerName: "audit_trigger", dialect: PostgresTriggerDialect())
        #expect(vm.isEditing == true)
        #expect(vm.triggerName == "audit_trigger")
    }

    // MARK: - Validation

    @Test func formInvalidWhenNameEmpty() {
        let vm = TriggerEditorViewModel(connectionSessionID: UUID(), schemaName: "public", tableName: "orders", existingTriggerName: nil, dialect: PostgresTriggerDialect())
        vm.functionName = "log_changes"
        vm.onInsert = true
        #expect(vm.isFormValid == false)
    }

    @Test func formInvalidWhenFunctionEmpty() {
        let vm = TriggerEditorViewModel(connectionSessionID: UUID(), schemaName: "public", tableName: "orders", existingTriggerName: nil, dialect: PostgresTriggerDialect())
        vm.triggerName = "my_trigger"
        vm.onInsert = true
        #expect(vm.isFormValid == false)
    }

    @Test func formInvalidWhenNoEventsSelected() {
        let vm = TriggerEditorViewModel(connectionSessionID: UUID(), schemaName: "public", tableName: "orders", existingTriggerName: nil, dialect: PostgresTriggerDialect())
        vm.triggerName = "my_trigger"
        vm.functionName = "log_changes"
        vm.onInsert = false
        vm.onUpdate = false
        vm.onDelete = false
        vm.onTruncate = false
        #expect(vm.isFormValid == false)
    }

    @Test func formValidWithRequiredFields() {
        let vm = TriggerEditorViewModel(connectionSessionID: UUID(), schemaName: "public", tableName: "orders", existingTriggerName: nil, dialect: PostgresTriggerDialect())
        vm.triggerName = "my_trigger"
        vm.functionName = "log_changes"
        vm.onInsert = true
        #expect(vm.isFormValid == true)
    }

    // MARK: - Dirty Tracking

    @Test func noChangesAfterSnapshot() {
        let vm = TriggerEditorViewModel(connectionSessionID: UUID(), schemaName: "public", tableName: "orders", existingTriggerName: "existing", dialect: PostgresTriggerDialect())
        vm.functionName = "fn"
        vm.takeSnapshot()
        #expect(vm.hasChanges == false)
    }

    @Test func detectsChangesAfterSnapshot() {
        let vm = TriggerEditorViewModel(connectionSessionID: UUID(), schemaName: "public", tableName: "orders", existingTriggerName: "existing", dialect: PostgresTriggerDialect())
        vm.functionName = "fn"
        vm.takeSnapshot()
        vm.functionName = "fn_changed"
        #expect(vm.hasChanges == true)
    }

    @Test func detectsTimingChange() {
        let vm = TriggerEditorViewModel(connectionSessionID: UUID(), schemaName: "public", tableName: "orders", existingTriggerName: "existing", dialect: PostgresTriggerDialect())
        vm.takeSnapshot()
        vm.timing = .before
        #expect(vm.hasChanges == true)
    }

    // MARK: - SQL Generation

    @Test func generatesSQLForNewTrigger() {
        let vm = TriggerEditorViewModel(connectionSessionID: UUID(), schemaName: "public", tableName: "orders", existingTriggerName: nil, dialect: PostgresTriggerDialect())
        vm.triggerName = "audit_trigger"
        vm.functionName = "log_changes"
        vm.timing = .after
        vm.onInsert = true
        vm.onUpdate = true
        vm.onDelete = false
        vm.forEach = .row

        let sql = vm.generateSQL()
        #expect(sql.contains("CREATE TRIGGER"))
        #expect(sql.contains("\"audit_trigger\""))
        #expect(sql.contains("AFTER INSERT OR UPDATE"))
        #expect(sql.contains("FOR EACH ROW"))
        #expect(sql.contains("log_changes()"))
        #expect(!sql.contains("DROP TRIGGER"))
    }

    @Test func generatesSQLWithDropForExistingTrigger() {
        let vm = TriggerEditorViewModel(connectionSessionID: UUID(), schemaName: "public", tableName: "orders", existingTriggerName: "audit_trigger", dialect: PostgresTriggerDialect())
        vm.functionName = "log_changes"
        vm.onInsert = true

        let sql = vm.generateSQL()
        #expect(sql.contains("DROP TRIGGER IF EXISTS"))
        #expect(sql.contains("CREATE TRIGGER"))
    }

    @Test func generatesSQLWithWhenCondition() {
        let vm = TriggerEditorViewModel(connectionSessionID: UUID(), schemaName: "public", tableName: "orders", existingTriggerName: nil, dialect: PostgresTriggerDialect())
        vm.triggerName = "check_trigger"
        vm.functionName = "check_fn"
        vm.onUpdate = true
        vm.whenCondition = "OLD.status IS DISTINCT FROM NEW.status"

        let sql = vm.generateSQL()
        #expect(sql.contains("WHEN (OLD.status IS DISTINCT FROM NEW.status)"))
    }

    @Test func generatesSQLWithDisabledTrigger() {
        let vm = TriggerEditorViewModel(connectionSessionID: UUID(), schemaName: "public", tableName: "orders", existingTriggerName: "audit_trigger", dialect: PostgresTriggerDialect())
        vm.functionName = "log_changes"
        vm.onInsert = true
        vm.isEnabled = false

        let sql = vm.generateSQL()
        #expect(sql.contains("DISABLE TRIGGER"))
    }

    @Test func generatesSQLWithComment() {
        let vm = TriggerEditorViewModel(connectionSessionID: UUID(), schemaName: "public", tableName: "orders", existingTriggerName: nil, dialect: PostgresTriggerDialect())
        vm.triggerName = "audit_trigger"
        vm.functionName = "log_changes"
        vm.onInsert = true
        vm.description = "Audit changes"

        let sql = vm.generateSQL()
        #expect(sql.contains("COMMENT ON TRIGGER"))
        #expect(sql.contains("Audit changes"))
    }
}

// MARK: - ViewEditorViewModel Tests

@Suite("ViewEditorViewModel")
struct ViewEditorViewModelTests {

    @Test func newViewIsNotEditing() {
        let vm = ViewEditorViewModel(connectionSessionID: UUID(), schemaName: "public", existingViewName: nil, isMaterialized: false, dialect: PostgresViewDialect())
        #expect(vm.isEditing == false)
    }

    @Test func existingViewIsEditing() {
        let vm = ViewEditorViewModel(connectionSessionID: UUID(), schemaName: "public", existingViewName: "active_users", isMaterialized: false, dialect: PostgresViewDialect())
        #expect(vm.isEditing == true)
        #expect(vm.viewName == "active_users")
    }

    @Test func formInvalidWhenNameEmpty() {
        let vm = ViewEditorViewModel(connectionSessionID: UUID(), schemaName: "public", existingViewName: nil, isMaterialized: false, dialect: PostgresViewDialect())
        vm.definition = "SELECT * FROM users"
        #expect(vm.isFormValid == false)
    }

    @Test func formInvalidWhenDefinitionEmpty() {
        let vm = ViewEditorViewModel(connectionSessionID: UUID(), schemaName: "public", existingViewName: nil, isMaterialized: false, dialect: PostgresViewDialect())
        vm.viewName = "my_view"
        #expect(vm.isFormValid == false)
    }

    @Test func formValidWithRequiredFields() {
        let vm = ViewEditorViewModel(connectionSessionID: UUID(), schemaName: "public", existingViewName: nil, isMaterialized: false, dialect: PostgresViewDialect())
        vm.viewName = "my_view"
        vm.definition = "SELECT * FROM users"
        #expect(vm.isFormValid == true)
    }

    @Test func dirtyTrackingWorks() {
        let vm = ViewEditorViewModel(connectionSessionID: UUID(), schemaName: "public", existingViewName: "v", isMaterialized: false, dialect: PostgresViewDialect())
        vm.definition = "SELECT 1"
        vm.takeSnapshot()
        #expect(vm.hasChanges == false)
        vm.definition = "SELECT 2"
        #expect(vm.hasChanges == true)
    }

    @Test func generatesSQLForNewView() {
        let vm = ViewEditorViewModel(connectionSessionID: UUID(), schemaName: "public", existingViewName: nil, isMaterialized: false, dialect: PostgresViewDialect())
        vm.viewName = "active_users"
        vm.definition = "SELECT * FROM users WHERE active = true"

        let sql = vm.generateSQL()
        #expect(sql.contains("CREATE OR REPLACE VIEW"))
        #expect(sql.contains("\"active_users\""))
        #expect(sql.contains("SELECT * FROM users WHERE active = true"))
    }

    @Test func generatesSQLForNewMaterializedView() {
        let vm = ViewEditorViewModel(connectionSessionID: UUID(), schemaName: "public", existingViewName: nil, isMaterialized: true, dialect: PostgresViewDialect())
        vm.viewName = "cached_stats"
        vm.definition = "SELECT count(*) FROM events"

        let sql = vm.generateSQL()
        #expect(sql.contains("CREATE MATERIALIZED VIEW"))
        #expect(!sql.contains("CREATE OR REPLACE"))
    }

    @Test func generatesSQLWithOwnerForExistingView() {
        let vm = ViewEditorViewModel(connectionSessionID: UUID(), schemaName: "public", existingViewName: "v", isMaterialized: false, dialect: PostgresViewDialect())
        vm.definition = "SELECT 1"
        vm.owner = "admin"

        let sql = vm.generateSQL()
        #expect(sql.contains("ALTER VIEW"))
        #expect(sql.contains("OWNER TO"))
    }
}

// MARK: - SequenceEditorViewModel Tests

@Suite("SequenceEditorViewModel")
struct SequenceEditorViewModelTests {

    @Test func newSequenceIsNotEditing() {
        let vm = SequenceEditorViewModel(connectionSessionID: UUID(), schemaName: "public", existingSequenceName: nil, dialect: PostgresSequenceDialect())
        #expect(vm.isEditing == false)
    }

    @Test func existingSequenceIsEditing() {
        let vm = SequenceEditorViewModel(connectionSessionID: UUID(), schemaName: "public", existingSequenceName: "order_seq", dialect: PostgresSequenceDialect())
        #expect(vm.isEditing == true)
        #expect(vm.sequenceName == "order_seq")
    }

    @Test func formInvalidWhenNameEmpty() {
        let vm = SequenceEditorViewModel(connectionSessionID: UUID(), schemaName: "public", existingSequenceName: nil, dialect: PostgresSequenceDialect())
        #expect(vm.isFormValid == false)
    }

    @Test func formValidWithName() {
        let vm = SequenceEditorViewModel(connectionSessionID: UUID(), schemaName: "public", existingSequenceName: nil, dialect: PostgresSequenceDialect())
        vm.sequenceName = "my_seq"
        #expect(vm.isFormValid == true)
    }

    @Test func dirtyTrackingDetectsIncrementChange() {
        let vm = SequenceEditorViewModel(connectionSessionID: UUID(), schemaName: "public", existingSequenceName: "seq", dialect: PostgresSequenceDialect())
        vm.takeSnapshot()
        vm.incrementBy = "5"
        #expect(vm.hasChanges == true)
    }

    @Test func dirtyTrackingDetectsCycleChange() {
        let vm = SequenceEditorViewModel(connectionSessionID: UUID(), schemaName: "public", existingSequenceName: "seq", dialect: PostgresSequenceDialect())
        vm.takeSnapshot()
        vm.cycle = true
        #expect(vm.hasChanges == true)
    }

    @Test func generatesSQLForNewSequence() {
        let vm = SequenceEditorViewModel(connectionSessionID: UUID(), schemaName: "public", existingSequenceName: nil, dialect: PostgresSequenceDialect())
        vm.sequenceName = "order_seq"
        vm.startWith = "100"
        vm.incrementBy = "10"
        vm.cycle = true

        let sql = vm.generateSQL()
        #expect(sql.contains("CREATE SEQUENCE"))
        #expect(sql.contains("START WITH 100"))
        #expect(sql.contains("INCREMENT BY 10"))
        #expect(sql.contains("CYCLE"))
    }

    @Test func generatesSQLForAlterSequence() {
        let vm = SequenceEditorViewModel(connectionSessionID: UUID(), schemaName: "public", existingSequenceName: "order_seq", dialect: PostgresSequenceDialect())
        vm.incrementBy = "5"
        vm.cycle = false

        let sql = vm.generateSQL()
        #expect(sql.contains("ALTER SEQUENCE"))
        #expect(sql.contains("INCREMENT BY 5"))
        #expect(sql.contains("NO CYCLE"))
    }

    @Test func generatesSQLWithOwner() {
        let vm = SequenceEditorViewModel(connectionSessionID: UUID(), schemaName: "public", existingSequenceName: "order_seq", dialect: PostgresSequenceDialect())
        vm.owner = "admin"
        vm.incrementBy = "1"

        let sql = vm.generateSQL()
        #expect(sql.contains("OWNER TO"))
    }
}

// MARK: - TypeEditorViewModel Tests

@Suite("TypeEditorViewModel")
struct TypeEditorViewModelTests {

    // MARK: - Composite

    @Test func newCompositeIsNotEditing() {
        let vm = TypeEditorViewModel(connectionSessionID: UUID(), schemaName: "public", existingTypeName: nil, typeCategory: .composite, dialect: PostgresTypeDialect())
        #expect(vm.isEditing == false)
        #expect(vm.typeCategory == .composite)
    }

    @Test func compositeFormInvalidWithoutAttributes() {
        let vm = TypeEditorViewModel(connectionSessionID: UUID(), schemaName: "public", existingTypeName: nil, typeCategory: .composite, dialect: PostgresTypeDialect())
        vm.typeName = "my_type"
        // Default attributes have empty name/dataType
        #expect(vm.isFormValid == false)
    }

    @Test func compositeFormValidWithAttribute() {
        let vm = TypeEditorViewModel(connectionSessionID: UUID(), schemaName: "public", existingTypeName: nil, typeCategory: .composite, dialect: PostgresTypeDialect())
        vm.typeName = "address"
        vm.attributes = [TypeAttributeDraft(name: "street", dataType: "text")]
        #expect(vm.isFormValid == true)
    }

    @Test func compositeGeneratesCreateSQL() {
        let vm = TypeEditorViewModel(connectionSessionID: UUID(), schemaName: "public", existingTypeName: nil, typeCategory: .composite, dialect: PostgresTypeDialect())
        vm.typeName = "address"
        vm.attributes = [
            TypeAttributeDraft(name: "street", dataType: "text"),
            TypeAttributeDraft(name: "city", dataType: "text")
        ]

        let sql = vm.generateSQL()
        #expect(sql.contains("CREATE TYPE"))
        #expect(sql.contains("\"street\" text"))
        #expect(sql.contains("\"city\" text"))
    }

    // MARK: - Enum

    @Test func enumFormInvalidWithoutValues() {
        let vm = TypeEditorViewModel(connectionSessionID: UUID(), schemaName: "public", existingTypeName: nil, typeCategory: .enum, dialect: PostgresTypeDialect())
        vm.typeName = "status"
        // Default enum values have empty value
        #expect(vm.isFormValid == false)
    }

    @Test func enumFormValidWithValue() {
        let vm = TypeEditorViewModel(connectionSessionID: UUID(), schemaName: "public", existingTypeName: nil, typeCategory: .enum, dialect: PostgresTypeDialect())
        vm.typeName = "status"
        vm.enumValues = [EnumValueDraft(value: "active")]
        #expect(vm.isFormValid == true)
    }

    @Test func enumGeneratesCreateSQL() {
        let vm = TypeEditorViewModel(connectionSessionID: UUID(), schemaName: "public", existingTypeName: nil, typeCategory: .enum, dialect: PostgresTypeDialect())
        vm.typeName = "status"
        vm.enumValues = [
            EnumValueDraft(value: "active"),
            EnumValueDraft(value: "inactive")
        ]

        let sql = vm.generateSQL()
        #expect(sql.contains("CREATE TYPE"))
        #expect(sql.contains("AS ENUM"))
        #expect(sql.contains("'active'"))
        #expect(sql.contains("'inactive'"))
    }

    @Test func enumGeneratesAlterSQL() {
        let vm = TypeEditorViewModel(connectionSessionID: UUID(), schemaName: "public", existingTypeName: "status", typeCategory: .enum, dialect: PostgresTypeDialect())
        vm.enumValues = [EnumValueDraft(value: "pending")]

        let sql = vm.generateSQL()
        #expect(sql.contains("ADD VALUE IF NOT EXISTS"))
        #expect(sql.contains("'pending'"))
    }

    // MARK: - Range

    @Test func rangeFormInvalidWithoutSubtype() {
        let vm = TypeEditorViewModel(connectionSessionID: UUID(), schemaName: "public", existingTypeName: nil, typeCategory: .range, dialect: PostgresTypeDialect())
        vm.typeName = "my_range"
        #expect(vm.isFormValid == false)
    }

    @Test func rangeFormValidWithSubtype() {
        let vm = TypeEditorViewModel(connectionSessionID: UUID(), schemaName: "public", existingTypeName: nil, typeCategory: .range, dialect: PostgresTypeDialect())
        vm.typeName = "int_range"
        vm.subtype = "integer"
        #expect(vm.isFormValid == true)
    }

    @Test func rangeGeneratesCreateSQL() {
        let vm = TypeEditorViewModel(connectionSessionID: UUID(), schemaName: "public", existingTypeName: nil, typeCategory: .range, dialect: PostgresTypeDialect())
        vm.typeName = "ts_range"
        vm.subtype = "timestamp"

        let sql = vm.generateSQL()
        #expect(sql.contains("CREATE TYPE"))
        #expect(sql.contains("AS RANGE"))
        #expect(sql.contains("subtype = timestamp"))
    }

    // MARK: - Domain

    @Test func domainFormInvalidWithoutBaseType() {
        let vm = TypeEditorViewModel(connectionSessionID: UUID(), schemaName: "public", existingTypeName: nil, typeCategory: .domain, dialect: PostgresTypeDialect())
        vm.typeName = "email"
        #expect(vm.isFormValid == false)
    }

    @Test func domainFormValidWithBaseType() {
        let vm = TypeEditorViewModel(connectionSessionID: UUID(), schemaName: "public", existingTypeName: nil, typeCategory: .domain, dialect: PostgresTypeDialect())
        vm.typeName = "email"
        vm.baseDataType = "text"
        #expect(vm.isFormValid == true)
    }

    @Test func domainGeneratesCreateSQL() {
        let vm = TypeEditorViewModel(connectionSessionID: UUID(), schemaName: "public", existingTypeName: nil, typeCategory: .domain, dialect: PostgresTypeDialect())
        vm.typeName = "positive_int"
        vm.baseDataType = "integer"
        vm.isNotNull = true
        vm.domainConstraints = [DomainConstraintDraft(name: "positive", expression: "VALUE > 0")]

        let sql = vm.generateSQL()
        #expect(sql.contains("CREATE DOMAIN"))
        #expect(sql.contains("AS integer"))
        #expect(sql.contains("NOT NULL"))
        #expect(sql.contains("CONSTRAINT \"positive\" CHECK (VALUE > 0)"))
    }

    @Test func domainGeneratesAlterSQL() {
        let vm = TypeEditorViewModel(connectionSessionID: UUID(), schemaName: "public", existingTypeName: "email", typeCategory: .domain, dialect: PostgresTypeDialect())
        vm.baseDataType = "text"
        vm.defaultValue = "'unknown@example.com'"
        vm.isNotNull = true

        let sql = vm.generateSQL()
        #expect(sql.contains("ALTER DOMAIN"))
        #expect(sql.contains("SET DEFAULT"))
        #expect(sql.contains("SET NOT NULL"))
    }

    // MARK: - Dirty Tracking

    @Test func dirtyTrackingForComposite() {
        let vm = TypeEditorViewModel(connectionSessionID: UUID(), schemaName: "public", existingTypeName: "addr", typeCategory: .composite, dialect: PostgresTypeDialect())
        vm.attributes = [TypeAttributeDraft(name: "street", dataType: "text")]
        vm.takeSnapshot()
        #expect(vm.hasChanges == false)
        vm.attributes.append(TypeAttributeDraft(name: "city", dataType: "text"))
        #expect(vm.hasChanges == true)
    }

    @Test func dirtyTrackingForEnum() {
        let vm = TypeEditorViewModel(connectionSessionID: UUID(), schemaName: "public", existingTypeName: "status", typeCategory: .enum, dialect: PostgresTypeDialect())
        vm.enumValues = [EnumValueDraft(value: "active")]
        vm.takeSnapshot()
        #expect(vm.hasChanges == false)
        vm.enumValues[0].value = "changed"
        #expect(vm.hasChanges == true)
    }

    @Test func dirtyTrackingForDomain() {
        let vm = TypeEditorViewModel(connectionSessionID: UUID(), schemaName: "public", existingTypeName: "email", typeCategory: .domain, dialect: PostgresTypeDialect())
        vm.baseDataType = "text"
        vm.takeSnapshot()
        #expect(vm.hasChanges == false)
        vm.isNotNull = true
        #expect(vm.hasChanges == true)
    }
}
