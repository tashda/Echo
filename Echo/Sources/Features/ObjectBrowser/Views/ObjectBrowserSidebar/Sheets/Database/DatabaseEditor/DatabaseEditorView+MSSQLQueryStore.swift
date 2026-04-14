import SwiftUI
import SQLServerKit

// MARK: - MSSQL Query Store Page

extension DatabaseEditorView {

    @ViewBuilder
    func mssqlQueryStorePage() -> some View {
        Section("Operation Mode") {
            PropertyRow(title: "Operation Mode", info: "Controls whether Query Store is actively capturing data (Read Write), serving cached data only (Read Only), or disabled (Off).") {
                Picker("", selection: $viewModel.qsDesiredState) {
                    Text("Off").tag("OFF")
                    Text("Read Only").tag("READ_ONLY")
                    Text("Read Write").tag("READ_WRITE")
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
        }

        Section("Status") {
            PropertyRow(title: "Actual State") {
                Text(viewModel.qsActualState)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }

            PropertyRow(title: "Current Storage") {
                Text("\(viewModel.qsCurrentStorageMB) MB")
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }

        Section("Data Collection") {
            PropertyRow(title: "Capture Mode", info: "Controls which queries are captured. ALL captures every query. AUTO ignores infrequent queries with insignificant resource usage. CUSTOM lets you define capture thresholds. NONE stops capturing new queries.") {
                Picker("", selection: $viewModel.qsCaptureMode) {
                    ForEach(QueryStoreCaptureMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            PropertyRow(title: "Wait Stats Capture", info: "When enabled, Query Store captures wait statistics per query, which helps identify performance bottlenecks.") {
                Toggle("", isOn: qsWaitStatsBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }

        if viewModel.qsCaptureMode == "CUSTOM" {
            mssqlQueryStoreCapturePolicySection()
        }

        Section("Storage") {
            PropertyRow(title: "Max Storage Size", subtitle: "MB", info: "Maximum disk space Query Store can use. When reached, the store switches to read-only mode automatically.") {
                TextField("", value: $viewModel.qsMaxStorageMB, format: .number, prompt: Text("100"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }

            PropertyRow(title: "Size-Based Cleanup", info: "When enabled, Query Store automatically removes oldest data when storage approaches the maximum size.") {
                Toggle("", isOn: qsCleanupBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }

        Section("Intervals") {
            PropertyRow(title: "Flush Interval", subtitle: "seconds", info: "How often Query Store data is flushed from memory to disk. Lower values reduce data loss risk on crash but increase I/O.") {
                TextField("", value: $viewModel.qsFlushIntervalSeconds, format: .number, prompt: Text("900"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }

            PropertyRow(title: "Statistics Interval", subtitle: "minutes", info: "Time window for aggregating runtime statistics. Shorter intervals give finer granularity but use more storage.") {
                TextField("", value: $viewModel.qsIntervalLengthMinutes, format: .number, prompt: Text("60"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }

            PropertyRow(title: "Stale Query Threshold", subtitle: "days", info: "Queries with no execution data newer than this threshold are eligible for cleanup when size-based cleanup runs.") {
                TextField("", value: $viewModel.qsStaleThresholdDays, format: .number, prompt: Text("30"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }

            PropertyRow(title: "Max Plans Per Query", subtitle: "plans", info: "Maximum number of execution plans retained per query. When reached, the oldest plan is removed.") {
                TextField("", value: $viewModel.qsMaxPlansPerQuery, format: .number, prompt: Text("200"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    // MARK: - Bindings

    private var qsWaitStatsBinding: Binding<Bool> {
        Binding(
            get: { viewModel.qsWaitStatsMode == "ON" },
            set: { viewModel.qsWaitStatsMode = $0 ? "ON" : "OFF" }
        )
    }

    private var qsCleanupBinding: Binding<Bool> {
        Binding(
            get: { viewModel.qsCleanupMode == "AUTO" },
            set: { viewModel.qsCleanupMode = $0 ? "AUTO" : "OFF" }
        )
    }
}
