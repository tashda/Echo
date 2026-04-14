import Foundation
import PostgresKit

extension PostgresAdvancedObjectsViewModel {

    // MARK: - Drop Actions

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

    // MARK: - Create Actions

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

    // MARK: - Aggregates

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

    // MARK: - Operators

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

    // MARK: - Languages

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

    // MARK: - Casts

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
