import SwiftUI

/// The tree's rows, each placed at its exact place from `ExplorerTreeLayout` (2026-10-01).
///
/// A `LazyVStack` estimates the height of rows it hasn't built yet, so after a jump deep into a
/// long card, or a new server arriving, the rows it showed sat up to several rows away from where
/// the layout (and so the cards, the veil, reveals and right-clicks) had them, and the room held
/// below the last card grew with the error. The canvas never estimates: it is as tall as the
/// layout says and puts each row it is given at its layout position. The tree gives it only the
/// rows in `ExplorerTreeWindow`, so it stays as cheap as a lazy stack.
public struct ExplorerTreeCanvasLayout: Layout {
    public let height: CGFloat

    public init(height: CGFloat) {
        self.height = height
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: proposal.width ?? 0, height: height)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for subview in subviews {
            let place = subview[ExplorerTreePlaceKey.self]
            subview.place(at: CGPoint(x: bounds.minX, y: bounds.minY + place.minY), anchor: .topLeading,
                          proposal: ProposedViewSize(width: bounds.width, height: place.height))
        }
    }

    public func explicitAlignment(of guide: HorizontalAlignment, in bounds: CGRect, proposal: ProposedViewSize,
                                  subviews: Subviews, cache: inout ()) -> CGFloat? {
        nil
    }

    public func explicitAlignment(of guide: VerticalAlignment, in bounds: CGRect, proposal: ProposedViewSize,
                                  subviews: Subviews, cache: inout ()) -> CGFloat? {
        nil
    }

    public func spacing(subviews: Subviews, cache: inout ()) -> ViewSpacing {
        ViewSpacing()
    }
}

/// Where a view sits on the canvas, in the tree's coordinates.
public struct ExplorerTreePlace: Equatable, Sendable {
    public var minY: CGFloat
    public var height: CGFloat
}

private struct ExplorerTreePlaceKey: LayoutValueKey {
    static let defaultValue = ExplorerTreePlace(minY: 0, height: 0)
}

extension View {
    /// Puts the view at `minY` on the canvas, `height` tall.
    public func explorerTreePlace(minY: CGFloat, height: CGFloat) -> some View {
        layoutValue(key: ExplorerTreePlaceKey.self, value: ExplorerTreePlace(minY: minY, height: height))
    }
}

/// The stretch of the tree the canvas builds rows for: the view and a margin of an eighth of a view
/// around it, moved in steps of that size. Every row in it is laid out on each frame the window
/// is laid out, so it is kept about as small as a lazy stack's; crossing a step rebuilds only the
/// list (unchanged rows keep their bodies, `ExplorerTreeRowHost`).
public struct ExplorerTreeWindow: Equatable, Sendable {
    public let minY: CGFloat
    public let maxY: CGFloat

    public init(minY: CGFloat, maxY: CGFloat) {
        self.minY = minY
        self.maxY = maxY
    }

    public static let initial = ExplorerTreeWindow(minY: 0, maxY: 2_000)

    public static func around(offset: CGFloat, viewport: CGFloat) -> ExplorerTreeWindow {
        guard viewport > 0 else { return initial }
        let step = max(viewport / 8, SpacingTokens.xxxl)
        let bucket = (max(offset, 0) / step).rounded(.down)
        return ExplorerTreeWindow(minY: max((bucket - 1) * step, 0), maxY: (bucket + 2) * step + viewport)
    }

    public func intersects(minY: CGFloat, maxY: CGFloat) -> Bool {
        maxY > self.minY && minY < self.maxY
    }
}

/// Builds the rows for the current window. It is the only view that reads `window`, so the
/// tree around it isn't rebuilt when the window steps.
public struct ExplorerTreeWindowed<Content: View>: View {
    let scroll: ExplorerTreeScrollState
    let content: (ExplorerTreeWindow) -> Content

    public init(scroll: ExplorerTreeScrollState, @ViewBuilder content: @escaping (ExplorerTreeWindow) -> Content) {
        self.scroll = scroll
        self.content = content
    }

    public var body: some View {
        content(scroll.window)
    }
}

/// One row's content, rebuilt only when its key changes. Stepping the window rebuilds the canvas's
/// list of rows; without this, every row in it would also run its body again, which a lazy stack
/// never did for rows already on screen.
public struct ExplorerTreeRowHost<Key: Equatable & Sendable, Content: View>: View, Equatable {
    nonisolated let key: Key
    let content: () -> Content

    public init(key: Key, @ViewBuilder content: @escaping () -> Content) {
        self.key = key
        self.content = content
    }

    public var body: some View { content() }

    public nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.key == rhs.key
    }
}

/// A server's name and dock stay at the top while the card's rows scroll under them, until the
/// end of the card pushes them up (TC1). The header moves as a visual effect, from where the
/// scroll view has it, so a scrolled frame neither runs a body nor lays anything out again.
public struct ExplorerTreePinnedHeader: ViewModifier {
    /// How far the header can travel down before the card's last row pushes it up.
    let travel: CGFloat

    public init(travel: CGFloat) {
        self.travel = travel
    }

    public func body(content: Content) -> some View {
        content.visualEffect { [travel] effect, proxy in
            let top = proxy.frame(in: .scrollView).minY
            return effect.offset(y: min(max(-top, 0), max(travel, 0)))
        }
    }
}
