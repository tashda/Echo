import SwiftUI
import PostgresKit

struct PostgresPoliciesSection: View {
    @Bindable var viewModel: PostgresDatabaseSecurityViewModel
    var onNewPolicy: () -> Void = {}
    @Environment(EnvironmentState.self) private var environmentState

    @State private var pendingDropPolicy: (name: String, table: String, schema: String)?

    var body: some View {
        VStack(spacing: 0) {
            schemaFilter
            Divider()
            policyTable
        }
        .dropConfirmationAlert(
            objectType: "Policy",
            objectName: Binding(
                get: { pendingDropPolicy?.name },
                set: { if $0 == nil { pendingDropPolicy = nil } }
            )
        ) { _ in
            if let drop = pendingDropPolicy {
                Task { await viewModel.dropPolicy(drop.name, table: drop.table, schema: drop.schema) }
            }
        }
    }

    private var schemaFilter: some View {
        HStack(spacing: SpacingTokens.sm) {
            Text("Schema:")
                .font(TypographyTokens.caption)
                .foregroundStyle(ColorTokens.Text.secondary)
            Picker("", selection: $viewModel.policySchemaFilter) {
                ForEach(viewModel.availableSchemas, id: \.self) { schema in
                    Text(schema).tag(schema)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: 200)
            .onChange(of: viewModel.policySchemaFilter) { _, _ in
                Task { await viewModel.loadCurrentSection() }
            }
            Spacer()
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
    }

    private var policyTable: some View {
        Table(viewModel.policies, selection: $viewModel.selectedPolicyID) {
            TableColumn("Policy") { policy in
                Text(policy.name)
                    .font(TypographyTokens.Table.name)
            }
            .width(min: 100, ideal: 160)

            TableColumn("Table") { policy in
                Text(policy.tableName)
                    .font(TypographyTokens.Table.secondaryName)
            }
            .width(min: 80, ideal: 120)

            TableColumn("Command") { policy in
                Text(policy.command)
                    .font(TypographyTokens.Table.category)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(70)

            TableColumn("Type") { policy in
                Text(policy.type)
                    .font(TypographyTokens.Table.category)
                    .foregroundStyle(policy.type == "PERMISSIVE" ? ColorTokens.Status.success : ColorTokens.Status.warning)
            }
            .width(90)

            TableColumn("Roles") { policy in
                Text(policy.roles.isEmpty ? "PUBLIC" : policy.roles.joined(separator: ", "))
                    .font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(min: 80, ideal: 140)

            TableColumn("USING") { policy in
                if let expr = policy.usingExpression, !expr.isEmpty {
                    Text(expr)
                        .font(TypographyTokens.Table.sql)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .lineLimit(1)
                } else {
                    Text("\u{2014}")
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            .width(min: 100, ideal: 200)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
        .contextMenu(forSelectionType: String.self) { selection in
            if let id = selection.first, let policy = viewModel.policies.first(where: { $0.id == id }) {
                Menu("Script as", systemImage: "scroll") {
                    Button {
                        let sql = ScriptingActions.scriptCreate(
                            objectType: "POLICY",
                            qualifiedName: "\(ScriptingActions.pgQuote(policy.name)) ON \(ScriptingActions.pgQuote(policy.schemaName)).\(ScriptingActions.pgQuote(policy.tableName))"
                        )
                        environmentState.openScriptTab(sql: sql, connectionID: viewModel.connectionID)
                    } label: { Label("CREATE", systemImage: "plus.square") }

                    Button {
                        let sql = "DROP POLICY IF EXISTS \(ScriptingActions.pgQuote(policy.name)) ON \(ScriptingActions.pgQuote(policy.schemaName)).\(ScriptingActions.pgQuote(policy.tableName));"
                        environmentState.openScriptTab(sql: sql, connectionID: viewModel.connectionID)
                    } label: { Label("DROP", systemImage: "minus.square") }
                }

                Divider()

                Button(role: .destructive) {
                    pendingDropPolicy = (name: policy.name, table: policy.tableName, schema: policy.schemaName)
                } label: {
                    Label("Drop Policy", systemImage: "trash")
                }
            } else {
                Button { onNewPolicy() } label: {
                    Label("New Policy", systemImage: "shield.lefthalf.filled")
                }

                Divider()

                Button {
                    Task { await viewModel.loadCurrentSection() }
                } label: { Label("Refresh", systemImage: "arrow.clockwise") }
            }
        } primaryAction: { _ in }
    }
}

extension PostgresPolicyInfo: @retroactive Identifiable {
    public var id: String { "\(schemaName).\(tableName).\(name)" }
}
