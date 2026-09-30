import SwiftUI

/// The canvas gap between a content card and its panel card: the resize handle. A small grab
/// capsule appears on hover; drag to resize, double-click to maximise or restore the panel.
struct ContentPanelCardGap: View {
    let height: CGFloat
    /// The pointer's position in the cards' coordinate space while dragging.
    let onDrag: (CGFloat) -> Void
    let onDoubleClick: () -> Void

    @State private var isHovering = false
    @Environment(\.echoMotion) private var motion

    static let coordinateSpace = "content-panel-cards"

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay {
                Capsule()
                    .fill(ColorTokens.Text.tertiary)
                    .frame(width: LayoutTokens.Workspace.gapHandleWidth, height: LayoutTokens.Workspace.gapHandleHeight)
                    .opacity(isHovering ? 1 : 0)
            }
            .contentShape(Rectangle().inset(by: -LayoutTokens.Workspace.gapHitSlop))
            .pointerStyle(.rowResize)
            .onHover { hovering in
                withAnimation(motion.hover) { isHovering = hovering }
            }
            .onTapGesture(count: 2, perform: onDoubleClick)
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named(Self.coordinateSpace))
                    .onChanged { value in onDrag(value.location.y) }
            )
            .accessibilityElement()
            .accessibilityLabel("Resize content and panel")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: "Maximize or Restore Panel", onDoubleClick)
    }
}
