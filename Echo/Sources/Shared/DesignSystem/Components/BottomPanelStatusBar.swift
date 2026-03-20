import SwiftUI

/// Configuration data for the bottom panel status bar.
struct BottomPanelStatusBarConfiguration {
    let connectionText: String
    let availableSegments: [PanelSegment]
    let disabledSegments: Set<PanelSegment>
    let selectedSegment: PanelSegment
    let onSelectSegment: (PanelSegment) -> Void
    let onTogglePanel: () -> Void
    let isPanelOpen: Bool

    var metrics: Metrics?
    var statusBubble: StatusBubble?

    init(
        connectionText: String,
        availableSegments: [PanelSegment],
        disabledSegments: Set<PanelSegment> = [],
        selectedSegment: PanelSegment,
        onSelectSegment: @escaping (PanelSegment) -> Void,
        onTogglePanel: @escaping () -> Void,
        isPanelOpen: Bool
    ) {
        self.connectionText = connectionText
        self.availableSegments = availableSegments
        self.disabledSegments = disabledSegments
        self.selectedSegment = selectedSegment
        self.onSelectSegment = onSelectSegment
        self.onTogglePanel = onTogglePanel
        self.isPanelOpen = isPanelOpen
    }

    struct Metrics {
        let rowCountText: String
        let rowCountLabel: String
        let durationText: String?
    }

    struct StatusBubble {
        let label: String
        let tint: Color
        let isPulsing: Bool
    }
}

/// Universal 24pt status bar at the bottom of every tab.
struct BottomPanelStatusBar: View {
    let configuration: BottomPanelStatusBarConfiguration

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                connectionLabel
                segmentToggles
                Spacer(minLength: SpacingTokens.sm)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        configuration.onTogglePanel()
                    }
                metricsSection
            }
            .padding(.leading, SpacingTokens.sm)
            .padding(.trailing, SpacingTokens.md1)
            .frame(height: 24)
        }
        .background(.bar)
        .transaction { $0.animation = nil }
    }

    private var connectionLabel: some View {
        Text(configuration.connectionText)
            .font(TypographyTokens.detail)
            .foregroundStyle(ColorTokens.Text.secondary)
            .lineLimit(1)
            .contentShape(Rectangle())
            .onTapGesture {
                configuration.onTogglePanel()
            }
    }

    @ViewBuilder
    private var segmentToggles: some View {
        if !configuration.availableSegments.isEmpty {
            ForEach(Array(configuration.availableSegments.enumerated()), id: \.element) { index, segment in
                segmentButton(segment)
                    .padding(.leading, index == 0 ? SpacingTokens.xs : SpacingTokens.xxs)
            }
        }
    }

    private func segmentButton(_ segment: PanelSegment) -> some View {
        let isActive = configuration.isPanelOpen && configuration.selectedSegment == segment
        let isDisabled = configuration.disabledSegments.contains(segment)
        return Button {
            configuration.onSelectSegment(segment)
        } label: {
            Image(systemName: segment.icon)
                .font(TypographyTokens.detail)
                .foregroundStyle(isActive ? ColorTokens.accent : ColorTokens.Text.secondary)
        }
        .buttonStyle(.borderless)
        .opacity(isDisabled ? 0.3 : 1)
        .disabled(isDisabled)
        .help(isDisabled ? segment.label : (isActive ? "Show Results" : "Show \(segment.label)"))
        .accessibilityLabel(segment.label)
    }

    @ViewBuilder
    private var metricsSection: some View {
        HStack(spacing: SpacingTokens.sm) {
            if let metrics = configuration.metrics {
                HStack(spacing: SpacingTokens.xxxs) {
                    Text(metrics.rowCountText)
                        .font(TypographyTokens.detail.monospaced().weight(.medium))
                        .foregroundStyle(ColorTokens.Text.secondary)
                    Text(metrics.rowCountLabel)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }

                if let duration = metrics.durationText {
                    Text(duration)
                        .font(TypographyTokens.detail.monospaced().weight(.medium))
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }

            if let bubble = configuration.statusBubble {
                HStack(spacing: SpacingTokens.xxs) {
                    PulsingStatusDot(tint: bubble.tint, isPulsing: bubble.isPulsing)
                    Text(bubble.label)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            configuration.onTogglePanel()
        }
    }
}
