import SwiftUI

/// How the footer's right-hand side is drawn: quiet text on the blur, all of it in one glass
/// pill, or a glass pill per entry (the default, round 10).
enum FooterMetricsStyle: String, CaseIterable, Identifiable, Sendable {
    case text = "Text"
    case onePill = "One pill"
    case pillPerEntry = "Pill per entry"
    var id: String { rawValue }
}

extension BottomPanelStatusBar {
    var metricsSection: some View {
        HStack(spacing: configuration.metricsStyle == .pillPerEntry ? SpacingTokens.xxs : SpacingTokens.xs) {
            if let metrics = configuration.metrics {
                if let selection = metrics.selectionText {
                    entry {
                        Text(selection)
                            .font(TypographyTokens.detail.monospacedDigit())
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .lineLimit(1)
                    }
                }
                entry {
                    HStack(spacing: SpacingTokens.xxxs) {
                        Text(metrics.rowCountText)
                            .font(TypographyTokens.detail.monospaced().weight(.medium))
                            .foregroundStyle(ColorTokens.Text.secondary)
                        Text(metrics.rowCountLabel)
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                }
                if let duration = metrics.durationText {
                    entry {
                        Text(duration)
                            .font(TypographyTokens.detail.monospaced().weight(.medium))
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                }
            }
            // The status always sits at the far right.
            if let bubble = configuration.statusBubble {
                entry {
                    if bubble.menu.isEmpty {
                        StatusBubbleLabel(bubble: bubble)
                    } else {
                        Menu {
                            ForEach(bubble.menu) { item in
                                Button(role: item.isDestructive ? .destructive : nil, action: item.action) {
                                    Label(item.title, systemImage: item.systemImage)
                                }
                            }
                        } label: {
                            StatusBubbleLabel(bubble: bubble)
                        }
                        .menuStyle(.button)
                        .buttonStyle(.plain)
                        .menuIndicator(.hidden)
                        .fixedSize()
                    }
                }
            }
        }
        .modifier(FooterPill(isPill: configuration.metricsStyle == .onePill))
        .contentShape(Rectangle())
        .onTapGesture {
            if configuration.statisticsPopover != nil,
               let binding = configuration.showStatisticsPopover {
                binding.wrappedValue.toggle()
            } else {
                configuration.onTogglePanel()
            }
        }
        .popover(isPresented: configuration.showStatisticsPopover ?? .constant(false)) {
            if let popoverView = configuration.statisticsPopover {
                popoverView
            }
        }
    }

    private func entry(@ViewBuilder _ content: () -> some View) -> some View {
        content().modifier(FooterPill(isPill: configuration.metricsStyle == .pillPerEntry))
    }
}

/// A footer chip's glass capsule, the same size as the server · database chip.
private struct FooterPill: ViewModifier {
    let isPill: Bool

    func body(content: Content) -> some View {
        if isPill {
            content
                .padding(.horizontal, LayoutTokens.Footer.chipHorizontalPadding)
                .frame(height: LayoutTokens.Footer.chipHeight)
                .glassEffect(.regular, in: .capsule)
        } else {
            content
        }
    }
}

/// The status: a pulsing dot and a word, or (round 21) an icon and a word in the tint, with the
/// time since `since` once it passes a minute.
private struct StatusBubbleLabel: View {
    let bubble: BottomPanelStatusBarConfiguration.StatusBubble

    var body: some View {
        HStack(spacing: SpacingTokens.xxs) {
            if let icon = bubble.icon {
                Image(systemName: icon)
                    .font(TypographyTokens.detail.weight(.semibold))
                    .foregroundStyle(bubble.tint)
            } else {
                PulsingStatusDot(tint: bubble.tint, isPulsing: bubble.isPulsing)
            }
            Text(bubble.label)
                .font(TypographyTokens.detail)
                .foregroundStyle(bubble.icon == nil ? ColorTokens.Text.secondary : bubble.tint)
            if let since = bubble.since {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let seconds = Int(context.date.timeIntervalSince(since))
                    if seconds >= 60 {
                        Text(String(format: "%d:%02d", seconds / 60, seconds % 60))
                            .font(TypographyTokens.detail.monospacedDigit())
                            .foregroundStyle(bubble.tint)
                    }
                }
            }
        }
    }
}
