import SwiftUI
import SQLServerKit

// MARK: - MSSQL Query Store Page

extension DatabasePropertiesSheet {

    @ViewBuilder
    func mssqlQueryStorePage() -> some View {
        Section("Status") {
            LabeledContent("Actual State", value: qsActualState)
            LabeledContent("Storage", value: "\(qsCurrentStorageMB)/\(qsMaxStorageMB) MB")

            Picker("Operation Mode", selection: $qsDesiredState) {
                Text("Off").tag("OFF")
                Text("Read Only").tag("READ_ONLY")
                Text("Read Write").tag("READ_WRITE")
            }
            .onChange(of: qsDesiredState) { _, newValue in
                guard let state = QueryStoreDesiredState(rawValue: newValue) else { return }
                applyQueryStoreOption(.desiredState(state))
            }
        }

        Section("Data Collection") {
            Picker("Capture Mode", selection: $qsCaptureMode) {
                ForEach(QueryStoreCaptureMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode.rawValue)
                }
            }
            .onChange(of: qsCaptureMode) { _, newValue in
                guard let mode = QueryStoreCaptureMode(rawValue: newValue) else { return }
                applyQueryStoreOption(.queryCaptureMode(mode))
            }

            Picker("Wait Stats Capture", selection: $qsWaitStatsMode) {
                ForEach(QueryStoreWaitStatsMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode.rawValue)
                }
            }
            .onChange(of: qsWaitStatsMode) { _, newValue in
                guard let mode = QueryStoreWaitStatsMode(rawValue: newValue) else { return }
                applyQueryStoreOption(.waitStatsCaptureMode(mode))
            }
        }

        Section("Storage") {
            LabeledContent("Max Storage Size") {
                HStack(spacing: SpacingTokens.xs) {
                    TextField("", value: $qsMaxStorageMB, format: .number)
                        .frame(width: 80)
                        .onSubmit { applyQueryStoreOption(.maxStorageSizeMB(qsMaxStorageMB)) }
                    Text("MB")
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }

            Picker("Size-Based Cleanup", selection: $qsCleanupMode) {
                ForEach(QueryStoreCleanupMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode.rawValue)
                }
            }
            .onChange(of: qsCleanupMode) { _, newValue in
                guard let mode = QueryStoreCleanupMode(rawValue: newValue) else { return }
                applyQueryStoreOption(.sizeBasedCleanupMode(mode))
            }
        }

        Section("Intervals") {
            LabeledContent("Flush Interval") {
                HStack(spacing: SpacingTokens.xs) {
                    TextField("", value: $qsFlushIntervalSeconds, format: .number)
                        .frame(width: 80)
                        .onSubmit { applyQueryStoreOption(.flushIntervalSeconds(qsFlushIntervalSeconds)) }
                    Text("seconds")
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }

            LabeledContent("Statistics Interval") {
                HStack(spacing: SpacingTokens.xs) {
                    TextField("", value: $qsIntervalLengthMinutes, format: .number)
                        .frame(width: 80)
                        .onSubmit { applyQueryStoreOption(.intervalLengthMinutes(qsIntervalLengthMinutes)) }
                    Text("minutes")
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }

            LabeledContent("Stale Query Threshold") {
                HStack(spacing: SpacingTokens.xs) {
                    TextField("", value: $qsStaleThresholdDays, format: .number)
                        .frame(width: 80)
                        .onSubmit { applyQueryStoreOption(.staleQueryThresholdDays(qsStaleThresholdDays)) }
                    Text("days")
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }

            LabeledContent("Max Plans Per Query") {
                TextField("", value: $qsMaxPlansPerQuery, format: .number)
                    .frame(width: 80)
                    .onSubmit { applyQueryStoreOption(.maxPlansPerQuery(qsMaxPlansPerQuery)) }
            }
        }
    }

    // MARK: - Apply Query Store Option

    func applyQueryStoreOption(_ option: SQLServerQueryStoreOption) {
        guard let mssqlSession = session.session as? MSSQLSession else { return }
        let queryStoreClient = mssqlSession.queryStore
        isSaving = true
        statusMessage = nil

        Task {
            do {
                try await queryStoreClient.alterOption(database: databaseName, option: option)
                isSaving = false
                // Reload to reflect changes
                let updated = try await queryStoreClient.options(database: databaseName)
                populateQueryStoreState(updated)
            } catch {
                isSaving = false
                statusMessage = error.localizedDescription
            }
        }
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
    }
}
