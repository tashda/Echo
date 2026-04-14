import SwiftUI
import SQLServerKit

struct PolicyManagementView: View {
    @Bindable var viewModel: PolicyManagementViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            toolbar
            
            Picker("", selection: $viewModel.selectedTab) {
                ForEach(PolicyManagementViewModel.PolicyTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(SpacingTokens.sm)
            .background(ColorTokens.Background.secondary)
            
            content
        }
        .background(ColorTokens.Background.primary)
        .onAppear {
            viewModel.refresh()
        }
    }
    
    private var toolbar: some View {
        HStack {
            Button {
                viewModel.refresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.isRefreshing)
            
            if viewModel.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }
            
            Spacer()
        }
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Background.secondary)
    }
    
    @ViewBuilder
    private var content: some View {
        switch viewModel.selectedTab {
        case .policies:
            policiesTable
        case .conditions:
            conditionsTable
        case .facets:
            facetsTable
        case .history:
            historyTable
        }
    }
    
    private var policiesTable: some View {
        Table(viewModel.policies, selection: $viewModel.selectedPolicyID) {
            TableColumn("Name", value: \.name)
            TableColumn("Condition", value: \.conditionName)
            TableColumn("Enabled") { p in
                Text(p.isEnabled ? "Yes" : "No")
                    .foregroundStyle(p.isEnabled ? .green : .secondary)
            }
            .width(60)
            TableColumn("Mode") { p in
                Text(executionModeLabel(p.executionMode))
            }
        }
        .contextMenu(forSelectionType: Int32.self) { selection in
            if let policyId = selection.first,
               let policy = viewModel.policies.first(where: { $0.policyId == policyId }) {
                Button {
                    Task { await viewModel.togglePolicy(name: policy.name, currentlyEnabled: policy.isEnabled) }
                } label: {
                    Label(policy.isEnabled ? "Disable" : "Enable", systemImage: policy.isEnabled ? "xmark.circle" : "checkmark.circle")
                }

                Button {
                    Task { await viewModel.evaluatePolicy(name: policy.name) }
                } label: {
                    Label("Evaluate Now", systemImage: "play.circle")
                }
            } else {
                Button {
                    viewModel.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        } primaryAction: { _ in }
    }
    
    private var conditionsTable: some View {
        Table(viewModel.conditions) {
            TableColumn("Name", value: \.name)
            TableColumn("Facet", value: \.facetName)
            TableColumn("Expression") { c in
                Text(c.expression ?? "-")
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }
    
    private var facetsTable: some View {
        Table(viewModel.facets) {
            TableColumn("Name", value: \.name)
            TableColumn("Description") { f in
                Text(f.description ?? "-")
            }
        }
    }
    
    private var historyTable: some View {
        Table(viewModel.history) {
            TableColumn("Date") { h in
                Text(h.startDate, style: .date)
            }
            .width(100)
            TableColumn("Time") { h in
                Text(h.startDate, style: .time)
            }
            .width(100)
            TableColumn("Result") { h in
                Label(h.result ? "Success" : "Failed", systemImage: h.result ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(h.result ? .green : .red)
            }
        }
    }
    
    private func executionModeLabel(_ mode: Int32) -> String {
        switch mode {
        case 0: return "On Demand"
        case 1: return "On Change: Prevent"
        case 2: return "On Change: Log"
        case 3: return "On Schedule"
        default: return "Unknown (\(mode))"
        }
    }
}
