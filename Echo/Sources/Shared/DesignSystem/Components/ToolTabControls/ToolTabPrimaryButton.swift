import SwiftUI

/// A tool tab's main action (round 37.3, PA1): a 28pt glass capsule, its symbol in the accent
/// colour and its word in grey. While what it started runs, it becomes Stop with a pulsing red
/// dot (ST1). It lives in the tool's header line, never in the window toolbar (round 45).
struct ToolTabPrimaryButton: View {
    let title: String
    let systemImage: String
    var isRunning = false
    var runningTitle: String?
    var isDisabled = false
    let action: () -> Void

    private var shownTitle: String { isRunning ? (runningTitle ?? "Stop") : title }

    var body: some View {
        Button(action: action) {
            HStack(spacing: SpacingTokens.xxs2) {
                if isRunning {
                    PulsingStatusDot(tint: ColorTokens.Status.error, isPulsing: true)
                } else {
                    Image(systemName: systemImage)
                        .foregroundStyle(isDisabled ? ColorTokens.Text.tertiary : ColorTokens.accent)
                }
                Text(shownTitle)
                    .foregroundStyle(isDisabled ? ColorTokens.Text.tertiary : ColorTokens.Text.secondary)
            }
            .font(TypographyTokens.standard.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, SpacingTokens.sm)
            .frame(height: LayoutTokens.ToolTab.controlHeight)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .disabled(isDisabled)
        .help(shownTitle)
        .accessibilityLabel(shownTitle)
    }
}
