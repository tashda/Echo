import SwiftUI
import EchoSense

struct RefreshAnimatedOverlay: View {
    let phase: RefreshButtonContent.Phase
    let showCancel: Bool
    let spinning: Bool
    let circleSize: CGFloat
    let glowPadding: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    private var shouldSpin: Bool {
        phase == .refreshing && !showCancel && spinning
    }

    private var currentSymbol: String {
        shouldSpin ? "arrow.clockwise" : spinnerSymbol
    }

    private var spinnerSymbol: String {
        if showCancel { return "xmark" }
        switch phase {
        case .completed: return "checkmark"
        default: return "arrow.clockwise"
        }
    }

    private var iconColor: Color {
        if showCancel {
            return Color.primary.opacity(colorScheme == .dark ? 0.95 : 0.9)
        }
        switch phase {
        case .idle:
            return Color.secondary.opacity(colorScheme == .dark ? 0.85 : 0.65)
        case .refreshing:
            return Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.85)
        case .completed:
            return Color.white
        }
    }

    private var circleFill: Color {
        switch phase {
        case .idle:
            return toolbarIdleFill(for: colorScheme)
        case .refreshing:
            return Color.yellow.opacity(colorScheme == .dark ? 0.35 : 0.18)
        case .completed:
            return Color.green.opacity(colorScheme == .dark ? 0.45 : 0.22)
        }
    }

    private var glowColor: Color {
        switch phase {
        case .refreshing: return Color.yellow
        case .completed: return Color.green
        case .idle: return .clear
        }
    }

    private var glowOpacity: Double {
        switch phase {
        case .refreshing: return showCancel ? 0.65 : 0.55
        case .completed: return 0.5
        case .idle: return 0
        }
    }

    var body: some View {
        ZStack {
            if glowOpacity > 0 {
                GlowBorder(cornerRadius: circleSize / 2, color: glowColor)
                    .frame(width: circleSize + glowPadding, height: circleSize + glowPadding)
                    .opacity(glowOpacity)
                    .allowsHitTesting(false)
            }

            Circle()
                .fill(circleFill)
                .frame(width: circleSize, height: circleSize)

            Image(systemName: currentSymbol)
                .rotationEffect(shouldSpin ? .degrees(360) : .degrees(0))
                .animation(
                    shouldSpin
                        ? .linear(duration: 0.9).repeatForever(autoreverses: false)
                        : .easeInOut(duration: 0.2),
                    value: shouldSpin
                )
                .transition(.asymmetric(insertion: .scale.combined(with: .opacity),
                                        removal: .opacity))
                .font(TypographyTokens.display.weight(.medium))
                .foregroundStyle(iconColor)
        }
    }
}
