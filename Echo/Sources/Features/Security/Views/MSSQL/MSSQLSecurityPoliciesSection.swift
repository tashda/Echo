import SwiftUI
import SQLServerKit

struct MSSQLSecurityPoliciesSection: View {
    @Bindable var viewModel: DatabaseSecurityViewModel
    @Environment(EnvironmentState.self) private var environmentState

    @State private var sortOrder = [KeyPathComparator(\SecurityPolicyInfo.name)]
    @State private var showDropAlert = false
    @State private var pendingDropPolicy: SecurityPolicyInfo?

    private var sortedPolicies: [SecurityPolicyInfo] {
        viewModel.securityPolicies.sorted(using: sortOrder)
    }

    var body: some View {
        Table(sortedPolicies, selection: $viewModel.selectedPolicyID, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name) { policy in
                Text(policy.name)
                    .font(TypographyTokens.Table.name)
            }
            .width(min: 100, ideal: 180)

            TableColumn("Schema", value: \.schema) { policy in
                Text(policy.schema)
                    .font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(min: 60, ideal: 100)

            TableColumn("Enabled") { policy in
                Image(systemName: policy.isEnabled ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(policy.isEnabled ? ColorTokens.Status.success : ColorTokens.Text.tertiary)
            }
            .width(min: 50, ideal: 70)

            TableColumn("Schema Bound") { policy in
                Text(policy.isSchemaBound ? "Yes" : "No")
                    .font(TypographyTokens.Table.category)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(min: 60, ideal: 90)

            TableColumn("Created") { policy in
                if let date = policy.createDate {
                    Text(date)
                        .font(TypographyTokens.Table.date)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                } else {
                    Text("\u{2014}")
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            .width(min: 80, ideal: 140)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
        .contextMenu(forSelectionType: String.self) { selection in
            if let id = selection.first,
               let policy = viewModel.securityPolicies.first(where: { $0.id == id }) {
                Button {
                    Task { await viewModel.toggleSecurityPolicy(name: policy.name, schema: policy.schema, enabled: !policy.isEnabled) }
                } label: {
                    Label(policy.isEnabled ? "Disable" : "Enable", systemImage: policy.isEnabled ? "pause.circle" : "play.circle")
                }

                Divider()

                Menu("Script as", systemImage: "scroll") {
                    Button { scriptCreate(policy) } label: {
                        Label("CREATE", systemImage: "plus.square")
                    }
                    Button { scriptDrop(policy) } label: {
                        Label("DROP", systemImage: "minus.square")
                    }
                }

                Divider()

                Button(role: .destructive) {
                    pendingDropPolicy = policy
                    showDropAlert = true
                } label: {
                    Label("Drop Policy", systemImage: "trash")
                }
            } else {
                Button {
                    Task { await viewModel.loadCurrentSection() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        } primaryAction: { _ in }
        .alert("Drop Security Policy?", isPresented: $showDropAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Drop", role: .destructive) {
                if let policy = pendingDropPolicy {
                    Task { await viewModel.dropSecurityPolicy(name: policy.name, schema: policy.schema) }
                }
            }
        } message: {
            Text("Are you sure you want to drop the security policy \(pendingDropPolicy?.id ?? "")? This action cannot be undone.")
        }
    }

    private func scriptCreate(_ policy: SecurityPolicyInfo) {
        let s = escapeID(policy.schema)
        let n = escapeID(policy.name)
        openScriptTab(sql: "CREATE SECURITY POLICY \(s).\(n)\n    ADD FILTER PREDICATE dbo.fn_securitypredicate(column) ON dbo.TargetTable\n    WITH (STATE = \(policy.isEnabled ? "ON" : "OFF"));\nGO")
    }

    private func scriptDrop(_ policy: SecurityPolicyInfo) {
        let s = escapeID(policy.schema)
        let n = escapeID(policy.name)
        openScriptTab(sql: "DROP SECURITY POLICY \(s).\(n);\nGO")
    }

    private func escapeID(_ name: String) -> String {
        "[\(name.replacingOccurrences(of: "]", with: "]]"))]"
    }

    private func openScriptTab(sql: String) {
        if let session = environmentState.sessionGroup.sessionForConnection(viewModel.connectionID) {
            environmentState.openQueryTab(for: session, presetQuery: sql)
        }
    }
}
