import SwiftUI

/// Where the morph is, for the dock row inside it (set by `ExplorerDockMorphHost`; nil outside).
public struct ExplorerDockMorphState: Equatable, Sendable {
    public var progress: Double
    public var cornerRadius: CGFloat

    public init(progress: Double, cornerRadius: CGFloat) {
        self.progress = progress
        self.cornerRadius = cornerRadius
    }
}

extension EnvironmentValues {
    @Entry public var explorerDockMorph: ExplorerDockMorphState?
}

/// Sizes its one child from the dock slot to the pill: the width narrows to the pill's, centred, and
/// the height shrinks with the top held, as `progress` goes from 0 to 1. The slot it asks for never
/// changes, so the morph never makes the tree lay out again.
public struct ExplorerDockMorphLayout: Layout {
    public var progress: Double

    public init(progress: Double) {
        self.progress = progress
    }

    public var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: proposal.width ?? 0, height: proposal.height ?? 0)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let morph = ExplorerDockMorph(cardTop: 0, nameHeight: 0, dockHeight: bounds.height, cardBottom: 0)
        let width = morph.width(cardWidth: bounds.width, progress: progress)
        let height = morph.height(progress: progress)
        for subview in subviews {
            subview.place(at: CGPoint(x: bounds.midX, y: bounds.minY), anchor: .top,
                          proposal: ProposedViewSize(width: width, height: height))
        }
    }
}
