import SwiftUI
import SQLServerKit

extension ChangeTrackingSheet {

    @ViewBuilder
    var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.lg) {
                changeTrackingStatusSection
                cdcTablesSection
            }
            .padding(SpacingTokens.md)
        }
    }

    @ViewBuilder
    var changeTrackingStatusSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text("Change Tracking")
                .font(TypographyTokens.standard.weight(.semibold))

            if ctStatus.isEmpty {
                Text("Change Tracking is not enabled on any database.")
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
