import SwiftUI

/// SQL Server's findings, worst first, each with its fix (round 37.4, HE0).
extension MSSQLMaintenanceHealthView {
    private var findings: [HealthFinding] {
        MaintenanceHealthFindings.sqlServer(
            status: viewModel.healthStats?.status,
            recoveryModel: viewModel.healthStats?.recoveryModel,
            backups: viewModel.backupHistory.map { .init(type: $0.type, finished: $0.finishDate) },
            fragmented: viewModel.fragmentedIndexes.map {
                .init(index: $0.indexName, table: "\($0.schemaName).\($0.tableName)", percent: $0.fragmentationPercent, pages: $0.pageCount)
            },
            backupsKnown: viewModel.hasLoadedBackups
        )
    }

    @ViewBuilder
    var findingsSection: some View {
        if viewModel.healthPermissionError == nil, viewModel.healthStats != nil {
            Section("Findings") {
                ForEach(findings) { finding in
                    HealthFindingRow(finding: finding, isFixing: finding.fix != nil && fixing == finding.fix) { fix in
                        run(fix)
                    }
                }
            }
        }
    }

    private func run(_ fix: HealthFinding.Fix) {
        switch fix {
        case .backUpNow:
            // The Backups page opens its backup sheet when it appears with this form set.
            viewModel.backupsActiveForm = .backup
            viewModel.selectedSection = .backups
        case .rebuildIndexes:
            fixing = .rebuildIndexes
            Task {
                for index in MaintenanceHealthFindings.fragmentedToRebuild(viewModel.fragmentedIndexes) {
                    await viewModel.rebuildIndex(index)
                }
                await viewModel.refreshIndexes()
                fixing = nil
            }
        case .vacuumTables:
            break
        }
    }
}
