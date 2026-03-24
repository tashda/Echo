import Foundation
import SQLServerKit
import PostgresKit

// MARK: - Data Loading

extension DatabaseEditorViewModel {

    func ensurePageLoaded(_ page: DatabaseEditorPage, session: ConnectionSession) async {
        // All pages load eagerly during initial loadProperties
    }

    func loadProperties(session: ConnectionSession) async {
        do {
            switch databaseType {
            case .postgresql:
                try await loadPostgresProperties(session: session)
            case .microsoftSQL:
                try await loadMSSQLProperties(session: session)
            default:
                break
            }
            takeSnapshot()
            isLoading = false
        } catch {
            let raw = error.localizedDescription
            if raw.contains("column") && raw.contains("does not exist") {
                errorMessage = "Some properties are unavailable on this server version."
            } else if raw.contains("permission denied") {
                errorMessage = "Insufficient permissions to read database properties."
            } else {
                errorMessage = raw
            }
            isLoading = false
        }
    }

    func loadMSSQLProperties(session: ConnectionSession) async throws {
        guard let mssqlSession = session.session as? MSSQLSession else { return }
        let admin = mssqlSession.admin
        let props = try await admin.fetchDatabaseProperties(name: databaseName)
        mssqlProps = props

        recoveryModel = SQLServerDatabaseOption.RecoveryModel(rawValue: props.recoveryModel) ?? .full
        compatibilityLevel = props.compatibilityLevel
        isReadOnly = props.isReadOnly
        userAccess = SQLServerDatabaseOption.UserAccessOption.fromDescription(props.userAccessDescription)
        pageVerify = SQLServerDatabaseOption.PageVerifyOption(rawValue: props.pageVerifyOption) ?? .checksum
        targetRecoveryTime = props.targetRecoveryTimeSeconds
        delayedDurability = SQLServerDatabaseOption.DelayedDurabilityOption(rawValue: props.delayedDurability) ?? .disabled
        allowSnapshotIsolation = props.snapshotIsolationState.uppercased().contains("ON")
        readCommittedSnapshot = props.isReadCommittedSnapshotOn
        isEncrypted = props.isEncrypted
        isBrokerEnabled = props.isBrokerEnabled
        isTrustworthy = props.isTrustworthy
        parameterization = props.isParameterizationForced ? .forced : .simple
        autoClose = props.isAutoCloseOn
        autoShrink = props.isAutoShrinkOn
        autoCreateStats = props.isAutoCreateStatsOn
        autoUpdateStats = props.isAutoUpdateStatsOn
        autoUpdateStatsAsync = props.isAutoUpdateStatsAsyncOn
        ansiNullDefault = props.isAnsiNullDefaultOn
        ansiNulls = props.isAnsiNullsOn
        ansiPadding = props.isAnsiPaddingOn
        ansiWarnings = props.isAnsiWarningsOn
        arithAbort = props.isArithAbortOn
        concatNullYieldsNull = props.isConcatNullYieldsNullOn
        quotedIdentifier = props.isQuotedIdentifierOn
        recursiveTriggers = props.isRecursiveTriggersOn
        numericRoundAbort = props.isNumericRoundAbortOn
        dateCorrelation = props.isDateCorrelationOn

        mssqlFiles = (try? await admin.fetchDatabaseFiles(name: databaseName)) ?? []
        mssqlFilegroups = (try? await admin.listFilegroups(database: databaseName)) ?? []

        if let cursorDefs = try? await admin.fetchCursorDefaults(database: databaseName) {
            cursorCloseOnCommit = cursorDefs.isCursorCloseOnCommitOn
            cursorDefaultLocal = cursorDefs.isLocalCursorDefault
        }

        if let fsOpts = try? await admin.fetchFilestreamOptions(database: databaseName) {
            filestreamDirectoryName = fsOpts.directoryName
            filestreamNonTransactedAccess = fsOpts.nonTransactedAccessDescription
        }

        if let brokerProps = try? await admin.fetchServiceBrokerProperties(database: databaseName) {
            serviceBrokerGUID = brokerProps.serviceBrokerGUID
            honorBrokerPriority = brokerProps.isHonorBrokerPriorityOn
        }

        mirroringStatus = try? await admin.fetchMirroringStatus(database: databaseName)
        logShippingConfig = try? await admin.fetchLogShippingConfig(database: databaseName)
        scopedConfigurations = (try? await admin.listScopedConfigurations(database: databaseName)) ?? []
        originalScopedConfigurations = scopedConfigurations

        if let qsOpts = try? await mssqlSession.queryStore.options(database: databaseName) {
            populateQueryStoreState(qsOpts)
        }
    }

    func loadPostgresProperties(session: ConnectionSession) async throws {
        guard let pgSession = session.session as? PostgresSession else { return }
        let client = pgSession.client

        let props = try await client.introspection.fetchDatabaseProperties(name: databaseName)
        pgProps = props
        pgOwner = props.owner
        pgConnectionLimit = props.connectionLimit
        pgIsTemplate = props.isTemplate
        pgAllowConnections = props.allowConnections
        pgComment = props.description ?? ""

        pgParams = (try? await client.introspection.fetchDatabaseParameters(databaseOid: props.oid)) ?? []
        pgOriginalParams = pgParams

        let roles = (try? await client.security.listRoles()) ?? []
        pgRoles = roles.map(\.name).sorted()

        pgTablespaces = (try? await client.introspection.listTablespaces()) ?? ["pg_default"]
        pgSettingDefinitions = (try? await client.introspection.fetchDatabaseConfigurableSettings()) ?? []

        if let acl = props.acl {
            pgACLEntries = PostgresACLEntry.parse(acl: acl)
        }

        pgDefaultPrivileges = (try? await client.introspection.fetchDefaultPrivileges()) ?? []
        pgOriginalDefaultPrivileges = pgDefaultPrivileges

        let schemas = (try? await client.introspection.listSchemas()) ?? []
        pgSchemas = schemas.map(\.name).sorted()
    }

    func populateQueryStoreState(_ opts: SQLServerQueryStoreOptions) {
        qsActualState = opts.actualState
        qsDesiredState = opts.desiredState
        qsCurrentStorageMB = opts.currentStorageSizeMB
        qsMaxStorageMB = opts.maxStorageSizeMB
        qsFlushIntervalSeconds = opts.flushIntervalSeconds
        qsIntervalLengthMinutes = opts.intervalLengthMinutes
        qsStaleThresholdDays = opts.staleQueryThresholdDays
        qsMaxPlansPerQuery = opts.maxPlansPerQuery
        qsCaptureMode = opts.queryCaptureMode
        qsCleanupMode = opts.sizeBasedCleanupMode
        qsWaitStatsMode = opts.waitStatsCaptureMode
        qsCaptureExecutionCount = opts.captureExecutionCount
        qsCaptureCompileCpuTimeMs = opts.captureCompileCpuTimeMs
        qsCaptureExecutionCpuTimeMs = opts.captureExecutionCpuTimeMs
        qsCaptureStalePolicyThresholdHours = opts.captureStalePolicyThresholdHours
    }
}
