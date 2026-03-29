import SwiftUI

extension TablePropertiesView {

    // MARK: - Change Tracking (MSSQL)

    @ViewBuilder
    var changeTrackingPage: some View {
        Section("Change Tracking") {
            PropertyRow(title: "Change Tracking Enabled") {
                flagIcon(viewModel.mssqlChangeTrackingEnabled)
            }
            PropertyRow(title: "Track Columns Updated") {
                flagIcon(viewModel.mssqlTrackColumnsUpdated)
            }
        }
    }

    // MARK: - Temporal (MSSQL)

    @ViewBuilder
    var temporalPage: some View {
        Section("System Versioning") {
            PropertyRow(title: "System-Versioned") {
                flagIcon(viewModel.mssqlIsSystemVersioned)
            }
        }

        if viewModel.mssqlIsSystemVersioned {
            Section("History Table") {
                if let schema = viewModel.mssqlHistoryTableSchema {
                    PropertyRow(title: "Schema") {
                        Text(schema)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                }
                if let table = viewModel.mssqlHistoryTableName {
                    PropertyRow(title: "Table") {
                        Text(table)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                }
            }

            Section("Period Columns") {
                if let start = viewModel.mssqlPeriodStartColumn {
                    PropertyRow(title: "Start Column") {
                        Text(start)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                }
                if let end = viewModel.mssqlPeriodEndColumn {
                    PropertyRow(title: "End Column") {
                        Text(end)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                }
            }
        }
    }
}
