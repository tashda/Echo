import SwiftUI

/// Behind a pinned server name and dock: nothing while it rests in place, and once rows scroll
/// under it only a blur that fades out below the dock, with no fill or line (round 14 answer).
struct ExplorerPinnedHeaderBlur: View {
    let restingMinY: CGFloat
    let scroll: ExplorerTreeScrollState

    private var isPinned: Bool { scroll.offset > restingMinY + SpacingTokens.micro }

    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .mask {
                VStack(spacing: SpacingTokens.none) {
                    Color.black
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: LayoutTokens.ExplorerDock.blurFadeHeight)
                }
            }
            .padding(.bottom, -LayoutTokens.ExplorerDock.blurFadeHeight)
            .opacity(isPinned ? 1 : 0)
            .animation(.easeOut(duration: 0.12), value: isPinned)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
