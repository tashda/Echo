import CoreGraphics
import Foundation

/// A tab being dragged along the strip (TABS-2.13): where it started, where it would land and how
/// far it has moved. Tabs differ in width while a tool tab shows its pages (round 49), so every step
/// uses the widths the tabs had when the drag began rather than one shared width.
struct TabDragState: Equatable {
    var id: UUID?
    var originalIndex = 0
    var currentIndex = 0
    var translation: CGFloat = 0
    var minIndex = 0
    var maxIndex = 0
    /// Every tab's width, in strip order, when the drag began.
    var widths: [CGFloat] = []

    /// A neighbour gives way once the dragged tab has covered this share of it: the point at
    /// which tabs swapped before tabs could differ in width.
    static let swapThreshold: CGFloat = 0.6

    var isActive: Bool { id != nil }

    mutating func begin(id: UUID, originalIndex: Int, minIndex: Int, maxIndex: Int, widths: [CGFloat]) {
        self = TabDragState(id: id, originalIndex: originalIndex, currentIndex: originalIndex,
                            minIndex: minIndex, maxIndex: maxIndex, widths: widths)
    }

    mutating func reset() {
        self = TabDragState()
    }

    private func width(at index: Int) -> CGFloat {
        widths.indices.contains(index) ? widths[index] : 0
    }

    /// The translation, kept between the first and the last place the tab may take.
    func clamped(_ translation: CGFloat) -> CGFloat {
        let maxRight = stride(from: originalIndex + 1, through: maxIndex, by: 1).reduce(CGFloat.zero) { $0 + width(at: $1) }
        let maxLeft = stride(from: minIndex, to: originalIndex, by: 1).reduce(CGFloat.zero) { $0 + width(at: $1) }
        return min(max(translation, -maxLeft), maxRight)
    }

    /// The place the tab would land at after moving `translation` points.
    func proposedIndex(for translation: CGFloat) -> Int {
        var index = originalIndex
        var remainder = translation
        if translation > 0 {
            while index < maxIndex, remainder > width(at: index + 1) * Self.swapThreshold {
                remainder -= width(at: index + 1)
                index += 1
            }
        } else {
            while index > minIndex, remainder < -width(at: index - 1) * Self.swapThreshold {
                remainder += width(at: index - 1)
                index -= 1
            }
        }
        return index
    }

    /// How far the tab at `index` is moved: the dragged tab by the pointer, the tabs it has passed
    /// by the dragged tab's own width, the opposite way.
    func offset(forTabAt index: Int) -> CGFloat {
        guard isActive else { return 0 }
        if index == originalIndex { return translation }
        let dragged = width(at: originalIndex)
        if currentIndex > originalIndex, index > originalIndex, index <= currentIndex { return -dragged }
        if currentIndex < originalIndex, index >= currentIndex, index < originalIndex { return dragged }
        return 0
    }
}
