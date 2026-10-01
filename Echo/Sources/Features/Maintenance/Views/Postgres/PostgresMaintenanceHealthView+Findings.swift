import SwiftUI

/// PostgreSQL's findings, worst first, each with its fix (round 37.4, HE0).
extension PostgresMaintenanceHealthView {
    func findingsSection(_ health: PostgresMaintenanceHealth) -> some View {
        Section("Findings") {
            ForEach(MaintenanceHealthFindings.postgres(health: health, tables: viewModel.tableStats)) { finding in
                HealthFindingRow(finding: finding, isFixing: finding.fix != nil && fixing == finding.fix) { fix in
                    run(fix)
                }
            }
        }
    }

    private func run(_ fix: HealthFinding.Fix) {
        guard fix == .vacuumTables, let database = viewModel.selectedDatabase else { return }
        let tables = MaintenanceHealthFindings.tablesNeedingVacuum(viewModel.tableStats)
        fixing = .vacuumTables
        Task {
            for table in tables {
                try? await viewModel.vacuumTable(database: database, schema: table.schemaName, table: table.tableName, analyze: true)
            }
            await viewModel.fetchTableStats(for: database)
            await viewModel.fetchHealth(for: database)
            fixing = nil
        }
    }
}
