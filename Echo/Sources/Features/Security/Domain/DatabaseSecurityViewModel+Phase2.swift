import Foundation
import SQLServerKit

// MARK: - Phase 2 Loading & Actions (Masking, RLS, Audit Specs, Always Encrypted)

extension DatabaseSecurityViewModel {

    // MARK: - Dynamic Data Masking

    func loadMaskedColumns(mssql: MSSQLSession) async {
        isLoadingMaskedColumns = true
        defer { isLoadingMaskedColumns = false }
        do {
            maskedColumns = try await mssql.security.listMaskedColumns()
        } catch {
            panelState?.appendMessage("Failed to load masked columns: \(error.localizedDescription)", severity: .error)
        }
    }

    func dropMask(schema: String, table: String, column: String) async {
        guard let mssql = session as? MSSQLSession else { return }
        let handle = activityEngine?.begin("Removing mask from \(schema).\(table).\(column)", connectionSessionID: connectionSessionID)
        do {
            _ = try? await session.sessionForDatabase(selectedDatabase ?? "")
            try await mssql.security.dropMask(schema: schema, table: table, column: column)
            handle?.succeed()
            panelState?.appendMessage("Removed mask from '\(schema).\(table).\(column)'")
            await loadMaskedColumns(mssql: mssql)
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to remove mask: \(error.localizedDescription)", severity: .error)
        }
    }

    // MARK: - Row-Level Security

    func loadSecurityPolicies(mssql: MSSQLSession) async {
        isLoadingSecurityPolicies = true
        defer { isLoadingSecurityPolicies = false }
        do {
            securityPolicies = try await mssql.security.listSecurityPolicies()
        } catch {
            panelState?.appendMessage("Failed to load security policies: \(error.localizedDescription)", severity: .error)
        }
    }

    func toggleSecurityPolicy(name: String, schema: String, enabled: Bool) async {
        guard let mssql = session as? MSSQLSession else { return }
        do {
            _ = try? await session.sessionForDatabase(selectedDatabase ?? "")
            try await mssql.security.alterSecurityPolicyState(name: name, schema: schema, enabled: enabled)
            panelState?.appendMessage(enabled ? "Enabled policy '\(schema).\(name)'" : "Disabled policy '\(schema).\(name)'")
            await loadSecurityPolicies(mssql: mssql)
        } catch {
            panelState?.appendMessage("Failed to \(enabled ? "enable" : "disable") policy: \(error.localizedDescription)", severity: .error)
        }
    }

    func dropSecurityPolicy(name: String, schema: String) async {
        guard let mssql = session as? MSSQLSession else { return }
        let handle = activityEngine?.begin("Dropping security policy \(schema).\(name)", connectionSessionID: connectionSessionID)
        do {
            _ = try? await session.sessionForDatabase(selectedDatabase ?? "")
            try await mssql.security.dropSecurityPolicy(name: name, schema: schema)
            handle?.succeed()
            panelState?.appendMessage("Dropped security policy '\(schema).\(name)'")
            await loadSecurityPolicies(mssql: mssql)
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to drop security policy: \(error.localizedDescription)", severity: .error)
        }
    }

    // MARK: - Database Audit Specifications

    func loadDBAuditSpecs(mssql: MSSQLSession) async {
        isLoadingDBAuditSpecs = true
        defer { isLoadingDBAuditSpecs = false }
        do {
            dbAuditSpecs = try await mssql.audit.listDatabaseAuditSpecifications()
        } catch {
            panelState?.appendMessage("Failed to load database audit specifications: \(error.localizedDescription)", severity: .error)
        }
    }

    func toggleDBAuditSpec(name: String, enabled: Bool) async {
        guard let mssql = session as? MSSQLSession else { return }
        do {
            _ = try? await session.sessionForDatabase(selectedDatabase ?? "")
            try await mssql.audit.setDatabaseAuditSpecificationState(name: name, enabled: enabled)
            panelState?.appendMessage(enabled ? "Enabled audit specification '\(name)'" : "Disabled audit specification '\(name)'")
            await loadDBAuditSpecs(mssql: mssql)
        } catch {
            panelState?.appendMessage("Failed to \(enabled ? "enable" : "disable") audit specification: \(error.localizedDescription)", severity: .error)
        }
    }

    func dropDBAuditSpec(name: String) async {
        guard let mssql = session as? MSSQLSession else { return }
        let handle = activityEngine?.begin("Dropping audit specification \(name)", connectionSessionID: connectionSessionID)
        do {
            _ = try? await session.sessionForDatabase(selectedDatabase ?? "")
            try await mssql.audit.dropDatabaseAuditSpecification(name: name)
            handle?.succeed()
            panelState?.appendMessage("Dropped database audit specification '\(name)'")
            await loadDBAuditSpecs(mssql: mssql)
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to drop audit specification: \(error.localizedDescription)", severity: .error)
        }
    }

    // MARK: - Always Encrypted

    func loadAlwaysEncrypted(mssql: MSSQLSession) async {
        isLoadingAlwaysEncrypted = true
        defer { isLoadingAlwaysEncrypted = false }
        do {
            columnMasterKeys = try await mssql.alwaysEncrypted.listColumnMasterKeys()
            columnEncryptionKeys = try await mssql.alwaysEncrypted.listColumnEncryptionKeys()
        } catch {
            panelState?.appendMessage("Failed to load Always Encrypted keys: \(error.localizedDescription)", severity: .error)
        }
    }

    func dropColumnMasterKey(name: String) async {
        guard let mssql = session as? MSSQLSession else { return }
        let handle = activityEngine?.begin("Dropping column master key \(name)", connectionSessionID: connectionSessionID)
        do {
            _ = try? await session.sessionForDatabase(selectedDatabase ?? "")
            try await mssql.alwaysEncrypted.dropColumnMasterKey(name: name)
            handle?.succeed()
            panelState?.appendMessage("Dropped column master key '\(name)'")
            await loadAlwaysEncrypted(mssql: mssql)
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to drop column master key: \(error.localizedDescription)", severity: .error)
        }
    }

    func dropColumnEncryptionKey(name: String) async {
        guard let mssql = session as? MSSQLSession else { return }
        let handle = activityEngine?.begin("Dropping column encryption key \(name)", connectionSessionID: connectionSessionID)
        do {
            _ = try? await session.sessionForDatabase(selectedDatabase ?? "")
            try await mssql.alwaysEncrypted.dropColumnEncryptionKey(name: name)
            handle?.succeed()
            panelState?.appendMessage("Dropped column encryption key '\(name)'")
            await loadAlwaysEncrypted(mssql: mssql)
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to drop column encryption key: \(error.localizedDescription)", severity: .error)
        }
    }
}
