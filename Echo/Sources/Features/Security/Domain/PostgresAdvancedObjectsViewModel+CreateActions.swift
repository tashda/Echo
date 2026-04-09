import Foundation
import PostgresKit

// MARK: - Create Actions

extension PostgresAdvancedObjectsViewModel {

    func createForeignServer(name: String, type: String?, version: String?, fdwName: String, options: [String: String]?) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Creating foreign server \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.createForeignServer(name: name, type: type, version: version, fdwName: fdwName, options: options)
            handle?.succeed()
            panelState?.appendMessage("Created foreign server '\(name)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to create server: \(error.localizedDescription)", severity: .error)
        }
    }

    func createEventTrigger(name: String, event: String, function: String, tags: [String]?) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Creating event trigger \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.triggers.createEventTrigger(name: name, event: event, function: function, tags: tags)
            handle?.succeed()
            panelState?.appendMessage("Created event trigger '\(name)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to create event trigger: \(error.localizedDescription)", severity: .error)
        }
    }

    func createDomain(name: String, schema: String?, dataType: String, defaultValue: String?, notNull: Bool, checkExpression: String?) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Creating domain \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.types.createDomain(name: name, dataType: dataType, defaultValue: defaultValue, notNull: notNull, checkExpression: checkExpression, schema: schema)
            handle?.succeed()
            panelState?.appendMessage("Created domain '\(name)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to create domain: \(error.localizedDescription)", severity: .error)
        }
    }

    func createCompositeType(name: String, schema: String?, attributes: [(name: String, dataType: String)]) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Creating composite type \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.types.createCompositeType(name: name, attributes: attributes, schema: schema)
            handle?.succeed()
            panelState?.appendMessage("Created composite type '\(name)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to create type: \(error.localizedDescription)", severity: .error)
        }
    }

    func createRangeType(name: String, schema: String?, subtype: String, opClass: String?, collation: String?) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Creating range type \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.types.createRangeType(name: name, subtype: subtype, subtypeOpClass: opClass, collation: collation, schema: schema)
            handle?.succeed()
            panelState?.appendMessage("Created range type '\(name)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to create range type: \(error.localizedDescription)", severity: .error)
        }
    }

    func createCollation(name: String, schema: String?, locale: String?, provider: String?) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Creating collation \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.createCollation(name: name, locale: locale, provider: provider, schema: schema)
            handle?.succeed()
            panelState?.appendMessage("Created collation '\(name)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to create collation: \(error.localizedDescription)", severity: .error)
        }
    }

    func createFTSConfig(name: String, schema: String?, parser: String?, copySource: String?) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Creating FTS config \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.createTextSearchConfiguration(name: name, parser: parser, copy: copySource, schema: schema)
            handle?.succeed()
            panelState?.appendMessage("Created text search config '\(name)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to create FTS config: \(error.localizedDescription)", severity: .error)
        }
    }

    func createRule(name: String, table: String, schema: String?, event: String, doInstead: Bool, condition: String?, commands: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Creating rule \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.createRule(name: name, table: table, event: event, doInstead: doInstead, condition: condition, commands: commands, schema: schema)
            handle?.succeed()
            panelState?.appendMessage("Created rule '\(name)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to create rule: \(error.localizedDescription)", severity: .error)
        }
    }

    func createTablespace(name: String, location: String, owner: String?) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Creating tablespace \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.createTablespace(name: name, location: location, owner: owner)
            handle?.succeed()
            panelState?.appendMessage("Created tablespace '\(name)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to create tablespace: \(error.localizedDescription)", severity: .error)
        }
    }

    func createAggregate(name: String, inputType: String, sfunc: String, stype: String, initcond: String?) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Creating aggregate \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.createAggregate(name: name, inputType: inputType, sfunc: sfunc, stype: stype, initcond: initcond, schema: schemaFilter)
            handle?.succeed()
            panelState?.appendMessage("Created aggregate '\(name)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to create aggregate: \(error.localizedDescription)", severity: .error)
        }
    }

    func createOperator(name: String, leftType: String?, rightType: String?, procedure: String) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Creating operator \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.createOperator(name: name, leftType: leftType, rightType: rightType, procedure: procedure, schema: schemaFilter)
            handle?.succeed()
            panelState?.appendMessage("Created operator '\(name)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to create operator: \(error.localizedDescription)", severity: .error)
        }
    }

    func createLanguage(name: String, trusted: Bool, handler: String?, validator: String?) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Creating language \(name)", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.createLanguage(name: name, trusted: trusted, handler: handler, validator: validator)
            handle?.succeed()
            panelState?.appendMessage("Created language '\(name)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to create language: \(error.localizedDescription)", severity: .error)
        }
    }

    func createCast(sourceType: String, targetType: String, function: String?, asAssignment: Bool, asImplicit: Bool) async {
        guard let pg = session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Creating cast (\(sourceType) AS \(targetType))", connectionSessionID: connectionSessionID)
        do {
            try await pg.client.admin.createCast(sourceType: sourceType, targetType: targetType, function: function, asAssignment: asAssignment, asImplicit: asImplicit)
            handle?.succeed()
            panelState?.appendMessage("Created cast '\(sourceType) -> \(targetType)'")
            await loadCurrentSection()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to create cast: \(error.localizedDescription)", severity: .error)
        }
    }
}
