import Foundation
import SQLServerKit
import PostgresKit

// MARK: - Submit Changes

extension DatabaseEditorViewModel {

    func submitChanges(session: ConnectionSession) async throws {
        switch databaseType {
        case .microsoftSQL:
            try await submitMSSQLChanges(session: session)
        case .postgresql:
            try await submitPostgresChanges(session: session)
        default:
            break
        }
        await environmentState?.refreshDatabaseStructure(for: session.id)
    }

    private func submitMSSQLChanges(session: ConnectionSession) async throws {
        guard let mssqlSession = session.session as? MSSQLSession else { return }
        guard let snap = snapshot else { return }
        let admin = mssqlSession.admin

        var options: [SQLServerDatabaseOption] = []

        if recoveryModel != snap.recoveryModel { options.append(.recoveryModel(recoveryModel)) }
        if compatibilityLevel != snap.compatibilityLevel { options.append(.compatibilityLevel(compatibilityLevel)) }
        if isReadOnly != snap.isReadOnly { options.append(.readOnly(isReadOnly)) }
        if userAccess != snap.userAccess { options.append(.userAccess(userAccess)) }
        if allowSnapshotIsolation != snap.allowSnapshotIsolation { options.append(.allowSnapshotIsolation(allowSnapshotIsolation)) }
        if readCommittedSnapshot != snap.readCommittedSnapshot { options.append(.readCommittedSnapshot(readCommittedSnapshot)) }
        if isEncrypted != snap.isEncrypted { options.append(.encryption(isEncrypted)) }
        if isBrokerEnabled != snap.isBrokerEnabled { options.append(.brokerEnabled(isBrokerEnabled)) }
        if isTrustworthy != snap.isTrustworthy { options.append(.trustworthy(isTrustworthy)) }
        if parameterization != snap.parameterization { options.append(.parameterization(parameterization)) }
        if autoClose != snap.autoClose { options.append(.autoClose(autoClose)) }
        if autoShrink != snap.autoShrink { options.append(.autoShrink(autoShrink)) }
        if autoCreateStats != snap.autoCreateStats { options.append(.autoCreateStatistics(autoCreateStats)) }
        if autoUpdateStats != snap.autoUpdateStats { options.append(.autoUpdateStatistics(autoUpdateStats)) }
        if autoUpdateStatsAsync != snap.autoUpdateStatsAsync { options.append(.autoUpdateStatisticsAsync(autoUpdateStatsAsync)) }
        if ansiNullDefault != snap.ansiNullDefault { options.append(.ansiNullDefault(ansiNullDefault)) }
        if ansiNulls != snap.ansiNulls { options.append(.ansiNulls(ansiNulls)) }
        if ansiPadding != snap.ansiPadding { options.append(.ansiPadding(ansiPadding)) }
        if ansiWarnings != snap.ansiWarnings { options.append(.ansiWarnings(ansiWarnings)) }
        if arithAbort != snap.arithAbort { options.append(.arithAbort(arithAbort)) }
        if concatNullYieldsNull != snap.concatNullYieldsNull { options.append(.concatNullYieldsNull(concatNullYieldsNull)) }
        if quotedIdentifier != snap.quotedIdentifier { options.append(.quotedIdentifier(quotedIdentifier)) }
        if recursiveTriggers != snap.recursiveTriggers { options.append(.recursiveTriggers(recursiveTriggers)) }
        if numericRoundAbort != snap.numericRoundAbort { options.append(.numericRoundAbort(numericRoundAbort)) }
        if dateCorrelation != snap.dateCorrelation { options.append(.dateCorrelationOptimization(dateCorrelation)) }
        if cursorCloseOnCommit != snap.cursorCloseOnCommit { options.append(.cursorCloseOnCommit(cursorCloseOnCommit)) }
        if cursorDefaultLocal != snap.cursorDefaultLocal { options.append(.cursorDefaultLocal(cursorDefaultLocal)) }

        for option in options {
            _ = try await admin.alterDatabaseOption(name: databaseName, option: option)
        }

        // Apply changed Query Store options
        let qsClient = mssqlSession.queryStore
        if qsDesiredState != snap.qsDesiredState, let state = QueryStoreDesiredState(rawValue: qsDesiredState) {
            try await qsClient.alterOption(database: databaseName, option: .desiredState(state))
        }
        if qsCaptureMode != snap.qsCaptureMode, let mode = QueryStoreCaptureMode(rawValue: qsCaptureMode) {
            if mode == .custom {
                try await qsClient.alterOption(database: databaseName, option: .customCapturePolicy(
                    executionCount: qsCaptureExecutionCount,
                    compileCpuTimeMs: qsCaptureCompileCpuTimeMs,
                    executionCpuTimeMs: qsCaptureExecutionCpuTimeMs,
                    stalePolicyThresholdHours: qsCaptureStalePolicyThresholdHours
                ))
            } else {
                try await qsClient.alterOption(database: databaseName, option: .queryCaptureMode(mode))
            }
        }
        if qsWaitStatsMode != snap.qsWaitStatsMode, let mode = QueryStoreWaitStatsMode(rawValue: qsWaitStatsMode) {
            try await qsClient.alterOption(database: databaseName, option: .waitStatsCaptureMode(mode))
        }
        if qsCleanupMode != snap.qsCleanupMode, let mode = QueryStoreCleanupMode(rawValue: qsCleanupMode) {
            try await qsClient.alterOption(database: databaseName, option: .sizeBasedCleanupMode(mode))
        }
        if qsMaxStorageMB != snap.qsMaxStorageMB {
            try await qsClient.alterOption(database: databaseName, option: .maxStorageSizeMB(qsMaxStorageMB))
        }
        if qsFlushIntervalSeconds != snap.qsFlushIntervalSeconds {
            try await qsClient.alterOption(database: databaseName, option: .flushIntervalSeconds(qsFlushIntervalSeconds))
        }
        if qsIntervalLengthMinutes != snap.qsIntervalLengthMinutes {
            try await qsClient.alterOption(database: databaseName, option: .intervalLengthMinutes(qsIntervalLengthMinutes))
        }
        if qsStaleThresholdDays != snap.qsStaleThresholdDays {
            try await qsClient.alterOption(database: databaseName, option: .staleQueryThresholdDays(qsStaleThresholdDays))
        }
        if qsMaxPlansPerQuery != snap.qsMaxPlansPerQuery {
            try await qsClient.alterOption(database: databaseName, option: .maxPlansPerQuery(qsMaxPlansPerQuery))
        }

        // Reload QS state from server
        if let qsOpts = try? await qsClient.options(database: databaseName) {
            populateQueryStoreState(qsOpts)
        }

        // Apply changed scoped configurations
        let originalMap = Dictionary(originalScopedConfigurations.map { ($0.configurationID, $0.value) }, uniquingKeysWith: { _, b in b })
        for config in scopedConfigurations {
            if let originalValue = originalMap[config.configurationID], originalValue != config.value {
                _ = try await admin.alterScopedConfiguration(database: databaseName, name: config.name, value: config.value)
            }
        }
        // Reload to reflect server's actual state
        scopedConfigurations = (try? await admin.listScopedConfigurations(database: databaseName)) ?? scopedConfigurations
        originalScopedConfigurations = scopedConfigurations
    }

    private func submitPostgresChanges(session: ConnectionSession) async throws {
        guard let pgSession = session.session as? PostgresSession else { return }
        guard let snap = snapshot else { return }
        let client = pgSession.client

        if pgOwner != snap.pgOwner {
            try await client.admin.alterDatabaseOwner(name: databaseName, newOwner: pgOwner)
        }
        if pgConnectionLimit != snap.pgConnectionLimit {
            try await client.admin.alterDatabaseConnectionLimit(name: databaseName, limit: pgConnectionLimit)
        }
        if pgIsTemplate != snap.pgIsTemplate {
            try await client.admin.alterDatabaseIsTemplate(name: databaseName, isTemplate: pgIsTemplate)
        }
        if pgAllowConnections != snap.pgAllowConnections {
            try await client.admin.alterDatabaseAllowConnections(name: databaseName, allow: pgAllowConnections)
        }

        // Parameter and default privilege changes are saved via pgSaveParameterChanges
        // and pgSaveDefaultPrivilegeChanges which are called from their respective pages
    }
}
