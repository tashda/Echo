import Foundation
import Observation
import SQLServerKit
import PostgresKit

@Observable
final class DatabaseEditorViewModel {
    let connectionSessionID: UUID
    let databaseName: String
    let databaseType: DatabaseType

    var isEditing: Bool { true }
    var isFormValid: Bool { true }

    // MARK: - Loading State

    var isLoading = true
    var errorMessage: String?
    var isSaving = false
    var statusMessage: String?

    // MARK: - Submit State

    var isSubmitting = false
    var didComplete = false

    // MARK: - MSSQL State

    var mssqlProps: SQLServerDatabaseProperties?
    var mssqlFiles: [SQLServerDatabaseFile] = []
    var recoveryModel: SQLServerDatabaseOption.RecoveryModel = .full
    var compatibilityLevel: Int = 160
    var isReadOnly = false
    var userAccess: SQLServerDatabaseOption.UserAccessOption = .multiUser
    var pageVerify: SQLServerDatabaseOption.PageVerifyOption = .checksum
    var targetRecoveryTime: Int = 0
    var delayedDurability: SQLServerDatabaseOption.DelayedDurabilityOption = .disabled
    var allowSnapshotIsolation = false
    var readCommittedSnapshot = false
    var isEncrypted = false
    var isBrokerEnabled = false
    var isTrustworthy = false
    var parameterization: SQLServerDatabaseOption.ParameterizationOption = .simple
    var autoClose = false
    var autoShrink = false
    var autoCreateStats = true
    var autoUpdateStats = true
    var autoUpdateStatsAsync = false
    var ansiNullDefault = false
    var ansiNulls = false
    var ansiPadding = false
    var ansiWarnings = false
    var arithAbort = false
    var concatNullYieldsNull = false
    var quotedIdentifier = false
    var recursiveTriggers = false
    var numericRoundAbort = false
    var dateCorrelation = false

    // MARK: - MSSQL Query Store State

    var qsDesiredState: String = "OFF"
    var qsActualState: String = "OFF"
    var qsMaxStorageMB: Int = 100
    var qsCurrentStorageMB: Int = 0
    var qsFlushIntervalSeconds: Int = 900
    var qsIntervalLengthMinutes: Int = 60
    var qsStaleThresholdDays: Int = 30
    var qsMaxPlansPerQuery: Int = 200
    var qsCaptureMode: String = "ALL"
    var qsCleanupMode: String = "AUTO"
    var qsWaitStatsMode: String = "ON"
    var qsCaptureExecutionCount: Int = 30
    var qsCaptureCompileCpuTimeMs: Int = 1000
    var qsCaptureExecutionCpuTimeMs: Int = 100
    var qsCaptureStalePolicyThresholdHours: Int = 24

    // MARK: - MSSQL File Editing State

    var fileSizeMBValues: [Int: Int] = [:]
    var fileMaxSizeTypes: [Int: FileMaxSizeType] = [:]
    var fileMaxSizeMBValues: [Int: Int] = [:]
    var fileGrowthTypes: [Int: FileGrowthType] = [:]
    var fileGrowthValues: [Int: Int] = [:]

    // MARK: - MSSQL Filegroups State

    var mssqlFilegroups: [SQLServerFilegroup] = []

    // MARK: - MSSQL Cursor & FILESTREAM State

    var cursorCloseOnCommit = false
    var cursorDefaultLocal = false
    var filestreamDirectoryName = ""
    var filestreamNonTransactedAccess: String = "OFF"
    var serviceBrokerGUID = ""
    var honorBrokerPriority = false

    // MARK: - MSSQL Mirroring State

    var mirroringStatus: SQLServerMirroringStatus?

    // MARK: - MSSQL Log Shipping State

    var logShippingConfig: SQLServerLogShippingConfig?

    // MARK: - MSSQL Scoped Configurations State

    var scopedConfigurations: [SQLServerScopedConfiguration] = []
    @ObservationIgnored var originalScopedConfigurations: [SQLServerScopedConfiguration] = []

    // MARK: - PostgreSQL State

    var pgProps: PostgresDatabaseProperties?
    var pgParams: [PostgresDatabaseParameter] = []
    var pgRoles: [String] = []
    var pgTablespaces: [String] = []
    var pgSchemas: [String] = []
    var pgOwner: String = ""
    var pgConnectionLimit: Int = -1
    var pgIsTemplate = false
    var pgAllowConnections = true
    var pgComment: String = ""

    // MARK: - PostgreSQL Parameters State

    var pgSettingDefinitions: [PostgresSettingDefinition] = []
    var pgOriginalParams: [PostgresDatabaseParameter] = []

    // MARK: - PostgreSQL Security State

    var pgACLEntries: [PostgresACLEntry] = []
    var pgACLExpanded: Set<String> = []

    // MARK: - PostgreSQL Default Privileges State

    var pgDefaultPrivileges: [PostgresDefaultPrivilege] = []
    var pgOriginalDefaultPrivileges: [PostgresDefaultPrivilege] = []
    var pgDefPrivExpanded: Set<String> = []

    // MARK: - ActivityEngine & Environment

    @ObservationIgnored var activityEngine: ActivityEngine?
    @ObservationIgnored var environmentState: EnvironmentState?
    @ObservationIgnored var notificationEngine: NotificationEngine?

    // MARK: - Computed Properties

    var isMSSQL: Bool { databaseType == .microsoftSQL }
    var isPostgres: Bool { databaseType == .postgresql }

    var pages: [DatabaseEditorPage] {
        if isMSSQL {
            return [.general, .files, .filegroups, .options, .scopedConfigurations, .queryStore, .mirroring, .logShipping]
        } else if isPostgres {
            return [.general, .definition, .parameters, .security, .defaultPrivileges, .sql]
        } else {
            return [.general]
        }
    }

    var compatibilityLevels: [(label: String, value: Int)] {
        [
            ("SQL Server 2022 (160)", 160),
            ("SQL Server 2019 (150)", 150),
            ("SQL Server 2017 (140)", 140),
            ("SQL Server 2016 (130)", 130),
            ("SQL Server 2014 (120)", 120),
            ("SQL Server 2012 (110)", 110),
            ("SQL Server 2008 (100)", 100),
        ]
    }

    // MARK: - Dirty Tracking

    @ObservationIgnored var snapshot: Snapshot?

    // MARK: - Init

    init(connectionSessionID: UUID, databaseName: String, databaseType: DatabaseType) {
        self.connectionSessionID = connectionSessionID
        self.databaseName = databaseName
        self.databaseType = databaseType
    }
}
