import SwiftUI

struct ResizeHandle: View {
    let ratio: CGFloat
    let minRatio: CGFloat
    let maxRatio: CGFloat
    let availableHeight: CGFloat
    let onLiveUpdate: (CGFloat) -> Void
    let onCommit: (CGFloat) -> Void
    var axis: Axis = .vertical

    @State private var dragStartRatio: CGFloat = 0
    @State private var isDragging = false

    var body: some View {
        Group {
            if axis == .vertical {
                verticalHandle
            } else {
                horizontalHandle
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    if !isDragging {
                        dragStartRatio = ratio
                        isDragging = true
                    }
                    let translation = axis == .vertical ? value.translation.height : value.translation.width
                    let delta = translation / max(availableHeight, 1)
                    let proposed = min(max(dragStartRatio + delta, minRatio), maxRatio)
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        onLiveUpdate(proposed)
                    }
                }
                .onEnded { value in
                    let translation = axis == .vertical ? value.translation.height : value.translation.width
                    let delta = translation / max(availableHeight, 1)
                    let proposed = min(max(dragStartRatio + delta, minRatio), maxRatio)
                    isDragging = false
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        onCommit(proposed)
                    }
                }
        )
        .onHover { hovering in
            if hovering {
                if axis == .vertical {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.resizeLeftRight.push()
                }
            } else {
                NSCursor.pop()
            }
        }
    }

    private var verticalHandle: some View {
        ZStack {
            Rectangle()
                .fill(Color.secondary.opacity(isDragging ? 0.25 : 0.12))
                .frame(height: 1)
            Capsule()
                .fill(Color.secondary.opacity(isDragging ? 0.5 : 0.3))
                .frame(width: 36, height: 3)
        }
        .frame(height: 9)
        .frame(maxWidth: .infinity)
    }

    private var horizontalHandle: some View {
        ZStack {
            Rectangle()
                .fill(Color.secondary.opacity(isDragging ? 0.25 : 0.12))
                .frame(width: 1)
            Capsule()
                .fill(Color.secondary.opacity(isDragging ? 0.5 : 0.3))
                .frame(width: 3, height: 36)
        }
        .frame(width: 9)
        .frame(maxHeight: .infinity)
    }
}
