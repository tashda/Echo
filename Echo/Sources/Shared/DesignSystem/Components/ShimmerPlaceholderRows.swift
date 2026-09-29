import SwiftUI

/// Placeholder rows shown while a list loads (Design/05-components.md › Explorer tree): an icon
/// square and a text bar per row, with a soft highlight sweeping across them. The sweep stops
/// with Reduce Motion. Real rows crossfade in over them when they arrive.
struct ShimmerPlaceholderRows: View {
    var count: Int = 3
    let rowHeight: CGFloat
    /// Leading inset, so the placeholders sit at the indent of the rows they stand in for.
    var leadingInset: CGFloat = 0
    /// What's loading, for VoiceOver.
    var accessibilityLabel: String = "Loading"

    @Environment(\.echoMotion) private var motion
    @State private var phase: CGFloat = -1

    /// Text bar widths, varied so the placeholders read as a list rather than a block.
    private static let barWidths: [CGFloat] = [0.62, 0.44, 0.54, 0.38]

    var body: some View {
        placeholderShapes
            .foregroundStyle(ColorTokens.Sidebar.hoverFill)
            .overlay { sweep.mask { placeholderShapes } }
            .onAppear(perform: startSweep)
            .onChange(of: motion.allowsLoopingEffects) { _, _ in startSweep() }
            .accessibilityElement()
            .accessibilityLabel(accessibilityLabel)
    }

    /// An icon square and a text bar per row; drawn once filled and once as the sweep's mask.
    private var placeholderShapes: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            ForEach(0..<count, id: \.self) { index in
                HStack(spacing: SidebarRowConstants.iconTextSpacing) {
                    RoundedRectangle(cornerRadius: LayoutTokens.Shimmer.iconCornerRadius, style: .continuous)
                        .frame(width: LayoutTokens.Shimmer.iconSize, height: LayoutTokens.Shimmer.iconSize)
                    GeometryReader { proxy in
                        Capsule()
                            .frame(width: proxy.size.width * Self.barWidths[index % Self.barWidths.count])
                            .frame(maxHeight: .infinity, alignment: .center)
                    }
                    .frame(height: LayoutTokens.Shimmer.barHeight)
                }
                .frame(height: rowHeight)
            }
        }
        .padding(.leading, leadingInset)
        .padding(.trailing, SpacingTokens.lg)
    }

    private var sweep: some View {
        GeometryReader { proxy in
            LinearGradient(
                colors: [.clear, ColorTokens.Sidebar.selectedFill, .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: proxy.size.width * LayoutTokens.Shimmer.sweepWidthFraction)
            .offset(x: phase * proxy.size.width)
        }
        .opacity(motion.allowsLoopingEffects ? 1 : 0)
        .allowsHitTesting(false)
    }

    private func startSweep() {
        guard motion.allowsLoopingEffects else { return }
        phase = -LayoutTokens.Shimmer.sweepWidthFraction
        withAnimation(.linear(duration: LayoutTokens.Shimmer.sweepDuration).repeatForever(autoreverses: false)) {
            phase = 1
        }
    }
}
