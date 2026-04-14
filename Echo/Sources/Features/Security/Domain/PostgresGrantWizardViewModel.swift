import Foundation
import Observation
import PostgresKit

@Observable
final class PostgresGrantWizardViewModel {

    // MARK: - Types

    enum Step: Int, CaseIterable {
        case objects = 0
        case privileges = 1
        case review = 2

        var title: String {
            switch self {
            case .objects: "Select Objects"
            case .privileges: "Privileges"
            case .review: "Review"
            }
        }
    }

    enum ObjectType: String, CaseIterable, Identifiable {
        case tables = "Tables"
        case sequences = "Sequences"
        case functions = "Functions"
        case schemas = "Schemas"

        var id: String { rawValue }

        var availablePrivileges: [PostgresPrivilege] {
            switch self {
            case .tables: [.select, .insert, .update, .delete, .truncate, .references, .trigger, .all]
            case .sequences: [.usage, .select, .update, .all]
            case .functions: [.execute, .all]
            case .schemas: [.create, .usage, .all]
            }
        }

        var sqlKeyword: String {
            switch self {
            case .tables: "TABLE"
            case .sequences: "SEQUENCE"
            case .functions: "FUNCTION"
            case .schemas: "SCHEMA"
            }
        }
    }

    // MARK: - State

    var currentStep: Step = .objects

    // Step 1 — Objects
    var availableSchemas: [String] = []
    var selectedSchema: String = "public"
    var objectType: ObjectType = .tables
    var availableObjects: [String] = []
    var selectedObjects: Set<String> = []
    var isLoadingObjects = false

    // Step 2 — Privileges
    var selectedPrivileges: Set<PostgresPrivilege> = []
    var grantee: String = ""
    var withGrantOption = false

    // Step 3 — Review
    var isApplying = false
    var errorMessage: String?

    @ObservationIgnored var activityEngine: ActivityEngine?
    @ObservationIgnored private(set) var panelState: BottomPanelState?
    let connectionSessionID: UUID

    // MARK: - Computed

    var canProceedFromObjects: Bool {
        !selectedObjects.isEmpty
    }

    var canProceedFromPrivileges: Bool {
        !selectedPrivileges.isEmpty
            && !grantee.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canApply: Bool {
        canProceedFromObjects && canProceedFromPrivileges && !isApplying
    }

    var generatedSQL: String {
        generateSQL()
    }

    // MARK: - Init

    init(connectionSessionID: UUID) {
        self.connectionSessionID = connectionSessionID
    }

    func setPanelState(_ state: BottomPanelState) {
        self.panelState = state
    }

    // MARK: - Navigation

    func goNext() {
        guard let nextIndex = Step(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = nextIndex
    }

    func goBack() {
        guard let prevIndex = Step(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = prevIndex
    }

    // MARK: - Data Loading

    func loadSchemas(session: DatabaseSession) async {
        guard let pg = session as? PostgresSession else { return }
        do {
            availableSchemas = try await pg.client.metadata.listSchemas().map(\.name)
            if !availableSchemas.contains(selectedSchema), let first = availableSchemas.first {
                selectedSchema = first
            }
        } catch {
            panelState?.appendMessage("Failed to load schemas: \(error.localizedDescription)", severity: .error)
        }
    }

    func loadObjects(session: DatabaseSession) async {
        guard let pg = session as? PostgresSession else { return }
        isLoadingObjects = true
        defer { isLoadingObjects = false }

        do {
            switch objectType {
            case .tables:
                let objects = try await pg.client.metadata.listTablesAndViews(schema: selectedSchema)
                availableObjects = objects.filter { $0.kind == .table }.map(\.name).sorted()
            case .sequences:
                let seqs = try await pg.client.metadata.listSequences(schema: selectedSchema)
                availableObjects = seqs.map(\.name).sorted()
            case .functions:
                let rows = try await pg.client.simpleQuery("""
                    SELECT routine_name FROM information_schema.routines \
                    WHERE routine_schema = '\(selectedSchema)' AND routine_type = 'FUNCTION' \
                    ORDER BY routine_name
                    """)
                var names: [String] = []
                for try await name in rows.decode(String.self) {
                    names.append(name)
                }
                availableObjects = names
            case .schemas:
                availableObjects = availableSchemas.sorted()
            }
            selectedObjects = []
        } catch {
            panelState?.appendMessage("Failed to load objects: \(error.localizedDescription)", severity: .error)
            availableObjects = []
        }
    }

    // MARK: - SQL Generation

    func generateSQL() -> String {
        guard !selectedObjects.isEmpty, !selectedPrivileges.isEmpty else { return "-- No privileges selected" }

        let trimmedGrantee = grantee.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedGrantee.isEmpty else { return "-- No grantee specified" }

        let privList: String
        if selectedPrivileges.contains(.all) {
            privList = "ALL PRIVILEGES"
        } else {
            privList = selectedPrivileges.map(\.rawValue).sorted().joined(separator: ", ")
        }

        let quotedGrantee = ScriptingActions.pgQuote(trimmedGrantee)
        let grantOptionClause = withGrantOption ? "\nWITH GRANT OPTION" : ""

        var statements: [String] = []
        for objectName in selectedObjects.sorted() {
            let qualifiedName: String
            if objectType == .schemas {
                qualifiedName = ScriptingActions.pgQuote(objectName)
            } else {
                qualifiedName = "\(ScriptingActions.pgQuote(selectedSchema)).\(ScriptingActions.pgQuote(objectName))"
            }
            let stmt = "GRANT \(privList) ON \(objectType.sqlKeyword) \(qualifiedName) TO \(quotedGrantee)\(grantOptionClause);"
            statements.append(stmt)
        }

        return statements.joined(separator: "\n\n")
    }

    // MARK: - Apply

    func apply(session: DatabaseSession) async {
        guard let pg = session as? PostgresSession else { return }
        let trimmedGrantee = grantee.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canApply, !trimmedGrantee.isEmpty else { return }

        isApplying = true
        errorMessage = nil
        let handle = activityEngine?.begin("Granting privileges", connectionSessionID: connectionSessionID)

        do {
            let privileges = Array(selectedPrivileges)
            for objectName in selectedObjects.sorted() {
                switch objectType {
                case .tables:
                    let qualifiedName = "\(selectedSchema).\(objectName)"
                    try await pg.client.security.grantPrivileges(
                        privileges: privileges, onTable: qualifiedName,
                        to: trimmedGrantee, withGrantOption: withGrantOption
                    )
                case .schemas:
                    try await pg.client.security.grantSchemaPrivileges(
                        privileges: privileges, onSchema: objectName,
                        to: trimmedGrantee, withGrantOption: withGrantOption
                    )
                case .sequences, .functions:
                    let sql = buildGrantSQL(object: objectName, grantee: trimmedGrantee, privileges: privileges)
                    _ = try await session.executeUpdate(sql)
                }
            }
            handle?.succeed()
            panelState?.appendMessage("Granted privileges to '\(trimmedGrantee)' on \(selectedObjects.count) object(s)")
        } catch {
            handle?.fail(error.localizedDescription)
            errorMessage = error.localizedDescription
            panelState?.appendMessage("Grant failed: \(error.localizedDescription)", severity: .error)
        }

        isApplying = false
    }

    private func buildGrantSQL(object: String, grantee: String, privileges: [PostgresPrivilege]) -> String {
        let privList = privileges.contains(.all)
            ? "ALL PRIVILEGES"
            : privileges.map(\.rawValue).joined(separator: ", ")
        let qualifiedName = "\(ScriptingActions.pgQuote(selectedSchema)).\(ScriptingActions.pgQuote(object))"
        let quotedGrantee = ScriptingActions.pgQuote(grantee)
        var sql = "GRANT \(privList) ON \(objectType.sqlKeyword) \(qualifiedName) TO \(quotedGrantee)"
        if withGrantOption { sql += " WITH GRANT OPTION" }
        return sql
    }
}
