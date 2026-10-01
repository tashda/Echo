import SwiftUI

/// How the footer's right-hand side is drawn: quiet text on the blur, all of it in one glass
/// pill, or a glass pill per entry (the default, round 10).
enum FooterMetricsStyle: String, CaseIterable, Identifiable, Sendable {
    case text = "Text"
    case onePill = "One pill"
    case pillPerEntry = "Pill per entry"
    var id: String { rawValue }
}

/// The right-hand pills that can open a popover of their own (round 41.5, PP2).
enum FooterPillKind: Hashable, Sendable {
    case selection
    case rows
    case time
    case status
}

extension BottomPanelStatusBar {
    var metricsSection: some View {
        HStack(spacing: configuration.metricsStyle == .pillPerEntry ? SpacingTokens.xxs : SpacingTokens.xs) {
            if let metrics = configuration.metrics {
                if let selection = metrics.selectionText {
                    entry(.selection) {
                        Text(selection)
                            .font(TypographyTokens.detail.monospacedDigit())
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .lineLimit(1)
                    }
                }
                entry(.rows) {
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
                    entry(.time) {
                        Text(duration)
                            .font(TypographyTokens.detail.monospaced().weight(.medium))
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                }
            }
            // The status always sits at the far right.
            if let bubble = configuration.statusBubble {
                if bubble.menu.isEmpty || configuration.pillPopovers[.status] != nil {
                    entry(.status) { StatusBubbleLabel(bubble: bubble) }
                } else {
                    entry(.status) {
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
        .onTapGesture { configuration.onTogglePanel() }
    }

    /// A pill; with a popover, clicking it opens that popover instead of the panel.
    private func entry(_ kind: FooterPillKind, @ViewBuilder _ content: () -> some View) -> some View {
        content()
            .modifier(FooterPill(isPill: configuration.metricsStyle == .pillPerEntry))
            .modifier(FooterPillPopover(content: configuration.pillPopovers[kind], isPresented: popoverBinding(kind)))
    }

    private func popoverBinding(_ kind: FooterPillKind) -> Binding<Bool> {
        Binding(
            get: { openPillPopover == kind },
            set: { isOpen in
                if isOpen { openPillPopover = kind } else if openPillPopover == kind { openPillPopover = nil }
            }
        )
    }
}

/// Opens a pill's popover above it on a click (round 41.5); no popover leaves the pill as it is.
private struct FooterPillPopover: ViewModifier {
    let content: AnyView?
    @Binding var isPresented: Bool

    func body(content pill: Content) -> some View {
        if let content {
            pill
                .contentShape(Capsule())
                .onTapGesture { isPresented.toggle() }
                .popover(isPresented: $isPresented, arrowEdge: .top) { content }
                .accessibilityAddTraits(.isButton)
        } else {
            pill
        }
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
        .help(bubble.help ?? "")
    }
}
