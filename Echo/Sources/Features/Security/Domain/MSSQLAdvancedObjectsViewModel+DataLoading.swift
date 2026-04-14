import Foundation
import SQLServerKit

extension MSSQLAdvancedObjectsViewModel {

    // MARK: - Change Tracking

    func loadChangeTracking() async {
        guard let mssql = session as? MSSQLSession else { return }
        isLoadingCT = true
        errorMessage = nil
        do {
            ctStatus = try await mssql.changeTracking.changeTrackingStatus()
            ctTables = try await mssql.changeTracking.listChangeTrackingTables()
            isLoadingCT = false
        } catch {
            errorMessage = error.localizedDescription
            isLoadingCT = false
        }
    }

    func enableChangeTracking() async {
        guard let mssql = session as? MSSQLSession else { return }
        isBusy = true
        let handle = activityEngine?.begin("Enable Change Tracking on \(databaseName)", connectionSessionID: connectionSessionID)
        do {
            try await mssql.changeTracking.enableChangeTracking(database: databaseName)
            handle?.succeed()
            await loadChangeTracking()
        } catch {
            errorMessage = error.localizedDescription
            handle?.fail(error.localizedDescription)
        }
        isBusy = false
    }

    func disableChangeTracking() async {
        guard let mssql = session as? MSSQLSession else { return }
        isBusy = true
        let handle = activityEngine?.begin("Disable Change Tracking on \(databaseName)", connectionSessionID: connectionSessionID)
        do {
            try await mssql.changeTracking.disableChangeTracking(database: databaseName)
            handle?.succeed()
            await loadChangeTracking()
        } catch {
            errorMessage = error.localizedDescription
            handle?.fail(error.localizedDescription)
        }
        isBusy = false
    }

    func disableTableChangeTracking(schema: String, table: String) async {
        guard let mssql = session as? MSSQLSession else { return }
        isBusy = true
        let handle = activityEngine?.begin("Disable CT on [\(schema)].[\(table)]", connectionSessionID: connectionSessionID)
        do {
            try await mssql.changeTracking.disableTableChangeTracking(schema: schema, table: table)
            handle?.succeed()
            await loadChangeTracking()
        } catch {
            errorMessage = error.localizedDescription
            handle?.fail(error.localizedDescription)
        }
        isBusy = false
    }

    // MARK: - CDC

    func loadCDC() async {
        guard let mssql = session as? MSSQLSession else { return }
        isLoadingCDC = true
        errorMessage = nil
        do {
            cdcTables = try await mssql.changeTracking.listCDCTables()
            isLoadingCDC = false
        } catch {
            // CDC tables may not exist if CDC isn't enabled — not an error
            cdcTables = []
            isLoadingCDC = false
        }
    }

    func enableCDC(schema: String, table: String) async {
        guard let mssql = session as? MSSQLSession else { return }
        isBusy = true
        let handle = activityEngine?.begin("Enable CDC on [\(schema)].[\(table)]", connectionSessionID: connectionSessionID)
        do {
            try await mssql.changeTracking.enableCDC(schema: schema, table: table)
            handle?.succeed()
            await loadCDC()
        } catch {
            errorMessage = error.localizedDescription
            handle?.fail(error.localizedDescription)
        }
        isBusy = false
    }

    func disableCDC(schema: String, table: String, captureInstance: String?) async {
        guard let mssql = session as? MSSQLSession else { return }
        isBusy = true
        let handle = activityEngine?.begin("Disable CDC on [\(schema)].[\(table)]", connectionSessionID: connectionSessionID)
        do {
            try await mssql.changeTracking.disableCDC(schema: schema, table: table, captureInstance: captureInstance)
            handle?.succeed()
            await loadCDC()
        } catch {
            errorMessage = error.localizedDescription
            handle?.fail(error.localizedDescription)
        }
        isBusy = false
    }

    // MARK: - Full-Text Search

    func loadFullText() async {
        guard let mssql = session as? MSSQLSession else { return }
        isLoadingFT = true
        errorMessage = nil
        do {
            ftCatalogs = try await mssql.fullText.listCatalogs()
            ftIndexes = try await mssql.fullText.listIndexes()
            isLoadingFT = false
        } catch {
            errorMessage = error.localizedDescription
            isLoadingFT = false
        }
    }

    func createCatalog(name: String, isDefault: Bool, accentSensitive: Bool) async {
        guard let mssql = session as? MSSQLSession else { return }
        isBusy = true
        let handle = activityEngine?.begin("Create full-text catalog \(name)", connectionSessionID: connectionSessionID)
        do {
            try await mssql.fullText.createCatalog(name: name, isDefault: isDefault, accentSensitive: accentSensitive)
            handle?.succeed()
            await loadFullText()
        } catch {
            errorMessage = error.localizedDescription
            handle?.fail(error.localizedDescription)
        }
        isBusy = false
    }

    func dropCatalog(name: String) async {
        guard let mssql = session as? MSSQLSession else { return }
        isBusy = true
        let handle = activityEngine?.begin("Drop full-text catalog \(name)", connectionSessionID: connectionSessionID)
        do {
            try await mssql.fullText.dropCatalog(name: name)
            handle?.succeed()
            await loadFullText()
        } catch {
            errorMessage = error.localizedDescription
            handle?.fail(error.localizedDescription)
        }
        isBusy = false
    }

    func rebuildCatalog(name: String) async {
        guard let mssql = session as? MSSQLSession else { return }
        isBusy = true
        let handle = activityEngine?.begin("Rebuild full-text catalog \(name)", connectionSessionID: connectionSessionID)
        do {
            try await mssql.fullText.rebuildCatalog(name: name)
            handle?.succeed()
            await loadFullText()
        } catch {
            errorMessage = error.localizedDescription
            handle?.fail(error.localizedDescription)
        }
        isBusy = false
    }

    func dropFullTextIndex(schema: String, table: String) async {
        guard let mssql = session as? MSSQLSession else { return }
        isBusy = true
        let handle = activityEngine?.begin("Drop full-text index on \(table)", connectionSessionID: connectionSessionID)
        do {
            try await mssql.fullText.dropIndex(schema: schema, table: table)
            handle?.succeed()
            await loadFullText()
        } catch {
            errorMessage = error.localizedDescription
            handle?.fail(error.localizedDescription)
        }
        isBusy = false
    }

    func createFullTextIndex(schema: String, table: String, keyIndex: String, catalogName: String?, columns: [String], changeTracking: SQLServerFullTextClient.ChangeTrackingMode) async {
        guard let mssql = session as? MSSQLSession else { return }
        isBusy = true
        let handle = activityEngine?.begin("Create full-text index on \(table)", connectionSessionID: connectionSessionID)
        do {
            try await mssql.fullText.createIndex(
                schema: schema,
                table: table,
                keyIndex: keyIndex,
                catalogName: catalogName,
                columns: columns,
                changeTracking: changeTracking
            )
            handle?.succeed()
            await loadFullText()
        } catch {
            errorMessage = error.localizedDescription
            handle?.fail(error.localizedDescription)
        }
        isBusy = false
    }

    func startPopulation(schema: String, table: String, type: SQLServerFullTextClient.PopulationType) async {
        guard let mssql = session as? MSSQLSession else { return }
        isBusy = true
        do {
            try await mssql.fullText.startPopulation(schema: schema, table: table, type: type)
            await loadFullText()
        } catch {
            errorMessage = error.localizedDescription
        }
        isBusy = false
    }

    func stopPopulation(schema: String, table: String) async {
        guard let mssql = session as? MSSQLSession else { return }
        isBusy = true
        do {
            try await mssql.fullText.stopPopulation(schema: schema, table: table)
            await loadFullText()
        } catch {
            errorMessage = error.localizedDescription
        }
        isBusy = false
    }

    // MARK: - Replication

    func loadReplication() async {
        guard let mssql = session as? MSSQLSession else { return }
        isLoadingReplication = true
        errorMessage = nil
        do {
            distributorConfigured = try await mssql.replication.isDistributorConfigured()
            publications = try await mssql.replication.listPublications()
            subscriptions = try await mssql.replication.listSubscriptions()
            agentStatuses = try await mssql.replication.agentStatus()
            isLoadingReplication = false
        } catch {
            // Replication system tables may not exist — gracefully handle
            distributorConfigured = false
            publications = []
            subscriptions = []
            agentStatuses = []
            isLoadingReplication = false
        }
    }

    func loadArticles(publicationName: String) async {
        guard let mssql = session as? MSSQLSession else { return }
        do {
            articles = try await mssql.replication.listArticles(publicationName: publicationName)
        } catch {
            articles = []
        }
    }

    func deletePublication(_ pub: SQLServerPublication) async {
        guard let mssql = session as? MSSQLSession else { return }
        isBusy = true
        let handle = activityEngine?.begin("Drop publication \(pub.name)", connectionSessionID: connectionSessionID)
        do {
            try await mssql.replication.dropPublication(name: pub.name)
            handle?.succeed()
            await loadReplication()
        } catch {
            handle?.fail(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
        isBusy = false
    }

    func deleteSubscription(_ sub: SQLServerSubscription, publicationName: String) async {
        guard let mssql = session as? MSSQLSession else { return }
        isBusy = true
        let handle = activityEngine?.begin("Drop subscription \(sub.subscriberServer).\(sub.subscriberDB)", connectionSessionID: connectionSessionID)
        do {
            try await mssql.replication.dropSubscription(
                publicationName: publicationName,
                subscriberServer: sub.subscriberServer,
                subscriberDB: sub.subscriberDB
            )
            handle?.succeed()
            await loadReplication()
        } catch {
            handle?.fail(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
        isBusy = false
    }

    func configureDistribution(password: String, dbName: String, snapshotFolder: String?) async throws {
        guard let mssql = session as? MSSQLSession else { return }
        try await mssql.replication.configureDistributor(password: password)
        try await mssql.replication.configureDistributionDB(name: dbName, snapshotFolder: snapshotFolder)
        try await mssql.replication.enablePublishing(distributionDB: dbName, password: password)
        await loadReplication()
    }

    func removeDistribution() async {
        guard let mssql = session as? MSSQLSession else { return }
        isBusy = true
        let handle = activityEngine?.begin("Remove distribution", connectionSessionID: connectionSessionID)
        do {
            try await mssql.replication.removeDistributor(force: true)
            handle?.succeed()
            await loadReplication()
        } catch {
            handle?.fail(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
        isBusy = false
    }

    func createPublication(name: String, type: SQLServerPublicationType) async {
        guard let mssql = session as? MSSQLSession else { return }
        isBusy = true
        let handle = activityEngine?.begin("Create publication \(name)", connectionSessionID: connectionSessionID)
        do {
            try await mssql.replication.createPublication(name: name, type: type, database: databaseName)
            handle?.succeed()
            await loadReplication()
        } catch {
            handle?.fail(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
        isBusy = false
    }

    func createSubscription(publicationName: String, subscriberServer: String, subscriberDB: String) async {
        guard let mssql = session as? MSSQLSession else { return }
        isBusy = true
        let handle = activityEngine?.begin("Create subscription to \(publicationName)", connectionSessionID: connectionSessionID)
        do {
            try await mssql.replication.createSubscription(
                publicationName: publicationName,
                subscriberServer: subscriberServer,
                subscriberDB: subscriberDB
            )
            handle?.succeed()
            await loadReplication()
        } catch {
            handle?.fail(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
        isBusy = false
    }
}
