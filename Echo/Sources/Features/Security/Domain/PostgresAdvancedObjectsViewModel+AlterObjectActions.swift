import Foundation
import PostgresKit

// MARK: - Alter Actions (Aggregates, Operators, Languages, Event Triggers, FDWs, Foreign Servers, Rules)

extension PostgresAdvancedObjectsViewModel {

    // MARK: - Aggregate Alter Actions

    func renameAggregate(_ id: String, newName: String) async {
        guard let pg = session as? PostgresSession else { return }
        guard let agg = aggregates.first(where: { $0.id == id }) else { return }
        let handle = activityEngine?.begin("Renaming aggregate \(agg.name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.alterAggregateRename(name: agg.name, inputType: agg.inputType, newName: newName, schema: agg.schema)
            handle?.succeed()
            panelState?.appendMessage("Renamed aggregate '\(agg.name)' to '\(newName)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to rename aggregate: \(error.localizedDescription)", severity: .error)
        }
    }

    func changeAggregateOwner(_ id: String, newOwner: String) async {
        guard let pg = session as? PostgresSession else { return }
        guard let agg = aggregates.first(where: { $0.id == id }) else { return }
        let handle = activityEngine?.begin("Changing owner of aggregate \(agg.name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.alterAggregateOwner(name: agg.name, inputType: agg.inputType, newOwner: newOwner, schema: agg.schema)
            handle?.succeed()
            panelState?.appendMessage("Changed owner of aggregate '\(agg.name)' to '\(newOwner)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to change aggregate owner: \(error.localizedDescription)", severity: .error)
        }
    }

    func setAggregateSchema(_ id: String, newSchema: String) async {
        guard let pg = session as? PostgresSession else { return }
        guard let agg = aggregates.first(where: { $0.id == id }) else { return }
        let handle = activityEngine?.begin("Moving aggregate \(agg.name) to schema \(newSchema)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.alterAggregateSetSchema(name: agg.name, inputType: agg.inputType, newSchema: newSchema, schema: agg.schema)
            handle?.succeed()
            panelState?.appendMessage("Moved aggregate '\(agg.name)' to schema '\(newSchema)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to change aggregate schema: \(error.localizedDescription)", severity: .error)
        }
    }

    // MARK: - Operator Alter Actions

    func changeOperatorOwner(_ id: String, newOwner: String) async {
        guard let pg = session as? PostgresSession else { return }
        guard let op = operators.first(where: { $0.id == id }) else { return }
        let handle = activityEngine?.begin("Changing owner of operator \(op.name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.alterOperatorOwner(name: op.name, leftType: op.leftType, rightType: op.rightType, newOwner: newOwner, schema: op.schema)
            handle?.succeed()
            panelState?.appendMessage("Changed owner of operator '\(op.name)' to '\(newOwner)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to change operator owner: \(error.localizedDescription)", severity: .error)
        }
    }

    func setOperatorSchema(_ id: String, newSchema: String) async {
        guard let pg = session as? PostgresSession else { return }
        guard let op = operators.first(where: { $0.id == id }) else { return }
        let handle = activityEngine?.begin("Moving operator \(op.name) to schema \(newSchema)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.alterOperatorSetSchema(name: op.name, leftType: op.leftType, rightType: op.rightType, newSchema: newSchema, schema: op.schema)
            handle?.succeed()
            panelState?.appendMessage("Moved operator '\(op.name)' to schema '\(newSchema)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to change operator schema: \(error.localizedDescription)", severity: .error)
        }
    }

    // MARK: - Language Alter Actions

    func renameLanguage(_ name: String, newName: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Renaming language \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.alterLanguageRename(name: name, newName: newName)
            handle?.succeed()
            panelState?.appendMessage("Renamed language '\(name)' to '\(newName)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to rename language: \(error.localizedDescription)", severity: .error)
        }
    }

    func changeLanguageOwner(_ name: String, newOwner: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Changing owner of language \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.alterLanguageOwner(name: name, newOwner: newOwner)
            handle?.succeed()
            panelState?.appendMessage("Changed owner of language '\(name)' to '\(newOwner)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to change language owner: \(error.localizedDescription)", severity: .error)
        }
    }

    // MARK: - Event Trigger Alter Actions

    func renameEventTrigger(_ name: String, newName: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Renaming event trigger \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.triggers.alterEventTriggerRename(name: name, newName: newName)
            handle?.succeed()
            panelState?.appendMessage("Renamed event trigger '\(name)' to '\(newName)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to rename event trigger: \(error.localizedDescription)", severity: .error)
        }
    }

    func changeEventTriggerOwner(_ name: String, newOwner: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Changing owner of event trigger \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.triggers.alterEventTriggerOwner(name: name, newOwner: newOwner)
            handle?.succeed()
            panelState?.appendMessage("Changed owner of event trigger '\(name)' to '\(newOwner)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to change event trigger owner: \(error.localizedDescription)", severity: .error)
        }
    }

    func enableEventTrigger(_ name: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Enabling event trigger \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.triggers.alterEventTriggerEnable(name: name, enable: true)
            handle?.succeed()
            panelState?.appendMessage("Enabled event trigger '\(name)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to enable event trigger: \(error.localizedDescription)", severity: .error)
        }
    }

    func disableEventTrigger(_ name: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Disabling event trigger \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.triggers.alterEventTriggerEnable(name: name, enable: false)
            handle?.succeed()
            panelState?.appendMessage("Disabled event trigger '\(name)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to disable event trigger: \(error.localizedDescription)", severity: .error)
        }
    }

    // MARK: - FDW Alter Actions

    func renameFDW(_ name: String, newName: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Renaming FDW \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.alterForeignDataWrapperRename(name: name, newName: newName)
            handle?.succeed()
            panelState?.appendMessage("Renamed FDW '\(name)' to '\(newName)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to rename FDW: \(error.localizedDescription)", severity: .error)
        }
    }

    func changeFDWOwner(_ name: String, newOwner: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Changing owner of FDW \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.alterForeignDataWrapperOwner(name: name, newOwner: newOwner)
            handle?.succeed()
            panelState?.appendMessage("Changed owner of FDW '\(name)' to '\(newOwner)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to change FDW owner: \(error.localizedDescription)", severity: .error)
        }
    }

    // MARK: - Foreign Server Alter Actions

    func renameForeignServer(_ name: String, newName: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Renaming server \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.alterForeignServerRename(name: name, newName: newName)
            handle?.succeed()
            panelState?.appendMessage("Renamed foreign server '\(name)' to '\(newName)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to rename server: \(error.localizedDescription)", severity: .error)
        }
    }

    func changeForeignServerOwner(_ name: String, newOwner: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Changing owner of server \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.alterForeignServerOwner(name: name, newOwner: newOwner)
            handle?.succeed()
            panelState?.appendMessage("Changed owner of server '\(name)' to '\(newOwner)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to change server owner: \(error.localizedDescription)", severity: .error)
        }
    }

    // MARK: - Rule Alter Actions

    func renameRule(_ name: String, tableName: String, schema: String, newName: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Renaming rule \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.alterRuleRename(ruleName: name, tableName: tableName, newName: newName, schema: schema)
            handle?.succeed()
            panelState?.appendMessage("Renamed rule '\(name)' to '\(newName)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to rename rule: \(error.localizedDescription)", severity: .error)
        }
    }
}
