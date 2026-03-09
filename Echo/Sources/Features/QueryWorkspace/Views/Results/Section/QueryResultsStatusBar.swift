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
                        // Left: connection path
                        Text(connectionChipText)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Spacer(minLength: SpacingTokens.sm)

                        // Right: metrics (only after execution)
                        if query.hasExecutedAtLeastOnce || query.isExecuting || query.errorMessage != nil {
                            HStack(spacing: SpacingTokens.sm) {
                                // Row count
                                HStack(spacing: 3) {
                                    AnimatedCounter(
                                        targetValue: query.rowProgress.displayCount,
                                        isActive: query.isExecuting,
                                        formatter: { formatCompact($0) }
                                    )
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    Text(query.rowProgress.displayCount == 1 ? "row" : "rows")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.tertiary)
                                }

                                // Execution time
                                let elapsed = query.isExecuting ? query.currentExecutionTime : (query.lastExecutionTime ?? 0)
                                let hasDuration = query.isExecuting || query.lastExecutionTime != nil
                                if hasDuration {
                                    Text(formattedDuration(Int(elapsed.rounded())))
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }

                                // Status
                                let config = statusBubbleConfiguration()
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(config.tint)
                                        .frame(width: 6, height: 6)
                                    Text(config.label)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, SpacingTokens.sm)
                    .frame(height: statusBarHeight)
                }
                .background(.bar)
            }
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }
}
#endif
