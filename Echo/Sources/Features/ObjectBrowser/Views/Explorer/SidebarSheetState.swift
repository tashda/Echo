import SwiftUI

@Observable
final class SidebarSheetState {

    // MARK: - Agent Jobs

    var showNewJobSheet = false
    var newJobSessionID: UUID?

    // MARK: - Linked Servers

    var showNewLinkedServerSheet = false
    var newLinkedServerSessionID: UUID?
    var showDropLinkedServerAlert = false
    var dropLinkedServerTarget: DropLinkedServerTarget?

    struct DropLinkedServerTarget {
        let connectionID: UUID
        let serverName: String
    }

    // MARK: - Security (Server-Level)

    var showSecurityServerRoleSheet = false
    var securityServerRoleSheetSessionID: UUID?

    var showSecurityPGRoleSheet = false
    var securityPGRoleSheetEditName: String?
    var securityPGRoleSheetSessionID: UUID?

    var showNewServerRoleSheet = false
    var showNewCredentialSheet = false
    var newSecuritySheetSessionID: UUID?

    // MARK: - New Database

    var showNewDatabaseSheet = false
    var newDatabaseConnectionID: UUID?

    // MARK: - PostgreSQL Backup/Restore

    var showPgBackupSheet = false
    var showPgRestoreSheet = false
    var pgBackupDatabaseName: String?
    var pgBackupConnectionID: UUID?

    // MARK: - Database Mail

    var showDatabaseMailSheet = false
    var databaseMailConnectionID: UUID?

    // MARK: - Change Tracking / CDC

    var showChangeTrackingSheet = false
    var changeTrackingDatabaseName: String?
    var changeTrackingConnectionID: UUID?

    // MARK: - Full-Text Search

    var showFullTextSheet = false
    var fullTextDatabaseName: String?
    var fullTextConnectionID: UUID?

    // MARK: - Replication

    var showReplicationSheet = false
    var replicationDatabaseName: String?
    var replicationConnectionID: UUID?
    var pendingDropPublicationName: String?
    var pendingDropPublicationConnID: UUID?
    var pendingDropSubscriptionName: String?
    var pendingDropSubscriptionConnID: UUID?

    // MARK: - CMS

    var showCMSSheet = false
    var cmsConnectionID: UUID?

    // MARK: - Detach Database

    var showDetachSheet = false
    var detachDatabaseName: String?
    var detachConnectionID: UUID?

    // MARK: - Attach Database

    var showAttachSheet = false
    var attachConnectionID: UUID?

    // MARK: - Database Snapshots

    var showCreateSnapshotSheet = false
    var createSnapshotConnectionID: UUID?

    // MARK: - Drop Database

    var showDropDatabaseAlert = false
    var dropDatabaseTarget: DropDatabaseTarget?

    struct DropDatabaseTarget {
        let sessionID: UUID
        let connectionID: UUID
        let databaseName: String
        let databaseType: DatabaseType
        let variant: DropVariant
    }

    enum DropVariant {
        case standard
        case cascade
        case force
    }

    // MARK: - Drop Security Principal

    var showDropSecurityPrincipalAlert = false
    var dropSecurityPrincipalTarget: DropSecurityPrincipalTarget?

    struct DropSecurityPrincipalTarget {
        let sessionID: UUID
        let connectionID: UUID
        let name: String
        let kind: SecurityPrincipalKind
        /// Database name, only for database-scoped principals (e.g. MSSQL users).
        let databaseName: String?
    }

    enum SecurityPrincipalKind: String {
        case pgRole = "Role"
        case mssqlLogin = "Login"
        case mssqlUser = "User"
        case mssqlServerRole = "Server Role"
    }

    // MARK: - Server Triggers

    var showNewServerTriggerSheet = false
    var newServerTriggerConnectionID: UUID?

    // MARK: - Database DDL Triggers

    var showNewDBDDLTriggerSheet = false
    var newDBDDLTriggerConnectionID: UUID?
    var newDBDDLTriggerDatabaseName: String?

    // MARK: - Service Broker

    var showNewMessageTypeSheet = false
    var newMessageTypeConnectionID: UUID?
    var newMessageTypeDatabaseName: String?

    var showNewContractSheet = false
    var newContractConnectionID: UUID?
    var newContractDatabaseName: String?

    var showNewQueueSheet = false
    var newQueueConnectionID: UUID?
    var newQueueDatabaseName: String?

    var showNewServiceSheet = false
    var newServiceConnectionID: UUID?
    var newServiceDatabaseName: String?

    var showNewRouteSheet = false
    var newRouteConnectionID: UUID?
    var newRouteDatabaseName: String?

    // MARK: - External Resources (PolyBase)

    var showNewExternalDataSourceSheet = false
    var newExternalDataSourceConnectionID: UUID?
    var newExternalDataSourceDatabaseName: String?

    var showNewExternalFileFormatSheet = false
    var newExternalFileFormatConnectionID: UUID?
    var newExternalFileFormatDatabaseName: String?

    var showNewExternalTableSheet = false
    var newExternalTableConnectionID: UUID?
    var newExternalTableDatabaseName: String?

    // MARK: - Generate Scripts

    var showGenerateScriptsWizard = false
    var generateScriptsConnectionID: UUID?
    var generateScriptsDatabaseName: String?

    // MARK: - Quick Import

    var showQuickImportSheet = false
    var quickImportConnectionID: UUID?
    var quickImportDatabaseName: String?

    // MARK: - DAC Wizard

    var showDACWizard = false
    var dacWizardConnectionID: UUID?
    var dacWizardDatabaseName: String?

    // MARK: - Temporal (System Versioning)

    var showEnableVersioningSheet = false
    var enableVersioningConnectionID: UUID?
    var enableVersioningDatabaseName: String?
    var enableVersioningSchemaName: String?
    var enableVersioningTableName: String?
}
