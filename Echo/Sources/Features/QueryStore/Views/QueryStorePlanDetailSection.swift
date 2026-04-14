import SwiftUI
import SQLServerKit

struct QueryStorePlanDetailSection: View {
    @Bindable var viewModel: QueryStoreViewModel

    var body: some View {
        VStack(spacing: 0) {
            sectionHeader
            Divider()
            planContent
        }
        .background(ColorTokens.Background.primary)
    }

    private var sectionHeader: some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: "list.bullet.rectangle")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.tertiary)
            Text("Execution Plans")
                .font(TypographyTokens.detail.weight(.medium))
                .foregroundStyle(ColorTokens.Text.secondary)
            if let queryId = viewModel.selectedQueryId {
                Text("\u{2014} Query \(queryId)")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
            Spacer()
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
    }

    @ViewBuilder
    private var planContent: some View {
        switch viewModel.plansLoadingState {
        case .loading:
            HStack(spacing: SpacingTokens.sm) {
                ProgressView().controlSize(.small)
                Text("Loading plans\u{2026}")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error(let message):
            ContentUnavailableView {
                Label("Failed to load plans", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            }
        default:
            if viewModel.queryPlans.isEmpty {
                ContentUnavailableView {
                    Label("No plans found", systemImage: "doc.text.magnifyingglass")
                } description: {
                    Text("No execution plans recorded for this query.")
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                        ForEach(viewModel.queryPlans) { plan in
                            PlanDisclosureRow(plan: plan, viewModel: viewModel)
                        }
                    }
                    .padding(SpacingTokens.sm)
                }
            }
        }
    }
}

// MARK: - Plan Disclosure Row

private struct PlanDisclosureRow: View {
    let plan: SQLServerQueryStorePlan
    @Bindable var viewModel: QueryStoreViewModel
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            planHeader
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }

            if isExpanded, let xml = plan.planXml, !xml.isEmpty {
                Divider()
                    .padding(.leading, SpacingTokens.lg)
                planXMLView(xml)
            }
        }
        .background(plan.isForcedPlan
            ? ColorTokens.accent.opacity(0.04)
            : ColorTokens.Background.secondary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    plan.isForcedPlan
                        ? ColorTokens.accent.opacity(0.15)
                        : ColorTokens.Text.primary.opacity(0.04),
                    lineWidth: 0.5
                )
        )
    }

    private var planHeader: some View {
        HStack(spacing: SpacingTokens.sm) {
            // Disclosure chevron
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(TypographyTokens.compact.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.tertiary)
                .frame(width: 12)

            // Plan identity
            Text("Plan \(plan.planId)")
                .font(TypographyTokens.standard.weight(.medium))
                .foregroundStyle(ColorTokens.Text.primary)

            if plan.isForcedPlan {
                Text("Forced")
                    .font(TypographyTokens.compact)
                    .foregroundStyle(ColorTokens.accent)
                    .padding(.horizontal, SpacingTokens.xxs)
                    .padding(.vertical, 1)
                    .background(ColorTokens.accent.opacity(0.1))
                    .clipShape(Capsule())
            }

            Divider().frame(height: 20)

            // Metrics
            metricLabel("Duration", formatDuration(plan.avgDurationUs))
            metricLabel("CPU", formatDuration(plan.avgCPUUs))
            metricLabel("I/O", formatCount(Int(plan.avgIOReads)))
            metricLabel("Runs", formatCount(plan.executionCount))

            if let lastExec = plan.lastExecutionTime {
                metricLabel("Last", lastExec, style: .relative)
            }

            Spacer()

            // Force/unforce
            forceControl
        }
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.vertical, SpacingTokens.xs)
    }

    private func metricLabel(_ label: String, _ value: String) -> some View {
        HStack(spacing: SpacingTokens.xxxs) {
            Text(label)
                .font(TypographyTokens.compact)
                .foregroundStyle(ColorTokens.Text.quaternary)
            Text(value)
                .font(TypographyTokens.detail.monospacedDigit())
                .foregroundStyle(ColorTokens.Text.secondary)
        }
    }

    private func metricLabel(_ label: String, _ date: Date, style: Text.DateStyle) -> some View {
        HStack(spacing: SpacingTokens.xxxs) {
            Text(label)
                .font(TypographyTokens.compact)
                .foregroundStyle(ColorTokens.Text.quaternary)
            Text(date, style: style)
                .font(TypographyTokens.compact)
                .foregroundStyle(ColorTokens.Text.tertiary)
        }
    }

    @ViewBuilder
    private var forceControl: some View {
        if viewModel.forcingPlanId == plan.planId {
            ProgressView().controlSize(.small)
        } else if plan.isForcedPlan {
            Button("Unforce", role: .destructive) {
                Task { await viewModel.unforcePlan(queryId: plan.queryId, planId: plan.planId) }
            }
            .controlSize(.small)
        } else {
            Button("Force Plan") {
                Task { await viewModel.forcePlan(queryId: plan.queryId, planId: plan.planId) }
            }
            .controlSize(.small)
        }
    }

    private func planXMLView(_ xml: String) -> some View {
        ScrollView(.vertical) {
            Text(formatXML(xml))
                .font(TypographyTokens.Table.sql)
                .foregroundStyle(ColorTokens.Text.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SpacingTokens.sm)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(ColorTokens.Background.tertiary.opacity(0.4))
    }

    private func formatXML(_ xml: String) -> String {
        var result = ""
        var indent = 0
        var i = xml.startIndex

        while i < xml.endIndex {
            if xml[i] == "<" {
                let tagEnd = xml[i...].firstIndex(of: ">") ?? xml.endIndex
                let tag = String(xml[i...tagEnd])

                if tag.hasPrefix("</") {
                    indent = max(0, indent - 1)
                    result += String(repeating: "  ", count: indent) + tag + "\n"
                } else if tag.hasSuffix("/>") {
                    result += String(repeating: "  ", count: indent) + tag + "\n"
                } else {
                    result += String(repeating: "  ", count: indent) + tag + "\n"
                    indent += 1
                }
                i = xml.index(after: tagEnd)
            } else {
                let nextTag = xml[i...].firstIndex(of: "<") ?? xml.endIndex
                let text = xml[i..<nextTag].trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    result += String(repeating: "  ", count: indent) + text + "\n"
                }
                i = nextTag
            }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func formatDuration(_ microseconds: Double) -> String {
        if microseconds >= 1_000_000 {
            return String(format: "%.2fs", microseconds / 1_000_000)
        } else if microseconds >= 1_000 {
            return String(format: "%.1fms", microseconds / 1_000)
        } else {
            return String(format: "%.0f\u{00B5}s", microseconds)
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
