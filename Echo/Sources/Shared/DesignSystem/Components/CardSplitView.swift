import SwiftUI

/// Two panes as two workspace cards, one gutter apart on the canvas (Design/05-components ›
/// Tool tabs: panes are cards). The gap between them is the resize handle.
struct CardSplitView<First: View, Second: View>: View {
    let axis: Axis
    @Binding var fraction: CGFloat
    var minFraction: CGFloat = 0.2
    /// False when the first pane is itself a split of cards.
    var cardsFirst = true
    @ViewBuilder let first: () -> First
    @ViewBuilder let second: () -> Second

    @Environment(ProjectStore.self) private var projectStore
    @State private var dragStartFraction: CGFloat?
    @State private var isHoveringGap = false

    var body: some View {
        GeometryReader { geometry in
            let gutter = projectStore.globalSettings.workspaceGutter.points
            let total = axis == .horizontal ? geometry.size.width : geometry.size.height
            let available = max(total - gutter, 0)
            let firstLength = available * Self.clamped(fraction, min: minFraction)

            let layout = axis == .horizontal ? AnyLayout(HStackLayout(spacing: SpacingTokens.none)) : AnyLayout(VStackLayout(spacing: SpacingTokens.none))
            layout {
                first()
                    .modifier(OptionalWorkspaceCard(isCard: cardsFirst))
                    .frame(width: axis == .horizontal ? firstLength : nil, height: axis == .vertical ? firstLength : nil)
                gap(length: gutter, available: available)
                second()
                    .workspaceCard()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func gap(length: CGFloat, available: CGFloat) -> some View {
        Color.clear
            .frame(width: axis == .horizontal ? length : nil, height: axis == .vertical ? length : nil)
            .overlay {
                Capsule()
                    .fill(ColorTokens.Text.tertiary)
                    .frame(width: axis == .horizontal ? LayoutTokens.Workspace.gapHandleHeight : LayoutTokens.Workspace.gapHandleWidth,
                           height: axis == .vertical ? LayoutTokens.Workspace.gapHandleHeight : LayoutTokens.Workspace.gapHandleWidth)
                    .opacity(isHoveringGap ? 1 : 0)
            }
            .contentShape(Rectangle().inset(by: -LayoutTokens.Workspace.gapHitSlop))
            .pointerStyle(axis == .horizontal ? .columnResize : .rowResize)
            .onHover { hovering in withAnimation(.easeOut(duration: 0.12)) { isHoveringGap = hovering } }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        guard available > 0 else { return }
                        let start = dragStartFraction ?? fraction
                        if dragStartFraction == nil { dragStartFraction = fraction }
                        let delta = axis == .horizontal ? value.translation.width : value.translation.height
                        fraction = Self.clamped(start + delta / available, min: minFraction)
                    }
                    .onEnded { _ in dragStartFraction = nil }
            )
            .accessibilityHidden(true)
    }

    static func clamped(_ value: CGFloat, min minimum: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minimum), 1 - minimum)
    }
}

private struct OptionalWorkspaceCard: ViewModifier {
    let isCard: Bool

    func body(content: Content) -> some View {
        if isCard { content.workspaceCard() } else { content }
    }
}
