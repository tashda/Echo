import SwiftUI
import SQLServerKit

struct MSSQLCDCSection: View {
    @Bindable var viewModel: MSSQLAdvancedObjectsViewModel

    @State private var confirmDisableCDC: CDCDisableTarget?

    struct CDCDisableTarget: Identifiable {
        let id = UUID()
        let schema: String
        let table: String
        let captureInstance: String?
    }

    var body: some View {
        if viewModel.cdcTables.isEmpty {
            ContentUnavailableView {
                Label("No CDC Tables", systemImage: "arrow.triangle.branch")
            } description: {
                Text("No tables have Change Data Capture enabled in this database.")
            }
        } else {
            List {
                ForEach(viewModel.cdcTables) { table in
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
                        .disabled(viewModel.isBusy)
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
        alertModifiers
    }

    @ViewBuilder
    private var alertModifiers: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .alert("Disable CDC?", isPresented: disableAlertBinding) {
                Button("Cancel", role: .cancel) { confirmDisableCDC = nil }
                Button("Disable", role: .destructive) {
                    guard let target = confirmDisableCDC else { return }
                    confirmDisableCDC = nil
                    Task { await viewModel.disableCDC(schema: target.schema, table: target.table, captureInstance: target.captureInstance) }
                }
            } message: {
                if let target = confirmDisableCDC {
                    Text("Disable CDC on [\(target.schema)].[\(target.table)]? This removes the change table.")
                }
            }
    }

    private var disableAlertBinding: Binding<Bool> {
        Binding(get: { confirmDisableCDC != nil }, set: { if !$0 { confirmDisableCDC = nil } })
    }
}
