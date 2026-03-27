import Foundation
import Observation
import PostgresKit

@Observable
final class PostgresDatabaseSecurityViewModel {

    enum Section: String, CaseIterable {
        case schemas = "Schemas"
        case roles = "Roles"
        case policies = "Policies"
    }

    let connectionID: UUID
    let connectionSessionID: UUID
    @ObservationIgnored let session: DatabaseSession
    @ObservationIgnored private(set) var panelState: BottomPanelState?
    @ObservationIgnored var activityEngine: ActivityEngine?

    var selectedSection: Section = .schemas
    var isInitialized = false

    // Schemas
    var schemas: [PostgresSchemaInfo] = []
    var selectedSchemaName: Set<String> = []
    var isLoadingSchemas = false

    // Roles
    var roles: [PostgresRoleInfo] = []
    var selectedRoleName: Set<String> = []
    var isLoadingRoles = false

    // Policies
    var policies: [PostgresPolicyInfo] = []
    var selectedPolicyID: Set<String> = []
    var isLoadingPolicies = false
    var policySchemaFilter: String = "public"
    var availableSchemas: [String] = []

    init(session: DatabaseSession, connectionID: UUID, connectionSessionID: UUID) {
        self.session = session
        self.connectionID = connectionID
        self.connectionSessionID = connectionSessionID
    }

    func setPanelState(_ state: BottomPanelState) {
        self.panelState = state
    }

    // MARK: - Data Loading

    func initialize() async {
        isInitialized = true
        await loadCurrentSection()
    }

    func loadCurrentSection() async {
        guard let pg = session as? PostgresSession else { return }

        switch selectedSection {
        case .schemas:
            await loadSchemas(pg: pg)
        case .roles:
            await loadRoles(pg: pg)
        case .policies:
            await loadPolicies(pg: pg)
        }
    }

    private func loadSchemas(pg: PostgresSession) async {
        isLoadingSchemas = true
        defer { isLoadingSchemas = false }
        do {
            schemas = try await pg.client.introspection.listSchemas()
        } catch {
            panelState?.appendMessage("Failed to load schemas: \(error.localizedDescription)", severity: .error)
        }
    }

    private func loadRoles(pg: PostgresSession) async {
        isLoadingRoles = true
        defer { isLoadingRoles = false }
        do {
            roles = try await pg.client.security.listRoles()
        } catch {
            panelState?.appendMessage("Failed to load roles: \(error.localizedDescription)", severity: .error)
        }
    }

    // MARK: - Schema Actions

    func createSchema(name: String, owner: String?) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Creating schema \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.createSchema(name: name, authorization: owner)
            handle?.succeed()
            panelState?.appendMessage("Created schema '\(name)'")
            await loadSchemas(pg: pg)
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to create schema '\(name)': \(error.localizedDescription)", severity: .error)
        }
    }

    func dropSchema(_ name: String, cascade: Bool = false) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Dropping schema \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.dropSchema(name: name, ifExists: true, cascade: cascade)
            handle?.succeed()
            panelState?.appendMessage("Dropped schema '\(name)'")
            await loadSchemas(pg: pg)
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to drop schema '\(name)': \(error.localizedDescription)", severity: .error)
        }
    }

    func renameSchema(_ name: String, to newName: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Renaming schema \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.alterSchemaRename(name: name, newName: newName)
            handle?.succeed()
            panelState?.appendMessage("Renamed schema '\(name)' to '\(newName)'")
            await loadSchemas(pg: pg)
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to rename schema '\(name)': \(error.localizedDescription)", severity: .error)
        }
    }

    func changeSchemaOwner(_ name: String, to newOwner: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Changing owner of \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.alterSchemaOwner(name: name, newOwner: newOwner)
            handle?.succeed()
            panelState?.appendMessage("Changed owner of schema '\(name)' to '\(newOwner)'")
            await loadSchemas(pg: pg)
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to change owner: \(error.localizedDescription)", severity: .error)
        }
    }

    // MARK: - Role Actions

    func dropRole(_ name: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Dropping role \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.security.dropRole(name: name, ifExists: true)
            handle?.succeed()
            panelState?.appendMessage("Dropped role '\(name)'")
            await loadRoles(pg: pg)
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to drop role '\(name)': \(error.localizedDescription)", severity: .error)
        }
    }

    func reassignOwned(from oldRole: String, to newRole: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Reassigning owned objects", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.security.reassignOwned(from: oldRole, to: newRole)
            handle?.succeed()
            panelState?.appendMessage("Reassigned objects from '\(oldRole)' to '\(newRole)'")
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to reassign: \(error.localizedDescription)", severity: .error)
        }
    }

    func dropOwned(by role: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Dropping owned objects", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.security.dropOwned(by: role)
            handle?.succeed()
            panelState?.appendMessage("Dropped all objects owned by '\(role)'")
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to drop owned: \(error.localizedDescription)", severity: .error)
        }
    }

    // MARK: - Policy Actions

    private func loadPolicies(pg: PostgresSession) async {
        isLoadingPolicies = true
        defer { isLoadingPolicies = false }
        do {
            if availableSchemas.isEmpty {
                availableSchemas = try await pg.client.introspection.listSchemas().map(\.name)
            }
            policies = try await pg.client.introspection.listPolicies(schema: policySchemaFilter)
        } catch {
            panelState?.appendMessage("Failed to load policies: \(error.localizedDescription)", severity: .error)
        }
    }

    func dropPolicy(_ name: String, table: String, schema: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Dropping policy \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.security.dropPolicy(name: name, table: "\(schema).\(table)", ifExists: true)
            handle?.succeed()
            panelState?.appendMessage("Dropped policy '\(name)'")
            await loadPolicies(pg: pg)
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to drop policy '\(name)': \(error.localizedDescription)", severity: .error)
        }
    }

    func createPolicy(name: String, table: String, schema: String, command: String, permissive: Bool, roles: String, usingExpr: String, withCheckExpr: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Creating policy \(name)", connectionSessionID: connectionSessionID)
        do {
            let qualifiedTable = "\"\(schema)\".\"\(table)\""
            let roleList: [String]? = roles.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : roles.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            let usingVal = usingExpr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : usingExpr
            let withCheckVal = withCheckExpr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : withCheckExpr
            let policyCommand = PostgresPolicyCommand(rawValue: command.uppercased()) ?? .all
            try await pg.client.security.createPolicy(
                name: name, table: qualifiedTable, command: policyCommand,
                to: roleList, using: usingVal, withCheck: withCheckVal, permissive: permissive
            )
            handle?.succeed()
            panelState?.appendMessage("Created policy '\(name)' on \(schema).\(table)")
            await loadPolicies(pg: pg)
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to create policy: \(error.localizedDescription)", severity: .error)
        }
    }
}
