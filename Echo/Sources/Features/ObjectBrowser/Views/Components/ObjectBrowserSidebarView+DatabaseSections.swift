import SwiftUI
import SQLServerKit

extension ObjectBrowserSidebarView {
    func loadDatabaseSecurity(database: DatabaseInfo, session: ConnectionSession) {
        guard let mssql = session.session as? MSSQLSession else { return }
        let key = ExplorerSourceKey(connectionID: session.connection.id, databaseName: database.name, source: .databaseSecurity)
        viewModel.beginLoading(key)

        Task {
            _ = try? await session.session.sessionForDatabase(database.name)
            let security = mssql.security
            let hiddenUsers: Set<String> = ["sys", "INFORMATION_SCHEMA"]
            let systemSchemas: Set<String> = [
                "sys", "INFORMATION_SCHEMA", "guest",
                "db_owner", "db_accessadmin", "db_securityadmin",
                "db_ddladmin", "db_backupoperator", "db_datareader",
                "db_datawriter", "db_denydatareader", "db_denydatawriter"
            ]

            let users = (try? await security.listUsers()) ?? []
            let roles = (try? await security.listRoles()) ?? []
            let schemas = (try? await security.listSchemas()) ?? []

            viewModel.finishLoading(key, items: [
                .users: users.filter { !hiddenUsers.contains($0.name) }.map {
                    ExplorerItem(id: $0.name, name: $0.name, detail: $0.defaultSchema)
                },
                .databaseRoles: roles.map {
                    ExplorerItem(id: $0.name, name: $0.name, detail: $0.isFixedRole ? "Fixed" : nil)
                },
                .applicationRoles: [],
                .schemas: schemas.filter { !systemSchemas.contains($0.name) }.map {
                    ExplorerItem(id: $0.name, name: $0.name, detail: $0.owner)
                },
            ])
        }
    }

    func loadDatabaseDDLTriggers(database: DatabaseInfo, session: ConnectionSession) {
        guard let mssql = session.session as? MSSQLSession else { return }
        let key = ExplorerSourceKey(connectionID: session.connection.id, databaseName: database.name, source: .databaseTriggers)
        viewModel.beginLoading(key)

        Task {
            let triggers = (try? await mssql.triggers.listDatabaseDDLTriggers(database: database.name)) ?? []
            viewModel.finishLoading(key, items: [.databaseTriggers: triggers.map {
                ExplorerItem(id: $0.name, name: $0.name, detail: $0.isDisabled ? "Disabled" : nil, isDisabled: $0.isDisabled)
            }])
        }
    }

    func loadServiceBrokerData(database: DatabaseInfo, session: ConnectionSession) {
        guard let mssql = session.session as? MSSQLSession else { return }
        let key = ExplorerSourceKey(connectionID: session.connection.id, databaseName: database.name, source: .serviceBroker)
        viewModel.beginLoading(key)

        Task {
            let broker = mssql.serviceBroker
            let name = database.name
            do {
                let messageTypes = try await broker.listMessageTypes(database: name).filter { !$0.isSystemObject }.map(\.name)
                let contracts = try await broker.listContracts(database: name).filter { !$0.isSystemObject }.map(\.name)
                let queues = try await broker.listQueues(database: name).map { "\($0.schema).\($0.name)" }
                let services = try await broker.listServices(database: name).filter { !$0.isSystemObject }.map(\.name)
                let routes = try await broker.listRoutes(database: name).map(\.name)
                let bindings = try await broker.listRemoteServiceBindings(database: name).map(\.name)
                viewModel.finishLoading(key, items: [
                    .messageTypes: Self.namedItems(messageTypes),
                    .contracts: Self.namedItems(contracts),
                    .queues: Self.namedItems(queues),
                    .services: Self.namedItems(services),
                    .routes: Self.namedItems(routes),
                    .remoteServiceBindings: Self.namedItems(bindings),
                ])
            } catch {
                viewModel.finishLoading(key, items: [:])
            }
        }
    }

    func loadExternalResources(database: DatabaseInfo, session: ConnectionSession) {
        guard let mssql = session.session as? MSSQLSession else { return }
        let key = ExplorerSourceKey(connectionID: session.connection.id, databaseName: database.name, source: .externalResources)
        viewModel.beginLoading(key)

        Task {
            let polyBase = mssql.polyBase
            let name = database.name
            do {
                let sources = try await polyBase.listExternalDataSources(database: name).map(\.name)
                let tables = try await polyBase.listExternalTables(database: name).map { "\($0.schema).\($0.name)" }
                let formats = try await polyBase.listExternalFileFormats(database: name).map(\.name)
                viewModel.finishLoading(key, items: [
                    .externalDataSources: Self.namedItems(sources),
                    .externalTables: Self.namedItems(tables),
                    .externalFileFormats: Self.namedItems(formats),
                ])
            } catch {
                viewModel.finishLoading(key, items: [:])
            }
        }
    }

    private static func namedItems(_ names: [String]) -> [ExplorerItem] {
        names.map { ExplorerItem(id: $0, name: $0) }
    }
}
