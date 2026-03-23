import SwiftUI

/// A bezier curve arrow from source to destination.
struct ExecutionPlanArrowShape: Shape {
    let from: CGPoint
    let to: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: from)
        let controlOffset = abs(to.x - from.x) * 0.35
        path.addCurve(
            to: to,
            control1: CGPoint(x: from.x - controlOffset, y: from.y),
            control2: CGPoint(x: to.x + controlOffset, y: to.y)
        )
        return path
    }
}

/// A small triangular arrowhead pointing left.
struct ExecutionPlanArrowheadShape: Shape {
    let at: CGPoint
    let size: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: at.x + size, y: at.y - size * 0.5))
        path.addLine(to: at)
        path.addLine(to: CGPoint(x: at.x + size, y: at.y + size * 0.5))
        path.closeSubpath()
        return path
    }
}
