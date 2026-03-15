import SwiftUI

#if os(macOS)
extension QueryResultsSection {
    var statusBar: some View {
        let shouldShowStatusBar = self.shouldShowStatusBar
        return Group {
            if shouldShowStatusBar {
                VStack(spacing: 0) {
                    Divider()
                    HStack(spacing: 0) {
                        // Left: connection path + messages toggle
                        Text(connectionChipText)
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .lineLimit(1)

                        if query.hasExecutedAtLeastOnce || query.isExecuting || query.errorMessage != nil {
                            messagesToggleButton
                                .padding(.leading, SpacingTokens.xs)
                            if query.executionPlan != nil || query.isLoadingExecutionPlan {
                                executionPlanToggleButton
                                    .padding(.leading, SpacingTokens.xxs)
                            }
                        }

                        Spacer(minLength: SpacingTokens.sm)

                        // Right: metrics (only after execution)
                        if query.hasExecutedAtLeastOnce || query.isExecuting || query.errorMessage != nil {
                            HStack(spacing: SpacingTokens.sm) {
                                // Row count
                                HStack(spacing: SpacingTokens.xxxs) {
                                    if !query.additionalResults.isEmpty {
                                        multiResultSetRowCount
                                    } else {
                                        singleResultSetRowCount
                                    }
                                }

                                // Execution time
                                let elapsed = query.isExecuting ? query.currentExecutionTime : (query.lastExecutionTime ?? 0)
                                let hasDuration = query.isExecuting || query.lastExecutionTime != nil
                                if hasDuration {
                                    Text(formattedDuration(Int(elapsed.rounded())))
                                        .font(TypographyTokens.detail.monospaced().weight(.medium))
                                        .foregroundStyle(ColorTokens.Text.secondary)
                                }

                                // Status
                                let config = statusBubbleConfiguration()
                                HStack(spacing: SpacingTokens.xxs) {
                                    PulsingStatusDot(tint: config.tint, isPulsing: query.isExecuting)
                                    Text(config.label)
                                        .font(TypographyTokens.detail)
                                        .foregroundStyle(ColorTokens.Text.secondary)
                                }

                            }
                        }
                    }
                    .padding(.leading, SpacingTokens.sm)
                    .padding(.trailing, SpacingTokens.md1)
                    .frame(height: statusBarHeight)
                }
                .background(.bar)
            }
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    @ViewBuilder
    private var singleResultSetRowCount: some View {
        let total = query.rowProgress.totalReported
        let showOfTotal = query.isExecuting && total > 0 && query.rowProgress.totalReceived < total
        AnimatedCounter(
            targetValue: showOfTotal ? query.rowProgress.totalReceived : query.rowProgress.displayCount,
            isActive: query.isExecuting,
            formatter: { formatCompact($0) }
        )
        .font(TypographyTokens.detail.monospaced().weight(.medium))
        .foregroundStyle(ColorTokens.Text.secondary)
        if showOfTotal {
            Text("of \(formatCompact(total)) rows")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.tertiary)
        } else {
            Text(query.rowProgress.displayCount == 1 ? "row" : "rows")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.tertiary)
        }
    }

    @ViewBuilder
    private var multiResultSetRowCount: some View {
        let selectedIndex = query.selectedResultSetIndex
        let selectedRowCount: Int = {
            if selectedIndex == 0 {
                return query.rowProgress.displayCount
            }
            let additionalIndex = selectedIndex - 1
            guard additionalIndex < query.additionalResults.count else { return 0 }
            return query.additionalResults[additionalIndex].totalRowCount ?? query.additionalResults[additionalIndex].rows.count
        }()
        let totalSets = 1 + query.additionalResults.count

        Text(formatCompact(selectedRowCount))
            .font(TypographyTokens.detail.monospaced().weight(.medium))
            .foregroundStyle(ColorTokens.Text.secondary)
        Text(selectedRowCount == 1 ? "row" : "rows")
            .font(TypographyTokens.detail)
            .foregroundStyle(ColorTokens.Text.tertiary)
        Text("·")
            .font(TypographyTokens.detail)
            .foregroundStyle(ColorTokens.Text.quaternary)
        Text("Result \(selectedIndex + 1) of \(totalSets)")
            .font(TypographyTokens.detail)
            .foregroundStyle(ColorTokens.Text.tertiary)
    }

    private var messagesToggleButton: some View {
        let isActive = selectedTab == .messages
        return Button {
            selectedTab = isActive ? .results : .messages
        } label: {
            Image(systemName: "text.bubble")
                .font(TypographyTokens.detail)
                .foregroundStyle(isActive ? ColorTokens.accent : ColorTokens.Text.secondary)
        }
        .buttonStyle(.borderless)
        .help(isActive ? "Show Results" : "Show Messages")
    }

    private var executionPlanToggleButton: some View {
        let isActive = selectedTab == .executionPlan
        return Button {
            selectedTab = isActive ? .results : .executionPlan
        } label: {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(TypographyTokens.detail)
                .foregroundStyle(isActive ? ColorTokens.accent : ColorTokens.Text.secondary)
        }
        .buttonStyle(.borderless)
        .help(isActive ? "Show Results" : "Show Execution Plan")
    }
}

#endif
