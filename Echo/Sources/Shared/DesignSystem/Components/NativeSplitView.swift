import SwiftUI
import AppKit

/// A SwiftUI wrapper around NSSplitView for smooth, native macOS split behavior.
/// Avoids GeometryReader + explicit frame recalculation that causes jank with Tables.
struct NativeSplitView<First: View, Second: View>: NSViewRepresentable {
    let isVertical: Bool
    let firstMinFraction: CGFloat
    let secondMinFraction: CGFloat
    @Binding var fraction: CGFloat
    var onDraggingChanged: ((Bool) -> Void)? = nil
    @ViewBuilder let first: () -> First
    @ViewBuilder let second: () -> Second

    func makeNSView(context: Context) -> NSSplitView {
        let splitView = NSSplitView()
        splitView.isVertical = isVertical
        splitView.dividerStyle = .thin
        splitView.delegate = context.coordinator

        let firstHost = NSHostingView(rootView: first())
        let secondHost = NSHostingView(rootView: second())

        // Prevent hosting views from forcing intrinsic sizes or window expansion
        for host in [firstHost, secondHost] {
            host.setContentHuggingPriority(.defaultLow, for: .horizontal)
            host.setContentHuggingPriority(.defaultLow, for: .vertical)
            host.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            host.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        }

        splitView.addArrangedSubview(firstHost)
        splitView.addArrangedSubview(secondHost)

        context.coordinator.splitView = splitView
        context.coordinator.isVertical = isVertical

        return splitView
    }

    func updateNSView(_ splitView: NSSplitView, context: Context) {
        context.coordinator.firstMinFraction = firstMinFraction
        context.coordinator.secondMinFraction = secondMinFraction
        context.coordinator.fractionBinding = $fraction
        context.coordinator.isVertical = isVertical
        context.coordinator.onDraggingChanged = onDraggingChanged

        // Update child views
        if let firstHost = splitView.arrangedSubviews.first as? NSHostingView<First> {
            firstHost.rootView = first()
        }
        if splitView.arrangedSubviews.count > 1, let secondHost = splitView.arrangedSubviews[1] as? NSHostingView<Second> {
            secondHost.rootView = second()
        }

        // Set divider position if not currently dragging
        if !context.coordinator.isDragging {
            let total = isVertical ? splitView.bounds.width : splitView.bounds.height
            if total > 0 {
                let position = total * fraction
                splitView.setPosition(position, ofDividerAt: 0)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            fraction: $fraction,
            firstMinFraction: firstMinFraction,
            secondMinFraction: secondMinFraction,
            isVertical: isVertical,
            onDraggingChanged: onDraggingChanged
        )
    }

    @MainActor
    final class Coordinator: NSObject, NSSplitViewDelegate, @unchecked Sendable {
        var fractionBinding: Binding<CGFloat>
        var firstMinFraction: CGFloat
        var secondMinFraction: CGFloat
        var isVertical: Bool
        var isDragging = false
        var onDraggingChanged: ((Bool) -> Void)?
        weak var splitView: NSSplitView?

        init(
            fraction: Binding<CGFloat>,
            firstMinFraction: CGFloat,
            secondMinFraction: CGFloat,
            isVertical: Bool,
            onDraggingChanged: ((Bool) -> Void)?
        ) {
            self.fractionBinding = fraction
            self.firstMinFraction = firstMinFraction
            self.secondMinFraction = secondMinFraction
            self.isVertical = isVertical
            self.onDraggingChanged = onDraggingChanged
        }

        nonisolated func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
            MainActor.assumeIsolated {
                let total = isVertical ? splitView.bounds.width : splitView.bounds.height
                return total * firstMinFraction
            }
        }

        nonisolated func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
            MainActor.assumeIsolated {
                let total = isVertical ? splitView.bounds.width : splitView.bounds.height
                return total * (1.0 - secondMinFraction)
            }
        }

        nonisolated func splitViewWillResizeSubviews(_ notification: Notification) {
            MainActor.assumeIsolated {
                isDragging = true
                onDraggingChanged?(true)
            }
        }

        nonisolated func splitViewDidResizeSubviews(_ notification: Notification) {
            MainActor.assumeIsolated {
                guard let splitView else { return }
                let total = isVertical ? splitView.bounds.width : splitView.bounds.height
                guard total > 0 else { return }
                let firstSize = isVertical
                    ? splitView.arrangedSubviews.first?.frame.width ?? 0
                    : splitView.arrangedSubviews.first?.frame.height ?? 0
                let newFraction = firstSize / total
                if abs(newFraction - fractionBinding.wrappedValue) > 0.001 {
                    fractionBinding.wrappedValue = newFraction
                }
            }
        }

        nonisolated func splitView(_ splitView: NSSplitView, resizeSubviewsWithOldSize oldSize: NSSize) {
            MainActor.assumeIsolated {
                let total = isVertical ? splitView.bounds.width : splitView.bounds.height
                let dividerThickness = splitView.dividerThickness
                let firstSize = total * fractionBinding.wrappedValue
                let secondSize = total - firstSize - dividerThickness

                if splitView.arrangedSubviews.count >= 2 {
                    let firstView = splitView.arrangedSubviews[0]
                    let secondView = splitView.arrangedSubviews[1]

                    if isVertical {
                        firstView.frame = NSRect(x: 0, y: 0, width: firstSize, height: splitView.bounds.height)
                        secondView.frame = NSRect(x: firstSize + dividerThickness, y: 0, width: secondSize, height: splitView.bounds.height)
                    } else {
                        // NSSplitView is flipped: y=0 at top
                        firstView.frame = NSRect(x: 0, y: 0, width: splitView.bounds.width, height: firstSize)
                        secondView.frame = NSRect(x: 0, y: firstSize + dividerThickness, width: splitView.bounds.width, height: secondSize)
                    }
                }

                isDragging = false
                onDraggingChanged?(false)
            }
        }
    }
}
