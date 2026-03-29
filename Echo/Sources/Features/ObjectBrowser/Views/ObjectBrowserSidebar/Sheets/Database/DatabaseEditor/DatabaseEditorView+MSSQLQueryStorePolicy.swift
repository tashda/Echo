import SwiftUI
import SQLServerKit

// MARK: - MSSQL Query Store Custom Capture Policy

extension DatabaseEditorView {

    @ViewBuilder
    func mssqlQueryStoreCapturePolicySection() -> some View {
        Section("Capture Policy") {
            PropertyRow(title: "Evaluation Interval", subtitle: "hours", info: "Time window during which capture conditions are evaluated. A query meeting any threshold within this interval is captured.") {
                TextField("", value: $viewModel.qsCaptureStalePolicyThresholdHours, format: .number, prompt: Text("24"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }

            PropertyRow(title: "Execution Count", subtitle: "executions", info: "Minimum number of executions within the evaluation interval for a query to be captured.") {
                TextField("", value: $viewModel.qsCaptureExecutionCount, format: .number, prompt: Text("30"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }

            PropertyRow(title: "Total Compile CPU Time", subtitle: "ms", info: "Minimum total compile CPU time within the evaluation interval for a query to be captured.") {
                TextField("", value: $viewModel.qsCaptureCompileCpuTimeMs, format: .number, prompt: Text("1000"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }

            PropertyRow(title: "Total Execution CPU Time", subtitle: "ms", info: "Minimum total execution CPU time within the evaluation interval for a query to be captured.") {
                TextField("", value: $viewModel.qsCaptureExecutionCpuTimeMs, format: .number, prompt: Text("100"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}
