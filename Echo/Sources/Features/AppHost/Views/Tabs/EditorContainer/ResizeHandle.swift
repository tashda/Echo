import SwiftUI

struct ResizeHandle: View {
    let ratio: CGFloat
    let minRatio: CGFloat
    let maxRatio: CGFloat
    let availableHeight: CGFloat
    let onLiveUpdate: (CGFloat) -> Void
    let onCommit: (CGFloat) -> Void

    @State private var dragStartRatio: CGFloat = 0
    @State private var isDragging = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.secondary.opacity(0.15))
                .frame(height: 2)
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 60, height: 3)
        }
        .frame(height: 8)
        .background(Color.clear)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isDragging {
                        dragStartRatio = ratio
                        isDragging = true
                    }

                    let delta = value.translation.height / max(availableHeight, 1)
                    let proposed = min(max(dragStartRatio + delta, minRatio), maxRatio)
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        onLiveUpdate(proposed)
                    }
                }
                .onEnded { value in
                    let delta = value.translation.height / max(availableHeight, 1)
                    let proposed = min(max(dragStartRatio + delta, minRatio), maxRatio)
                    isDragging = false
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        onCommit(proposed)
                    }
                }
        )
#if os(macOS)
        .onHover { hovering in
            if hovering {
                NSCursor.resizeUpDown.set()
            } else {
                NSCursor.arrow.set()
            }
        }
#endif
    }
}
