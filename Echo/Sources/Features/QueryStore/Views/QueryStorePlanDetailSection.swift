import SwiftUI
import SQLServerKit

struct QueryStorePlanDetailSection: View {
    @Bindable var viewModel: QueryStoreViewModel

    var body: some View {
        SectionContainer(
            title: "Execution Plans for Query \(viewModel.selectedQueryId ?? 0)",
            icon: "list.bullet.rectangle",
            info: "All execution plans recorded for this query. Force a plan to lock the optimizer to a known-good plan."
        ) {
            switch viewModel.plansLoadingState {
            case .loading:
                plansLoadingView
            case .error(let message):
                plansErrorView(message)
            default:
                if viewModel.queryPlans.isEmpty {
                    plansEmptyView
                } else {
                    plansContent
                }
            }
        }
    }

    private var plansLoadingView: some View {
        HStack(spacing: SpacingTokens.sm) {
            ProgressView()
                .controlSize(.small)
            Text("Loading plans...")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
    }

    private func plansErrorView(_ message: String) -> some View {
        Text(message)
            .font(TypographyTokens.detail)
            .foregroundStyle(ColorTokens.Status.error)
            .frame(maxWidth: .infinity, minHeight: 80)
    }

    private var plansEmptyView: some View {
        Text("No plans found for this query")
            .font(TypographyTokens.detail)
            .foregroundStyle(ColorTokens.Text.secondary)
            .frame(maxWidth: .infinity, minHeight: 80)
    }

    private var plansContent: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            ForEach(viewModel.queryPlans) { plan in
                PlanCard(plan: plan, viewModel: viewModel)
            }
        }
        .padding(SpacingTokens.sm)
    }
}

// MARK: - Plan Card

private struct PlanCard: View {
    let plan: SQLServerQueryStorePlan
    @Bindable var viewModel: QueryStoreViewModel

    var body: some View {
        HStack(spacing: SpacingTokens.md) {
            planIdentifier
            Divider().frame(height: 32)
            metricsRow
            Spacer()
            forceButton
        }
        .padding(SpacingTokens.sm)
        .background(plan.isForcedPlan
            ? ColorTokens.accent.opacity(0.06)
            : ColorTokens.Text.primary.opacity(0.02))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    plan.isForcedPlan
                        ? ColorTokens.accent.opacity(0.3)
                        : ColorTokens.Text.primary.opacity(0.06),
                    lineWidth: 1
                )
        )
    }

    private var planIdentifier: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
            HStack(spacing: SpacingTokens.xs) {
                Text("Plan \(plan.planId)")
                    .font(TypographyTokens.standard.weight(.semibold))
                    .foregroundStyle(ColorTokens.Text.primary)
                if plan.isForcedPlan {
                    Text("FORCED")
                        .font(TypographyTokens.compact.weight(.bold))
                        .foregroundStyle(ColorTokens.accent)
                        .padding(.horizontal, SpacingTokens.xxxs)
                        .padding(.vertical, 1)
                        .background(ColorTokens.accent.opacity(0.12))
                        .cornerRadius(3)
                }
            }
            if let lastExec = plan.lastExecutionTime {
                Text("Last: \(lastExec, style: .relative) ago")
                    .font(TypographyTokens.compact)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
        }
        .frame(minWidth: 120, alignment: .leading)
    }

    private var metricsRow: some View {
        HStack(spacing: SpacingTokens.lg) {
            metricItem(label: "Avg Duration", value: formatDuration(plan.avgDurationUs))
            metricItem(label: "Avg CPU", value: formatDuration(plan.avgCPUUs))
            metricItem(label: "Avg I/O", value: formatCount(Int(plan.avgIOReads)))
            metricItem(label: "Executions", value: formatCount(plan.executionCount))
        }
    }

    private func metricItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(TypographyTokens.compact)
                .foregroundStyle(ColorTokens.Text.tertiary)
            Text(value)
                .font(TypographyTokens.monospaced)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
    }

    private var forceButton: some View {
        Group {
            if viewModel.forcingPlanId == plan.planId {
                ProgressView()
                    .controlSize(.small)
            } else if plan.isForcedPlan {
                Button("Unforce") {
                    Task {
                        await viewModel.unforcePlan(
                            queryId: plan.queryId, planId: plan.planId
                        )
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Button("Force Plan") {
                    Task {
                        await viewModel.forcePlan(
                            queryId: plan.queryId, planId: plan.planId
                        )
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private func formatDuration(_ microseconds: Double) -> String {
        if microseconds >= 1_000_000 {
            return String(format: "%.2fs", microseconds / 1_000_000)
        } else if microseconds >= 1_000 {
            return String(format: "%.1fms", microseconds / 1_000)
        } else {
            return String(format: "%.0fus", microseconds)
        }
    }

    private func formatCount(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        } else {
            return "\(value)"
        }
    }
}
