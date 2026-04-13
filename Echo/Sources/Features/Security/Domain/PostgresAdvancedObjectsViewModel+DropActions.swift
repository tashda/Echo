import Foundation
import PostgresKit

// MARK: - Drop Actions

extension PostgresAdvancedObjectsViewModel {

    func dropFDW(_ name: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Dropping FDW \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.dropForeignDataWrapper(name: name, ifExists: true, cascade: true)
            handle?.succeed()
            panelState?.appendMessage("Dropped FDW '\(name)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to drop FDW: \(error.localizedDescription)", severity: .error)
        }
    }

    func dropForeignServer(_ name: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Dropping server \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.dropForeignServer(name: name, ifExists: true, cascade: true)
            handle?.succeed()
            panelState?.appendMessage("Dropped foreign server '\(name)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to drop server: \(error.localizedDescription)", severity: .error)
        }
    }

    func dropEventTrigger(_ name: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Dropping event trigger \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.triggers.dropEventTrigger(name: name, ifExists: true, cascade: true)
            handle?.succeed()
            panelState?.appendMessage("Dropped event trigger '\(name)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to drop event trigger: \(error.localizedDescription)", severity: .error)
        }
    }

    func dropDomain(_ name: String, schema: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Dropping domain \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.types.dropDomain(name: name, ifExists: true, cascade: true, schema: schema)
            handle?.succeed()
            panelState?.appendMessage("Dropped domain '\(name)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to drop domain: \(error.localizedDescription)", severity: .error)
        }
    }

    func dropCompositeType(_ name: String, schema: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Dropping type \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.types.dropCompositeType(name: name, ifExists: true, cascade: true, schema: schema)
            handle?.succeed()
            panelState?.appendMessage("Dropped composite type '\(name)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to drop type: \(error.localizedDescription)", severity: .error)
        }
    }

    func dropRangeType(_ name: String, schema: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Dropping range type \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.types.dropRangeType(name: name, ifExists: true, cascade: true, schema: schema)
            handle?.succeed()
            panelState?.appendMessage("Dropped range type '\(name)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to drop range type: \(error.localizedDescription)", severity: .error)
        }
    }

    func dropCollation(_ name: String, schema: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Dropping collation \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.dropCollation(name: name, ifExists: true, cascade: true, schema: schema)
            handle?.succeed()
            panelState?.appendMessage("Dropped collation '\(name)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to drop collation: \(error.localizedDescription)", severity: .error)
        }
    }

    func dropFTSConfig(_ name: String, schema: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Dropping FTS config \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.dropTextSearchConfiguration(name: name, ifExists: true, cascade: true, schema: schema)
            handle?.succeed()
            panelState?.appendMessage("Dropped text search config '\(name)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to drop FTS config: \(error.localizedDescription)", severity: .error)
        }
    }

    func dropRule(_ name: String, table: String, schema: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Dropping rule \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.dropRule(name: name, table: table, ifExists: true, cascade: true, schema: schema)
            handle?.succeed()
            panelState?.appendMessage("Dropped rule '\(name)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to drop rule: \(error.localizedDescription)", severity: .error)
        }
    }

    func dropTablespace(_ name: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Dropping tablespace \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.dropTablespace(name: name, ifExists: true)
            handle?.succeed()
            panelState?.appendMessage("Dropped tablespace '\(name)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to drop tablespace: \(error.localizedDescription)", severity: .error)
        }
    }

    func dropAggregate(_ id: String) async {
        guard let pg = session as? PostgresSession else { return }
        guard let agg = aggregates.first(where: { $0.id == id }) else { return }
        let handle = activityEngine?.begin("Dropping aggregate \(agg.name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.dropAggregate(name: agg.name, inputType: agg.inputType, ifExists: true, cascade: true, schema: agg.schema)
            handle?.succeed()
            panelState?.appendMessage("Dropped aggregate '\(agg.name)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to drop aggregate: \(error.localizedDescription)", severity: .error)
        }
    }

    func dropOperator(_ id: String) async {
        guard let pg = session as? PostgresSession else { return }
        guard let op = operators.first(where: { $0.id == id }) else { return }
        let handle = activityEngine?.begin("Dropping operator \(op.name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.dropOperator(name: op.name, leftType: op.leftType, rightType: op.rightType, ifExists: true, cascade: true, schema: op.schema)
            handle?.succeed()
            panelState?.appendMessage("Dropped operator '\(op.name)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to drop operator: \(error.localizedDescription)", severity: .error)
        }
    }

    func dropLanguage(_ name: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Dropping language \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.dropLanguage(name: name, ifExists: true, cascade: true)
            handle?.succeed()
            panelState?.appendMessage("Dropped language '\(name)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to drop language: \(error.localizedDescription)", severity: .error)
        }
    }

    func dropCast(_ id: String) async {
        guard let pg = session as? PostgresSession else { return }
        guard let cast = casts.first(where: { $0.id == id }) else { return }
        let handle = activityEngine?.begin("Dropping cast \(cast.sourceType) -> \(cast.targetType)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.dropCast(sourceType: cast.sourceType, targetType: cast.targetType, ifExists: true)
            handle?.succeed()
            panelState?.appendMessage("Dropped cast '\(cast.sourceType) -> \(cast.targetType)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to drop cast: \(error.localizedDescription)", severity: .error)
        }
    }
}
