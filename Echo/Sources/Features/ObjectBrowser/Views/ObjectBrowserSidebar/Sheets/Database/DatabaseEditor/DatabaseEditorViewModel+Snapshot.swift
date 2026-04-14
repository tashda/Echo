import Foundation
import SQLServerKit

// MARK: - Dirty Tracking

extension DatabaseEditorViewModel {

    struct Snapshot {
        let recoveryModel: SQLServerDatabaseOption.RecoveryModel
        let compatibilityLevel: Int
        let isReadOnly: Bool
        let userAccess: SQLServerDatabaseOption.UserAccessOption
        let allowSnapshotIsolation: Bool
        let readCommittedSnapshot: Bool
        let isEncrypted: Bool
        let isBrokerEnabled: Bool
        let isTrustworthy: Bool
        let parameterization: SQLServerDatabaseOption.ParameterizationOption
        let autoClose: Bool
        let autoShrink: Bool
        let autoCreateStats: Bool
        let autoUpdateStats: Bool
        let autoUpdateStatsAsync: Bool
        let ansiNullDefault: Bool
        let ansiNulls: Bool
        let ansiPadding: Bool
        let ansiWarnings: Bool
        let arithAbort: Bool
        let concatNullYieldsNull: Bool
        let quotedIdentifier: Bool
        let recursiveTriggers: Bool
        let numericRoundAbort: Bool
        let dateCorrelation: Bool
        let cursorCloseOnCommit: Bool
        let cursorDefaultLocal: Bool
        let qsDesiredState: String
        let qsCaptureMode: String
        let qsWaitStatsMode: String
        let qsCleanupMode: String
        let qsMaxStorageMB: Int
        let qsFlushIntervalSeconds: Int
        let qsIntervalLengthMinutes: Int
        let qsStaleThresholdDays: Int
        let qsMaxPlansPerQuery: Int
        let qsCaptureExecutionCount: Int
        let qsCaptureCompileCpuTimeMs: Int
        let qsCaptureExecutionCpuTimeMs: Int
        let qsCaptureStalePolicyThresholdHours: Int
        let pgOwner: String
        let pgConnectionLimit: Int
        let pgIsTemplate: Bool
        let pgAllowConnections: Bool
        let pgComment: String
    }

    func takeSnapshot() {
        snapshot = Snapshot(
            recoveryModel: recoveryModel,
            compatibilityLevel: compatibilityLevel,
            isReadOnly: isReadOnly,
            userAccess: userAccess,
            allowSnapshotIsolation: allowSnapshotIsolation,
            readCommittedSnapshot: readCommittedSnapshot,
            isEncrypted: isEncrypted,
            isBrokerEnabled: isBrokerEnabled,
            isTrustworthy: isTrustworthy,
            parameterization: parameterization,
            autoClose: autoClose,
            autoShrink: autoShrink,
            autoCreateStats: autoCreateStats,
            autoUpdateStats: autoUpdateStats,
            autoUpdateStatsAsync: autoUpdateStatsAsync,
            ansiNullDefault: ansiNullDefault,
            ansiNulls: ansiNulls,
            ansiPadding: ansiPadding,
            ansiWarnings: ansiWarnings,
            arithAbort: arithAbort,
            concatNullYieldsNull: concatNullYieldsNull,
            quotedIdentifier: quotedIdentifier,
            recursiveTriggers: recursiveTriggers,
            numericRoundAbort: numericRoundAbort,
            dateCorrelation: dateCorrelation,
            cursorCloseOnCommit: cursorCloseOnCommit,
            cursorDefaultLocal: cursorDefaultLocal,
            qsDesiredState: qsDesiredState,
            qsCaptureMode: qsCaptureMode,
            qsWaitStatsMode: qsWaitStatsMode,
            qsCleanupMode: qsCleanupMode,
            qsMaxStorageMB: qsMaxStorageMB,
            qsFlushIntervalSeconds: qsFlushIntervalSeconds,
            qsIntervalLengthMinutes: qsIntervalLengthMinutes,
            qsStaleThresholdDays: qsStaleThresholdDays,
            qsMaxPlansPerQuery: qsMaxPlansPerQuery,
            qsCaptureExecutionCount: qsCaptureExecutionCount,
            qsCaptureCompileCpuTimeMs: qsCaptureCompileCpuTimeMs,
            qsCaptureExecutionCpuTimeMs: qsCaptureExecutionCpuTimeMs,
            qsCaptureStalePolicyThresholdHours: qsCaptureStalePolicyThresholdHours,
            pgOwner: pgOwner,
            pgConnectionLimit: pgConnectionLimit,
            pgIsTemplate: pgIsTemplate,
            pgAllowConnections: pgAllowConnections,
            pgComment: pgComment
        )
    }

    var hasChanges: Bool {
        guard let snapshot else { return false }

        if recoveryModel != snapshot.recoveryModel { return true }
        if compatibilityLevel != snapshot.compatibilityLevel { return true }
        if isReadOnly != snapshot.isReadOnly { return true }
        if userAccess != snapshot.userAccess { return true }
        if allowSnapshotIsolation != snapshot.allowSnapshotIsolation { return true }
        if readCommittedSnapshot != snapshot.readCommittedSnapshot { return true }
        if isEncrypted != snapshot.isEncrypted { return true }
        if isBrokerEnabled != snapshot.isBrokerEnabled { return true }
        if isTrustworthy != snapshot.isTrustworthy { return true }
        if parameterization != snapshot.parameterization { return true }
        if autoClose != snapshot.autoClose { return true }
        if autoShrink != snapshot.autoShrink { return true }
        if autoCreateStats != snapshot.autoCreateStats { return true }
        if autoUpdateStats != snapshot.autoUpdateStats { return true }
        if autoUpdateStatsAsync != snapshot.autoUpdateStatsAsync { return true }
        if ansiNullDefault != snapshot.ansiNullDefault { return true }
        if ansiNulls != snapshot.ansiNulls { return true }
        if ansiPadding != snapshot.ansiPadding { return true }
        if ansiWarnings != snapshot.ansiWarnings { return true }
        if arithAbort != snapshot.arithAbort { return true }
        if concatNullYieldsNull != snapshot.concatNullYieldsNull { return true }
        if quotedIdentifier != snapshot.quotedIdentifier { return true }
        if recursiveTriggers != snapshot.recursiveTriggers { return true }
        if numericRoundAbort != snapshot.numericRoundAbort { return true }
        if dateCorrelation != snapshot.dateCorrelation { return true }
        if cursorCloseOnCommit != snapshot.cursorCloseOnCommit { return true }
        if cursorDefaultLocal != snapshot.cursorDefaultLocal { return true }
        if qsDesiredState != snapshot.qsDesiredState { return true }
        if qsCaptureMode != snapshot.qsCaptureMode { return true }
        if qsWaitStatsMode != snapshot.qsWaitStatsMode { return true }
        if qsCleanupMode != snapshot.qsCleanupMode { return true }
        if qsMaxStorageMB != snapshot.qsMaxStorageMB { return true }
        if qsFlushIntervalSeconds != snapshot.qsFlushIntervalSeconds { return true }
        if qsIntervalLengthMinutes != snapshot.qsIntervalLengthMinutes { return true }
        if qsStaleThresholdDays != snapshot.qsStaleThresholdDays { return true }
        if qsMaxPlansPerQuery != snapshot.qsMaxPlansPerQuery { return true }
        if qsCaptureExecutionCount != snapshot.qsCaptureExecutionCount { return true }
        if qsCaptureCompileCpuTimeMs != snapshot.qsCaptureCompileCpuTimeMs { return true }
        if qsCaptureExecutionCpuTimeMs != snapshot.qsCaptureExecutionCpuTimeMs { return true }
        if qsCaptureStalePolicyThresholdHours != snapshot.qsCaptureStalePolicyThresholdHours { return true }
        if pgOwner != snapshot.pgOwner { return true }
        if pgConnectionLimit != snapshot.pgConnectionLimit { return true }
        if pgIsTemplate != snapshot.pgIsTemplate { return true }
        if pgAllowConnections != snapshot.pgAllowConnections { return true }
        if pgComment != snapshot.pgComment { return true }

        // Scoped configuration changes
        let originalMap = Dictionary(originalScopedConfigurations.map { ($0.configurationID, $0.value) }, uniquingKeysWith: { _, b in b })
        for config in scopedConfigurations {
            if let origVal = originalMap[config.configurationID], origVal != config.value { return true }
        }

        return false
    }
}
