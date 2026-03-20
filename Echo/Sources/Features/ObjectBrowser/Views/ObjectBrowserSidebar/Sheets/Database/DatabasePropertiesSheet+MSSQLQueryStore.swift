import SwiftUI
import SQLServerKit

// MARK: - MSSQL Query Store Page

extension DatabasePropertiesSheet {

    @ViewBuilder
    func mssqlQueryStorePage() -> some View {
        Section("Status") {
            PropertyRow(title: "Actual State") {
                Text(qsActualState)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            
            PropertyRow(title: "Storage") {
                Text("\(qsCurrentStorageMB)/\(qsMaxStorageMB) MB")
                    .foregroundStyle(ColorTokens.Text.secondary)
            }

            PropertyRow(title: "Operation Mode") {
                Picker("", selection: $qsDesiredState) {
                    Text("Off").tag("OFF")
                    Text("Read Only").tag("READ_ONLY")
                    Text("Read Write").tag("READ_WRITE")
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
            .onChange(of: qsDesiredState) { _, newValue in
                guard let state = QueryStoreDesiredState(rawValue: newValue) else { return }
                applyQueryStoreOption(.desiredState(state))
            }
        }

        Section("Data Collection") {
            PropertyRow(title: "Capture Mode") {
                Picker("", selection: $qsCaptureMode) {
                    ForEach(QueryStoreCaptureMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
            .onChange(of: qsCaptureMode) { _, newValue in
                guard let mode = QueryStoreCaptureMode(rawValue: newValue) else { return }
                applyQueryStoreOption(.queryCaptureMode(mode))
            }

            PropertyRow(title: "Wait Stats Capture") {
                Picker("", selection: $qsWaitStatsMode) {
                    ForEach(QueryStoreWaitStatsMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
            .onChange(of: qsWaitStatsMode) { _, newValue in
                guard let mode = QueryStoreWaitStatsMode(rawValue: newValue) else { return }
                applyQueryStoreOption(.waitStatsCaptureMode(mode))
            }
        }

        Section("Storage") {
            PropertyRow(title: "Max Storage Size", subtitle: "MB") {
                TextField("", value: $qsMaxStorageMB, format: .number, prompt: Text("100"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .onSubmit { applyQueryStoreOption(.maxStorageSizeMB(qsMaxStorageMB)) }
            }

            PropertyRow(title: "Size-Based Cleanup") {
                Picker("", selection: $qsCleanupMode) {
                    ForEach(QueryStoreCleanupMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
            .onChange(of: qsCleanupMode) { _, newValue in
                guard let mode = QueryStoreCleanupMode(rawValue: newValue) else { return }
                applyQueryStoreOption(.sizeBasedCleanupMode(mode))
            }
        }

        Section("Intervals") {
            PropertyRow(title: "Flush Interval", subtitle: "seconds") {
                TextField("", value: $qsFlushIntervalSeconds, format: .number, prompt: Text("900"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .onSubmit { applyQueryStoreOption(.flushIntervalSeconds(qsFlushIntervalSeconds)) }
            }

            PropertyRow(title: "Statistics Interval", subtitle: "minutes") {
                TextField("", value: $qsIntervalLengthMinutes, format: .number, prompt: Text("60"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .onSubmit { applyQueryStoreOption(.intervalLengthMinutes(qsIntervalLengthMinutes)) }
            }

            PropertyRow(title: "Stale Query Threshold", subtitle: "days") {
                TextField("", value: $qsStaleThresholdDays, format: .number, prompt: Text("30"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .onSubmit { applyQueryStoreOption(.staleQueryThresholdDays(qsStaleThresholdDays)) }
            }

            PropertyRow(title: "Max Plans Per Query", subtitle: "plans") {
                TextField("", value: $qsMaxPlansPerQuery, format: .number, prompt: Text("200"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
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
