import SwiftUI
import AppKit

struct SchemaDiffDetailView: View {
    @Bindable var viewModel: SchemaDiffViewModel
    @Environment(EnvironmentState.self) private var environmentState

    var body: some View {
        Group {
            if let item = viewModel.selectedDiff {
                detailContent(for: item)
            } else {
                ContentUnavailableView(
                    "Select an Object",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Choose an object from the diff list to inspect its definition.")
                )
            }
        }
    }

    private func detailContent(for item: SchemaDiffItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header(for: item)
            Divider()
            ddlComparison(for: item)
        }
    }

    private func header(for item: SchemaDiffItem) -> some View {
        HStack(spacing: SpacingTokens.sm) {
            Label(item.status.rawValue, systemImage: item.status.icon)
                .font(TypographyTokens.prominent.weight(.medium))
                .foregroundStyle(statusColor(for: item.status))

            Text("\(item.objectType): \(item.objectName)")
                .font(TypographyTokens.body)
                .foregroundStyle(ColorTokens.Text.primary)

            Spacer()

            Button("Copy Migration SQL") {
                let sql = viewModel.generateMigrationSQL(for: item)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(sql, forType: .string)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button("Open in Query Tab") {
                openSelectedMigrationSQL()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.sm)
    }

    private func ddlComparison(for item: SchemaDiffItem) -> some View {
        HSplitView {
            ddlPane(title: "Source (\(viewModel.sourceSchema))", ddl: item.sourceDDL)
            ddlPane(title: "Target (\(viewModel.targetSchema))", ddl: item.targetDDL)
        }
    }

    private func ddlPane(title: String, ddl: String?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(TypographyTokens.caption.weight(.medium))
                .foregroundStyle(ColorTokens.Text.secondary)
                .padding(.horizontal, SpacingTokens.sm)
                .padding(.vertical, SpacingTokens.xs)

            Divider()

            if let ddl, !ddl.isEmpty {
                ScrollView {
                    Text(ddl)
                        .font(TypographyTokens.monospaced)
                        .foregroundStyle(ColorTokens.Text.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(SpacingTokens.sm)
                }
            } else {
                ContentUnavailableView(
                    "No Definition",
                    systemImage: "doc",
                    description: Text("Object does not exist in this schema.")
                )
            }
        }
        .frame(minWidth: 200)
    }

    private func statusColor(for status: SchemaDiffStatus) -> Color {
        switch status {
        case .added: return ColorTokens.Status.success
        case .removed: return ColorTokens.Status.error
        case .modified: return ColorTokens.Status.warning
        case .identical: return ColorTokens.Text.tertiary
        }
    }

    private func openSelectedMigrationSQL() {
        guard let sql = viewModel.migrationSQLForSelectedDiff(),
              let session = environmentState.sessionGroup.activeSessions.first(where: { $0.id == viewModel.connectionSessionID }) else {
            return
        }

        let database = session.connection.databaseType == .mysql ? viewModel.targetSchema : nil
        environmentState.openQueryTab(for: session, presetQuery: sql, database: database)
    }
}
