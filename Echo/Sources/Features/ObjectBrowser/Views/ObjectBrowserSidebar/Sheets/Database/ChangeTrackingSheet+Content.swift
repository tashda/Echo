import SwiftUI
import SQLServerKit

extension ChangeTrackingSheet {

    @ViewBuilder
    var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.lg) {
                changeTrackingStatusSection
                ctTablesSection
                cdcTablesSection
            }
            .padding(SpacingTokens.md)
        }
    }

    @ViewBuilder
    var changeTrackingStatusSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack {
                Text("Change Tracking")
                    .font(TypographyTokens.standard.weight(.semibold))
                Spacer()

                let isEnabled = ctStatus.contains(where: { $0.databaseName == databaseName })
                if isEnabled {
                    Button("Disable CT") {
                        Task { await disableCT() }
                    }
                    .controlSize(.small)
                    .disabled(!canManageState)
                } else {
                    Button("Enable CT") {
                        Task { await enableCT() }
                    }
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canManageState)
                }
            }

            if ctStatus.isEmpty {
                Text("Change Tracking is not enabled on this database.")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            } else {
                ForEach(ctStatus, id: \.databaseName) { ct in
                    HStack(spacing: SpacingTokens.sm) {
                        Text(ct.databaseName)
                            .font(TypographyTokens.standard)
                        Spacer()
                        Text("Retention: \(ct.retentionPeriod) \(ct.retentionPeriodUnits.lowercased())")
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.secondary)
                        if ct.isAutoCleanupOn {
                            Text("Auto-cleanup")
                                .font(TypographyTokens.compact)
                                .foregroundStyle(ColorTokens.Status.success)
                        }
                    }
                    .padding(SpacingTokens.xs)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(ColorTokens.Background.secondary)
                    )
                }
            }
        }
    }

    @ViewBuilder
    var ctTablesSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text("CT-Tracked Tables")
                .font(TypographyTokens.standard.weight(.semibold))

            if ctTables.isEmpty {
                Text("No tables have Change Tracking enabled.")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            } else {
                ForEach(ctTables) { table in
                    HStack(spacing: SpacingTokens.sm) {
                        Image(systemName: "tablecells")
                            .foregroundStyle(ColorTokens.Text.tertiary)
                        Text("[\(table.schemaName)].[\(table.tableName)]")
                            .font(TypographyTokens.standard)
                        if table.isTrackColumnsUpdatedOn {
                            Text("Columns tracked")
                                .font(TypographyTokens.detail)
                                .foregroundStyle(ColorTokens.Text.tertiary)
                        }
                        Spacer()
                        Button("Disable") {
                            Task { await disableCTTable(schema: table.schemaName, table: table.tableName) }
                        }
                        .controlSize(.small)
                        .disabled(!canManageState)
                    }
                    .padding(SpacingTokens.xs)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(ColorTokens.Background.secondary)
                    )
                }
            }
        }
    }

    @ViewBuilder
    var cdcTablesSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text("CDC-Enabled Tables")
                .font(TypographyTokens.standard.weight(.semibold))

            if cdcTables.isEmpty {
                Text("No tables have Change Data Capture enabled.")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            } else {
                ForEach(cdcTables) { table in
                    HStack(spacing: SpacingTokens.sm) {
                        Image(systemName: "tablecells")
                            .foregroundStyle(ColorTokens.Text.tertiary)
                        Text("[\(table.schemaName)].[\(table.tableName)]")
                            .font(TypographyTokens.standard)
                        if let instance = table.captureInstance {
                            Text(instance)
                                .font(TypographyTokens.detail)
                                .foregroundStyle(ColorTokens.Text.tertiary)
                        }
                        Spacer()
                        Button("Disable") {
                            confirmDisableCDC = CDCDisableTarget(
                                schema: table.schemaName,
                                table: table.tableName,
                                captureInstance: table.captureInstance
                            )
                        }
                        .controlSize(.small)
                        .disabled(!(session.permissions?.canManageServerState ?? true))
                    }
                    .padding(SpacingTokens.xs)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(ColorTokens.Background.secondary)
                    )
                }
            }
        }
    }
}
