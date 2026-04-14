import Foundation
import PostgresKit

// MARK: - Alter Actions (Domains, Types, Collations, FTS Configs, Tablespaces)

extension PostgresAdvancedObjectsViewModel {

    // MARK: - Domain Alter Actions

    func renameDomain(_ name: String, schema: String, newName: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Renaming domain \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.types.alterDomainRename(name: name, newName: newName, schema: schema)
            handle?.succeed()
            panelState?.appendMessage("Renamed domain '\(name)' to '\(newName)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to rename domain: \(error.localizedDescription)", severity: .error)
        }
    }

    func changeDomainOwner(_ name: String, schema: String, newOwner: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Changing owner of domain \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.types.alterDomainOwner(name: name, newOwner: newOwner, schema: schema)
            handle?.succeed()
            panelState?.appendMessage("Changed owner of domain '\(name)' to '\(newOwner)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to change domain owner: \(error.localizedDescription)", severity: .error)
        }
    }

    func setDomainSchema(_ name: String, schema: String, newSchema: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Moving domain \(name) to schema \(newSchema)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.types.alterDomainSetSchema(name: name, newSchema: newSchema, schema: schema)
            handle?.succeed()
            panelState?.appendMessage("Moved domain '\(name)' to schema '\(newSchema)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to change domain schema: \(error.localizedDescription)", severity: .error)
        }
    }

    // MARK: - Composite Type / Range Type Alter Actions

    func renameType(_ name: String, schema: String, newName: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Renaming type \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.types.alterTypeRename(name: name, newName: newName, schema: schema)
            handle?.succeed()
            panelState?.appendMessage("Renamed type '\(name)' to '\(newName)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to rename type: \(error.localizedDescription)", severity: .error)
        }
    }

    func changeTypeOwner(_ name: String, schema: String, newOwner: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Changing owner of type \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.types.alterTypeOwner(name: name, newOwner: newOwner, schema: schema)
            handle?.succeed()
            panelState?.appendMessage("Changed owner of type '\(name)' to '\(newOwner)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to change type owner: \(error.localizedDescription)", severity: .error)
        }
    }

    func setTypeSchema(_ name: String, schema: String, newSchema: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Moving type \(name) to schema \(newSchema)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.types.alterTypeSetSchema(name: name, newSchema: newSchema, schema: schema)
            handle?.succeed()
            panelState?.appendMessage("Moved type '\(name)' to schema '\(newSchema)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to change type schema: \(error.localizedDescription)", severity: .error)
        }
    }

    // MARK: - Collation Alter Actions

    func renameCollation(_ name: String, schema: String, newName: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Renaming collation \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.alterCollationRename(name: name, newName: newName, schema: schema)
            handle?.succeed()
            panelState?.appendMessage("Renamed collation '\(name)' to '\(newName)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to rename collation: \(error.localizedDescription)", severity: .error)
        }
    }

    func changeCollationOwner(_ name: String, schema: String, newOwner: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Changing owner of collation \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.alterCollationOwner(name: name, newOwner: newOwner, schema: schema)
            handle?.succeed()
            panelState?.appendMessage("Changed owner of collation '\(name)' to '\(newOwner)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to change collation owner: \(error.localizedDescription)", severity: .error)
        }
    }

    func setCollationSchema(_ name: String, schema: String, newSchema: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Moving collation \(name) to schema \(newSchema)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.alterCollationSetSchema(name: name, newSchema: newSchema, schema: schema)
            handle?.succeed()
            panelState?.appendMessage("Moved collation '\(name)' to schema '\(newSchema)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to change collation schema: \(error.localizedDescription)", severity: .error)
        }
    }

    func refreshCollationVersion(_ name: String, schema: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Refreshing collation version \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.alterCollationRefreshVersion(name: name, schema: schema)
            handle?.succeed()
            panelState?.appendMessage("Refreshed collation version '\(name)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to refresh collation version: \(error.localizedDescription)", severity: .error)
        }
    }

    // MARK: - FTS Config Alter Actions

    func renameFTSConfig(_ name: String, schema: String, newName: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Renaming FTS config \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.alterTextSearchConfigurationRename(name: name, newName: newName, schema: schema)
            handle?.succeed()
            panelState?.appendMessage("Renamed FTS config '\(name)' to '\(newName)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to rename FTS config: \(error.localizedDescription)", severity: .error)
        }
    }

    func changeFTSConfigOwner(_ name: String, schema: String, newOwner: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Changing owner of FTS config \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.alterTextSearchConfigurationOwner(name: name, newOwner: newOwner, schema: schema)
            handle?.succeed()
            panelState?.appendMessage("Changed owner of FTS config '\(name)' to '\(newOwner)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to change FTS config owner: \(error.localizedDescription)", severity: .error)
        }
    }

    func setFTSConfigSchema(_ name: String, schema: String, newSchema: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Moving FTS config \(name) to schema \(newSchema)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.alterTextSearchConfigurationSetSchema(name: name, newSchema: newSchema, schema: schema)
            handle?.succeed()
            panelState?.appendMessage("Moved FTS config '\(name)' to schema '\(newSchema)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to change FTS config schema: \(error.localizedDescription)", severity: .error)
        }
    }

    // MARK: - Tablespace Alter Actions

    func renameTablespace(_ name: String, newName: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Renaming tablespace \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.alterTablespaceRename(name: name, newName: newName)
            handle?.succeed()
            panelState?.appendMessage("Renamed tablespace '\(name)' to '\(newName)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to rename tablespace: \(error.localizedDescription)", severity: .error)
        }
    }

    func changeTablespaceOwner(_ name: String, newOwner: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Changing owner of tablespace \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.alterTablespaceOwner(name: name, newOwner: newOwner)
            handle?.succeed()
            panelState?.appendMessage("Changed owner of tablespace '\(name)' to '\(newOwner)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to change tablespace owner: \(error.localizedDescription)", severity: .error)
        }
    }
}
