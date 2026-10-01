import SQLServerKit
import SwiftUI

extension PolicyManagementView {
    var policiesTable: some View {
        Table(viewModel.policies, selection: $viewModel.selectedPolicyID) {
            TableColumn("Name") { policy in
                Text(policy.name).font(TypographyTokens.Table.name)
            }
            TableColumn("Condition") { policy in
                Text(policy.conditionName).font(TypographyTokens.Table.secondaryName)
            }
            TableColumn("Enabled") { policy in
                Text(policy.isEnabled ? "Yes" : "No")
                    .font(TypographyTokens.Table.status)
                    .foregroundStyle(policy.isEnabled ? ColorTokens.Status.success : ColorTokens.Text.secondary)
            }
            .width(60)
            TableColumn("Mode") { policy in
                Text(executionModeLabel(policy.executionMode)).font(TypographyTokens.Table.category)
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
        .contextMenu(forSelectionType: Int32.self) { selection in
            if let policyID = selection.first,
               let policy = viewModel.policies.first(where: { $0.policyId == policyID }) {
                Button {
                    Task { await viewModel.togglePolicy(name: policy.name, currentlyEnabled: policy.isEnabled) }
                } label: {
                    Label(
                        policy.isEnabled ? "Disable" : "Enable",
                        systemImage: policy.isEnabled ? "xmark.circle" : "checkmark.circle"
                    )
                }

                Button {
                    Task { await viewModel.evaluatePolicy(name: policy.name) }
                } label: {
                    Label("Evaluate Now", systemImage: "play.circle")
                }
            }
        } primaryAction: { _ in }
    }

    var conditionsTable: some View {
        Table(viewModel.conditions) {
            TableColumn("Name") { condition in
                Text(condition.name).font(TypographyTokens.Table.name)
            }
            TableColumn("Facet") { condition in
                Text(condition.facetName).font(TypographyTokens.Table.category)
            }
            TableColumn("Expression") { condition in
                Text(condition.expression ?? "—")
                    .font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle(condition.expression == nil ? ColorTokens.Text.tertiary : ColorTokens.Text.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
    }

    var facetsTable: some View {
        Table(viewModel.facets) {
            TableColumn("Name") { facet in
                Text(facet.name).font(TypographyTokens.Table.name)
            }
            TableColumn("Description") { facet in
                Text(facet.description ?? "—")
                    .font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle(facet.description == nil ? ColorTokens.Text.tertiary : ColorTokens.Text.secondary)
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
    }

    var historyTable: some View {
        Table(viewModel.history) {
            TableColumn("Date") { entry in
                Text(entry.startDate, style: .date).font(TypographyTokens.Table.date)
            }
            .width(100)
            TableColumn("Time") { entry in
                Text(entry.startDate, style: .time).font(TypographyTokens.Table.date)
            }
            .width(100)
            TableColumn("Result") { entry in
                Label(
                    entry.result ? "Success" : "Failed",
                    systemImage: entry.result ? "checkmark.circle.fill" : "xmark.circle.fill"
                )
                .font(TypographyTokens.Table.status)
                .foregroundStyle(entry.result ? ColorTokens.Status.success : ColorTokens.Status.error)
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
    }

    private func executionModeLabel(_ mode: Int32) -> String {
        switch mode {
        case 0: "On Demand"
        case 1: "On Change: Prevent"
        case 2: "On Change: Log"
        case 3: "On Schedule"
        default: "Unknown (\(mode))"
        }
    }
}
