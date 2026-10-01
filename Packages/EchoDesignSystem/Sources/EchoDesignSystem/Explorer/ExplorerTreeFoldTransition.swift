import SwiftUI

/// A server card folding or opening (round 30.2, CM2): its bottom edge glides between where it
/// ends open and where it ends closed (the header and the card's bottom padding), in the tree's
/// coordinates. The cards layer moves the edge; the rows use this to fade and be cut by it.
public struct ExplorerTreeFold: Sendable, Equatable {
    public let openBottom: CGFloat
    public let closedBottom: CGFloat
    public let cornerRadius: CGFloat

    public init(openBottom: CGFloat, closedBottom: CGFloat, cornerRadius: CGFloat) {
        self.openBottom = openBottom
        self.closedBottom = closedBottom
        self.cornerRadius = cornerRadius
    }

    /// Round 46, DA2: the dock starts 8% smaller and this far out of focus.
    public static let growScale: CGFloat = 0.08
    public static let growBlur: CGFloat = SpacingTokens.xxxs

    /// Where the edge is when the fold is `progress` of the way closed (0 open, 1 closed).
    public func edge(at progress: Double) -> CGFloat {
        openBottom - CGFloat(progress) * (openBottom - closedBottom)
    }
}

/// A row of a folding card leaves (or arrives) while the card's edge passes over it, cut by the
/// edge and the card's rounded corners, so it never shows outside the card. It runs on the fold's
/// own animation, the same one that moves the edge.
public struct ExplorerTreeFoldTransition: Transition {
    /// How the row itself changes while the edge passes it.
    public enum Style: Sendable {
        /// It fades.
        case fade
        /// Round 46, DA2: it grows out of the header, from 92% and out of focus, without fading,
        /// so glass keeps its blur from the first frame.
        case grow
    }

    let fold: ExplorerTreeFold
    let rowTop: CGFloat
    let style: Style

    public init(fold: ExplorerTreeFold, rowTop: CGFloat, style: Style = .fade) {
        self.fold = fold
        self.rowTop = rowTop
        self.style = style
    }

    public func body(content: Content, phase: TransitionPhase) -> some View {
        content.modifier(ExplorerTreeFoldCut(fold: fold, rowTop: rowTop, style: style, progress: phase.isIdentity ? 0 : 1))
    }
}

/// The row's fade and cut at one moment of the fold.
private struct ExplorerTreeFoldCut: ViewModifier, Animatable {
    let fold: ExplorerTreeFold
    let rowTop: CGFloat
    let style: ExplorerTreeFoldTransition.Style
    var progress: Double

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let grows = style == .grow
        content
            .scaleEffect(grows ? 1 - ExplorerTreeFold.growScale * progress : 1, anchor: .top)
            .blur(radius: grows ? ExplorerTreeFold.growBlur * progress : 0)
            .opacity(grows ? 1 : 1 - progress)
            .clipShape(ExplorerTreeFoldEdge(edge: fold.edge(at: progress) - rowTop, cornerRadius: fold.cornerRadius))
    }
}

/// Everything above the card's moving edge, in the row's own coordinates, with the card's
/// rounded bottom corners at the edge. It reaches past the row's own slot, so colour a row draws
/// below itself (the server header's wash, round 30.1) is cut by the edge too, not by the slot.
private struct ExplorerTreeFoldEdge: Shape {
    let edge: CGFloat
    let cornerRadius: CGFloat

    nonisolated func path(in rect: CGRect) -> Path {
        let bottom = edge
        let top = rect.minY - cornerRadius
        guard bottom > rect.minY else { return Path() }
        let radius = min(cornerRadius, (bottom - top) / 2)
        return UnevenRoundedRectangle(bottomLeadingRadius: radius, bottomTrailingRadius: radius, style: .continuous)
            .path(in: CGRect(x: rect.minX, y: top, width: rect.width, height: bottom - top))
    }
}
