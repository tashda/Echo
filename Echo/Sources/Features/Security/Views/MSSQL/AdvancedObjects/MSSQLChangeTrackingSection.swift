import SwiftUI
import SQLServerKit

struct MSSQLChangeTrackingSection: View {
    @Bindable var viewModel: MSSQLAdvancedObjectsViewModel

    @State private var confirmDisableCT = false

    private var isEnabled: Bool {
        viewModel.ctStatus.contains(where: { $0.databaseName == viewModel.databaseName })
    }

    private var ctInfo: SQLServerChangeTrackingStatus? {
        viewModel.ctStatus.first(where: { $0.databaseName == viewModel.databaseName })
    }

    var body: some View {
        VStack(spacing: 0) {
            statusBar
            Divider()

            if viewModel.ctTables.isEmpty {
                ContentUnavailableView {
                    Label("No Tracked Tables", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                } description: {
                    Text(isEnabled
                         ? "No tables have Change Tracking enabled."
                         : "Change Tracking is not enabled on this database.")
                } actions: {
                    if !isEnabled {
                        Button("Enable Change Tracking") {
                            Task { await viewModel.enableChangeTracking() }
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isBusy)
                    }
                }
            } else {
                List {
                    ForEach(viewModel.ctTables) { table in
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
                                Task { await viewModel.disableTableChangeTracking(schema: table.schemaName, table: table.tableName) }
                            }
                            .controlSize(.small)
                            .disabled(viewModel.isBusy)
                        }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .alert("Disable Change Tracking?", isPresented: $confirmDisableCT) {
            Button("Cancel", role: .cancel) {}
            Button("Disable", role: .destructive) {
                Task { await viewModel.disableChangeTracking() }
            }
        } message: {
            Text("This will disable Change Tracking on \(viewModel.databaseName). All tracked change data will be lost.")
        }
    }

    private var statusBar: some View {
        HStack(spacing: SpacingTokens.sm) {
            Circle()
                .fill(isEnabled ? ColorTokens.Status.success : ColorTokens.Text.quaternary)
                .frame(width: 8, height: 8)
            Text(isEnabled ? "Enabled" : "Disabled")
                .font(TypographyTokens.standard)
                .foregroundStyle(isEnabled ? ColorTokens.Text.primary : ColorTokens.Text.secondary)

            if let ct = ctInfo {
                Text("\u{2022}")
                    .foregroundStyle(ColorTokens.Text.quaternary)
                Text("Retention: \(ct.retentionPeriod) \(ct.retentionPeriodUnits.lowercased())")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                if ct.isAutoCleanupOn {
                    Text("\u{2022}")
                        .foregroundStyle(ColorTokens.Text.quaternary)
                    Text("Auto-cleanup")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }

            Spacer()

            if isEnabled {
                Button("Disable", role: .destructive) { confirmDisableCT = true }
                    .controlSize(.small)
                    .disabled(viewModel.isBusy)
            } else {
                Button("Enable") {
                    Task { await viewModel.enableChangeTracking() }
                }
                .controlSize(.small)
                .buttonStyle(.bordered)
                .disabled(viewModel.isBusy)
            }
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
    }
}
