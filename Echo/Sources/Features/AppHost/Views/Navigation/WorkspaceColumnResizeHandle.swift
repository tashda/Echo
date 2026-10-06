import SwiftUI

/// The gutter beside a canvas column (the tree, the inspector), which resizes the column when
/// dragged. Double-click returns it to its default width. `edge` is the column's side the handle is
/// on: a trailing handle grows the column to the right, a leading one to the left.
struct WorkspaceColumnResizeHandle: View {
    @Binding var width: Double
    let gutter: CGFloat
    let range: ClosedRange<Double>
    let defaultWidth: Double
    let edge: HorizontalEdge
    let accessibilityLabel: String

    @State private var widthAtDragStart: Double?

    var body: some View {
        Color.clear
            .frame(width: gutter)
            .frame(maxHeight: .infinity)
            .overlay {
                // Wider than the gutter so it is easy to grab.
                Color.clear
                    .frame(width: max(gutter, LayoutTokens.Workspace.treeResizeHandleWidth))
                    .contentShape(Rectangle())
                    .pointerStyle(.columnResize)
                    .gesture(drag)
                    .onTapGesture(count: 2) { width = defaultWidth }
            }
            .accessibilityElement()
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue("\(Int(width)) points")
            .accessibilityAdjustableAction { direction in
                let step = Double(SpacingTokens.md)
                switch direction {
                case .increment: width = clamp(width + step)
                case .decrement: width = clamp(width - step)
                @unknown default: break
                }
            }
    }

    private var drag: some Gesture {
        // Global coordinates, because the handle itself moves as the column resizes.
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .onChanged { value in
                let start = widthAtDragStart ?? width
                if widthAtDragStart == nil { widthAtDragStart = start }
                let delta = Double(value.translation.width)
                // The column follows the pointer: its width spring (a click on the handle's keys) must not run on every drag event.
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { width = clamp(edge == .trailing ? start + delta : start - delta) }
            }
            .onEnded { _ in
                widthAtDragStart = nil
            }
    }

    private func clamp(_ value: Double) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
