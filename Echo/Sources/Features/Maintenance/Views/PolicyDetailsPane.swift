import SwiftUI
import SQLServerKit

/// The selected policy beside Policy Management's list (round 37.4, MA0): its condition and
/// facet, how it runs and its last evaluation, with Evaluate Now and Enable or Disable on the
/// pane's header.
struct PolicyDetailsPane: View {
    @Bindable var viewModel: PolicyManagementViewModel

    var body: some View {
        VStack(spacing: SpacingTokens.none) {
            PaneHeader("Details") { actions }
            if let policy = viewModel.selectedPolicy {
                Form {
                    Section(policy.name) {
                        PropertyRow(title: "Condition") { secondary(policy.conditionName) }
                        if let condition {
                            PropertyRow(title: "Facet") { secondary(condition.facetName) }
                            if let expression = condition.expression, !expression.isEmpty {
                                PropertyRow(title: "Expression") {
                                    Text(expression).font(TypographyTokens.code).foregroundStyle(ColorTokens.Text.secondary)
                                        .textSelection(.enabled).lineLimit(3)
                                }
                            }
                        }
                    }
                    Section("Evaluation") {
                        PropertyRow(title: "Mode") { secondary(PolicyManagementView.executionModeLabel(policy.executionMode)) }
                        PropertyRow(title: "Schedule") { secondary(policy.scheduleName ?? "None") }
                        PropertyRow(title: "Enabled") {
                            Text(policy.isEnabled ? "Yes" : "No")
                                .foregroundStyle(policy.isEnabled ? ColorTokens.Status.success : ColorTokens.Text.secondary)
                        }
                        PropertyRow(title: "Last Run") { lastRun(policy) }
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
            } else {
                TabContentUnavailableView("No Policy Selected", systemImage: "checklist") {
                    Text("Select a policy to see its condition and how it runs.")
                }
            }
        }
    }

    @ViewBuilder
    private var actions: some View {
        if let policy = viewModel.selectedPolicy {
            Button("Evaluate Now", systemImage: "play.circle") {
                Task { await viewModel.evaluatePolicy(name: policy.name) }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help("Evaluate Now")
            Button(policy.isEnabled ? "Disable" : "Enable", systemImage: policy.isEnabled ? "xmark.circle" : "checkmark.circle") {
                Task { await viewModel.togglePolicy(name: policy.name, currentlyEnabled: policy.isEnabled) }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help(policy.isEnabled ? "Disable" : "Enable")
        }
    }

    private var condition: SQLServerPolicyCondition? {
        guard let policy = viewModel.selectedPolicy else { return nil }
        return viewModel.conditions.first { $0.name == policy.conditionName }
    }

    @ViewBuilder
    private func lastRun(_ policy: SQLServerPolicy) -> some View {
        if let run = viewModel.history.filter({ $0.policyId == policy.policyId }).max(by: { $0.startDate < $1.startDate }) {
            Text("\(run.startDate.formatted(date: .abbreviated, time: .shortened)) · \(run.result ? "Passed" : "Failed")")
                .foregroundStyle(run.result ? ColorTokens.Text.secondary : ColorTokens.Status.error)
        } else {
            secondary("Never")
        }
    }

    private func secondary(_ text: String) -> some View {
        Text(text).foregroundStyle(ColorTokens.Text.secondary)
    }
}
