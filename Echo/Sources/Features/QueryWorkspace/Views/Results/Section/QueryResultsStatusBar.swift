import SwiftUI

#if os(macOS)
extension QueryResultsSection {
    var statusBar: some View {
        let shouldShowStatusBar = self.shouldShowStatusBar
        return Group {
            if shouldShowStatusBar {
                VStack(spacing: 0) {
                    Divider().opacity(0.5)
                    HStack(spacing: statusBarChipSpacing) {
                        // Left: connection info (plain text)
                        HStack(spacing: 5) {
                            Image(systemName: "server.rack")
                                .font(TypographyTokens.label.weight(.medium))
                                .foregroundStyle(.tertiary)
                            Text(connectionChipText)
                                .font(TypographyTokens.detail.weight(.medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)

                        // Mode indicator
                        if query.isExecuting {
                            HStack(spacing: 3) {
                                Image(systemName: "dot.radiowaves.left.and.right")
                                    .font(TypographyTokens.label.weight(.semibold))
                                    .foregroundStyle(.orange)
                                Text("STREAM")
                                    .font(TypographyTokens.compact.weight(.semibold))
                                    .foregroundStyle(.orange)
                            }
                        } else {
                            HStack(spacing: 3) {
                                Image(systemName: "internaldrive")
                                    .font(TypographyTokens.label.weight(.medium))
                                    .foregroundStyle(.tertiary)
                                Text("LOCAL")
                                    .font(TypographyTokens.compact.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        // Row count
                        HStack(spacing: 4) {
                            Image(systemName: query.isExecuting ? "arrow.triangle.2.circlepath" : "tablecells")
                                .font(TypographyTokens.label.weight(.medium))
                                .foregroundStyle(query.isExecuting ? AnyShapeStyle(.orange) : AnyShapeStyle(.tertiary))
                            AnimatedCounter(
                                targetValue: query.rowProgress.displayCount,
                                isActive: query.isExecuting,
                                formatter: { formatCompact($0) }
                            )
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                            Text("rows")
                                .font(TypographyTokens.label.weight(.medium))
                                .foregroundStyle(.tertiary)
                        }

                        // Execution time
                        HStack(spacing: 4) {
                            let elapsed = query.isExecuting ? query.currentExecutionTime : (query.lastExecutionTime ?? 0)
                            let hasDuration = query.isExecuting || query.lastExecutionTime != nil
                            Image(systemName: "clock")
                                .font(TypographyTokens.label.weight(.medium))
                                .foregroundStyle(query.isExecuting ? AnyShapeStyle(.orange) : AnyShapeStyle(.tertiary))
                            Text(hasDuration ? formattedDuration(Int(elapsed.rounded())) : "\u{2014}")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }

                        // Status indicator: dot + text
                        HStack(spacing: 5) {
                            let config = statusBubbleConfiguration()
                            Circle()
                                .fill(config.tint)
                                .frame(width: 6, height: 6)
                            Text(config.label)
                                .font(TypographyTokens.detail.weight(.medium))
                                .foregroundStyle(config.tint)
                        }
                    }
                    .padding(.horizontal, SpacingTokens.sm)
                    .frame(height: statusBarHeight)
                }
                .background(ColorTokens.Background.primary)
            }
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }
}
#endif
