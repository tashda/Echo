import SwiftUI
import SQLServerKit

extension ExperimentalObjectBrowserSidebarView {
    func loadDatabaseSecurityIfNeeded(database: DatabaseInfo, session: ConnectionSession) {
        let dbKey = viewModel.databaseStorageKey(connectionID: session.connection.id, databaseName: database.name)
        let hasData = !(viewModel.dbSecurityUsersByDB[dbKey] ?? []).isEmpty
            || !(viewModel.dbSecurityRolesByDB[dbKey] ?? []).isEmpty
            || !(viewModel.dbSecurityAppRolesByDB[dbKey] ?? []).isEmpty
            || !(viewModel.dbSecuritySchemasByDB[dbKey] ?? []).isEmpty
        let isLoading = viewModel.dbSecurityLoadingByDB[dbKey] ?? false
        if !hasData && !isLoading {
            loadDatabaseSecurity(database: database, session: session)
        }
    }

    func loadDatabaseSecurity(database: DatabaseInfo, session: ConnectionSession) {
        let dbKey = viewModel.databaseStorageKey(connectionID: session.connection.id, databaseName: database.name)
        viewModel.dbSecurityLoadingByDB[dbKey] = true

        Task {
            defer { viewModel.dbSecurityLoadingByDB[dbKey] = false }
            guard let mssql = session.session as? MSSQLSession else { return }
            _ = try? await session.session.sessionForDatabase(database.name)
            let security = mssql.security

            do {
                let users = try await security.listUsers()
                viewModel.dbSecurityUsersByDB[dbKey] = users
                    .filter { $0.name != "sys" && $0.name != "INFORMATION_SCHEMA" }
                    .map { .init(id: $0.name, name: $0.name, userType: String(describing: $0.type), defaultSchema: $0.defaultSchema) }
            } catch {
                viewModel.dbSecurityUsersByDB[dbKey] = []
            }

            do {
                let roles = try await security.listRoles()
                viewModel.dbSecurityRolesByDB[dbKey] = roles.map {
                    .init(id: $0.name, name: $0.name, isFixed: $0.isFixedRole, owner: $0.ownerPrincipalId.map(String.init))
                }
            } catch {
                viewModel.dbSecurityRolesByDB[dbKey] = []
            }

            viewModel.dbSecurityAppRolesByDB[dbKey] = []

            do {
                let schemas = try await security.listSchemas()
                let systemSchemas: Set<String> = [
                    "sys", "INFORMATION_SCHEMA", "guest",
                    "db_owner", "db_accessadmin", "db_securityadmin",
                    "db_ddladmin", "db_backupoperator", "db_datareader",
                    "db_datawriter", "db_denydatareader", "db_denydatawriter"
                ]
                viewModel.dbSecuritySchemasByDB[dbKey] = schemas
                    .filter { !systemSchemas.contains($0.name) }
                    .map { .init(id: $0.name, name: $0.name, owner: $0.owner) }
            } catch {
                viewModel.dbSecuritySchemasByDB[dbKey] = []
            }
        }
    }

    func loadDatabaseDDLTriggers(database: DatabaseInfo, session: ConnectionSession) {
        let dbKey = viewModel.databaseStorageKey(connectionID: session.connection.id, databaseName: database.name)
        guard let mssql = session.session as? MSSQLSession else { return }
        viewModel.dbDDLTriggersLoadingByDB[dbKey] = true

        Task {
            defer { viewModel.dbDDLTriggersLoadingByDB[dbKey] = false }
            do {
                let triggers = try await mssql.triggers.listDatabaseDDLTriggers(database: database.name)
                viewModel.dbDDLTriggersByDB[dbKey] = triggers.map {
                    .init(id: $0.name, name: $0.name, isDisabled: $0.isDisabled, events: $0.events)
                }
            } catch {
                viewModel.dbDDLTriggersByDB[dbKey] = []
            }
        }
    }

    func loadServiceBrokerData(database: DatabaseInfo, session: ConnectionSession) {
        let dbKey = viewModel.databaseStorageKey(connectionID: session.connection.id, databaseName: database.name)
        guard let mssql = session.session as? MSSQLSession else { return }
        viewModel.serviceBrokerLoadingByDB[dbKey] = true

        Task {
            defer { viewModel.serviceBrokerLoadingByDB[dbKey] = false }
            do {
                let broker = mssql.serviceBroker
                let dbName = database.name
                let messageTypes = try await broker.listMessageTypes(database: dbName)
                let contracts = try await broker.listContracts(database: dbName)
                let queues = try await broker.listQueues(database: dbName)
                let services = try await broker.listServices(database: dbName)
                let routes = try await broker.listRoutes(database: dbName)
                let bindings = try await broker.listRemoteServiceBindings(database: dbName)

                viewModel.serviceBrokerMessageTypesByDB[dbKey] = messageTypes.filter { !$0.isSystemObject }.map(\.name)
                viewModel.serviceBrokerContractsByDB[dbKey] = contracts.filter { !$0.isSystemObject }.map(\.name)
                viewModel.serviceBrokerQueuesByDB[dbKey] = queues.map { "\($0.schema).\($0.name)" }
                viewModel.serviceBrokerServicesByDB[dbKey] = services.filter { !$0.isSystemObject }.map(\.name)
                viewModel.serviceBrokerRoutesByDB[dbKey] = routes.map(\.name)
                viewModel.serviceBrokerBindingsByDB[dbKey] = bindings.map(\.name)
            } catch {
                viewModel.serviceBrokerMessageTypesByDB[dbKey] = []
                viewModel.serviceBrokerContractsByDB[dbKey] = []
                viewModel.serviceBrokerQueuesByDB[dbKey] = []
                viewModel.serviceBrokerServicesByDB[dbKey] = []
                viewModel.serviceBrokerRoutesByDB[dbKey] = []
                viewModel.serviceBrokerBindingsByDB[dbKey] = []
            }
        }
    }

    func loadExternalResources(database: DatabaseInfo, session: ConnectionSession) {
        let dbKey = viewModel.databaseStorageKey(connectionID: session.connection.id, databaseName: database.name)
        guard let mssql = session.session as? MSSQLSession else { return }
        viewModel.externalResourcesLoadingByDB[dbKey] = true

        Task {
            defer { viewModel.externalResourcesLoadingByDB[dbKey] = false }
            do {
                let polyBase = mssql.polyBase
                let dbName = database.name
                let sources = try await polyBase.listExternalDataSources(database: dbName)
                let tables = try await polyBase.listExternalTables(database: dbName)
                let formats = try await polyBase.listExternalFileFormats(database: dbName)
                viewModel.externalDataSourcesByDB[dbKey] = sources.map(\.name)
                viewModel.externalTablesByDB[dbKey] = tables.map { "\($0.schema).\($0.name)" }
                viewModel.externalFileFormatsByDB[dbKey] = formats.map(\.name)
            } catch {
                viewModel.externalDataSourcesByDB[dbKey] = []
                viewModel.externalTablesByDB[dbKey] = []
                viewModel.externalFileFormatsByDB[dbKey] = []
            }
        }
    }
}
