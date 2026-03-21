import Foundation
import SQLServerKit
import Logging

final class MSSQLDedicatedQuerySession: DatabaseSession, MSSQLSession, @unchecked Sendable {
    private var connection: SQLServerConnection
    private let connectionConfiguration: SQLServerConnection.Configuration
    private var reconnectTask: Task<SQLServerConnection, Error>?
    let metadataSession: SQLServerSessionAdapter
    let logger = Logger(label: "dk.tippr.echo.mssql.query")

    init(
        connection: SQLServerConnection,
        configuration: SQLServerConnection.Configuration,
        metadataSession: SQLServerSessionAdapter
    ) {
        self.connection = connection
        self.connectionConfiguration = configuration
        self.metadataSession = metadataSession
    }

    var database: String? {
        connection.currentDatabase
    }

    func close() async {
        reconnectTask?.cancel()
        reconnectTask = nil
        do {
            try await connection.close()
        } catch {
            logger.debug("Dedicated query connection close failed: \(error.localizedDescription)")
        }
    }

    func serverVersion() async throws -> String {
        let connection = try await readyConnection()
        return try await connection.serverVersion()
    }

    func readyConnection() async throws -> SQLServerConnection {
        if let reconnectTask {
            let reconnected = try await reconnectTask.value
            connection = reconnected
            self.reconnectTask = nil
        }
        return connection
    }

    func reconnectAfterCancellation() {
        guard reconnectTask == nil else { return }

        let previousConnection = connection
        let configuration = connectionConfiguration
        let targetDatabase = connection.currentDatabase

        reconnectTask = Task {
            do {
                try await previousConnection.close()
            } catch {
                self.logger.debug("Dedicated query connection close before reconnect failed: \(error.localizedDescription)")
            }

            let newConnection = try await SQLServerConnection.connect(configuration: configuration)
            if !targetDatabase.isEmpty,
               newConnection.currentDatabase.caseInsensitiveCompare(targetDatabase) != .orderedSame {
                try await newConnection.changeDatabase(targetDatabase)
            }
            return newConnection
        }
    }

    var metadata: SQLServerMetadataNamespace { metadataSession.metadata }
    var agent: SQLServerAgentOperations { metadataSession.agent }
    var admin: SQLServerAdministrationClient { metadataSession.admin }
    var security: SQLServerSecurityClient { metadataSession.security }
    var serverSecurity: SQLServerServerSecurityClient { metadataSession.serverSecurity }
    var extendedProperties: SQLServerExtendedPropertiesClient { metadataSession.extendedProperties }
    var queryStore: SQLServerQueryStoreClient { metadataSession.queryStore }
    var backupRestore: SQLServerBackupRestoreClient { metadataSession.backupRestore }
    var linkedServers: SQLServerLinkedServersClient { metadataSession.linkedServers }
    var extendedEvents: SQLServerExtendedEventsClient { metadataSession.extendedEvents }
    var availabilityGroups: SQLServerAvailabilityGroupsClient { metadataSession.availabilityGroups }
    var databaseMail: SQLServerDatabaseMailClient { metadataSession.databaseMail }
    var changeTracking: SQLServerChangeTrackingClient { metadataSession.changeTracking }
    var fullText: SQLServerFullTextClient { metadataSession.fullText }
    var maintenance: SQLServerMaintenanceClient { metadataSession.maintenance }
    var replication: SQLServerReplicationClient { metadataSession.replication }
    var cms: SQLServerCMSClient { metadataSession.cms }
}
