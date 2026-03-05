import SwiftUI

#if os(macOS)
extension QueryResultsSection {
    var statusBar: some View {
        let shouldShowStatusBar = self.shouldShowStatusBar
        return Group {
            if shouldShowStatusBar {
                QueryResultsStatusBarContainer(
                    height: statusBarHeight,
                    verticalPadding: statusBarVerticalPadding,
                    contentOffset: statusBarContentYOffset,
                    background: ColorTokens.Background.primary,
                    dividerOpacity: 0.3
                ) {
                    HStack(alignment: .center, spacing: statusBarChipSpacing) {
                        connectionStatusChip
                        Spacer(minLength: 0)
                        HStack(alignment: .center, spacing: statusBarChipSpacing) {
                            modeChip
                            rowCountChip
                            executionTimeChip
                            queryStatusChip
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 18)
                    .padding(.vertical, statusBarVerticalPadding)
                }
                .background(ColorTokens.Background.primary)
                .frame(minHeight: statusBarHeight)
            }
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    var connectionStatusChip: some View {
        Button {
            showConnectionInfoPopover.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "server.rack")
                    .font(TypographyTokens.label.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(connectionChipText)
                    .font(TypographyTokens.detail.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, SpacingTokens.xs)
            .frame(height: statusChipHeight)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showConnectionInfoPopover, arrowEdge: .top) {
            connectionInfoPopover
        }
    }

    var modeChip: some View {
        let isStreaming = query.isExecuting
        return HStack(spacing: 4) {
            Image(systemName: isStreaming ? "dot.radiowaves.left.and.right" : "Memory")
                .font(TypographyTokens.compact.weight(.bold))
            Text(isStreaming ? "STREAM" : "LOCAL")
                .font(TypographyTokens.compact.weight(.bold))
        }
        .foregroundStyle(isStreaming ? .orange : .secondary)
        .padding(.horizontal, SpacingTokens.xxs2)
        .frame(width: modeChipWidth, height: 20)
        .background(isStreaming ? Color.orange.opacity(0.1) : Color.primary.opacity(0.05), in: Capsule())
    }

    var rowCountChip: some View {
        let progress = query.rowProgress
        let isExecuting = query.isExecuting
        return Button {
            if !isExecuting && progress.displayCount > 0 {
                showRowInfoPopover.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isExecuting ? "arrow.triangle.2.circlepath" : "tablecells")
                    .font(TypographyTokens.label.weight(.medium))
                    .foregroundStyle(isExecuting ? .orange : .secondary)

                AnimatedCounter(
                    targetValue: progress.displayCount,
                    isActive: isExecuting,
                    formatter: { formatCompact($0) }
                )
                .font(.system(size: 11, weight: .semibold, design: .monospaced))

                Text("rows")
                    .font(TypographyTokens.label.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, SpacingTokens.xs)
            .frame(width: rowCountChipWidth, height: statusChipHeight)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showRowInfoPopover, arrowEdge: .top) {
            rowInfoPopover
        }
    }

    var executionTimeChip: some View {
        let elapsed = query.isExecuting ? query.currentExecutionTime : (query.lastExecutionTime ?? 0)
        let hasDuration = query.isExecuting || query.lastExecutionTime != nil
        return Button {
            if !query.isExecuting && hasDuration {
                showTimeInfoPopover.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(TypographyTokens.label.weight(.medium))
                    .foregroundStyle(query.isExecuting ? .orange : .secondary)
                Text(hasDuration ? formattedDuration(Int(elapsed.rounded())) : "—")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
            }
            .padding(.horizontal, SpacingTokens.xs)
            .frame(width: timeChipWidth, height: statusChipHeight)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showTimeInfoPopover, arrowEdge: .top) {
            timeInfoPopover
        }
    }

    var queryStatusChip: some View {
        let config = statusBubbleConfiguration()
        return HStack(spacing: 6) {
            Image(systemName: config.icon)
                .font(TypographyTokens.label.weight(.medium))
            Text(config.label)
                .font(TypographyTokens.detail.weight(.semibold))
        }
        .foregroundStyle(config.tint)
        .padding(.horizontal, SpacingTokens.xs)
        .frame(width: statusChipWidth, height: statusChipHeight)
        .background(config.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

struct QueryResultsStatusBarContainer<Content: View>: View {
    let height: CGFloat
    let verticalPadding: CGFloat
    let contentOffset: CGFloat
    let background: Color
    let dividerOpacity: Double
    let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Divider().opacity(dividerOpacity)
            content()
                .frame(height: height)
                .offset(y: contentOffset)
        }
        .background(background)
    }
}
#endif
