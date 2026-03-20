import SwiftUI

struct DiagramMinimapView: View {
    let nodes: [SchemaDiagramNodeModel]
    let zoom: CGFloat
    let offset: CGSize
    let viewSize: CGSize
    let palette: DiagramPalette

    private let minimapSize: CGFloat = 160
    private let padding: CGFloat = 8

    var body: some View {
        let bounds = nodeBounds()
        guard bounds.width > 0, bounds.height > 0 else { return AnyView(EmptyView()) }

        let scale = min(
            (minimapSize - padding * 2) / bounds.width,
            (minimapSize - padding * 2) / bounds.height
        )
        let mapWidth = bounds.width * scale + padding * 2
        let mapHeight = bounds.height * scale + padding * 2

        return AnyView(
            Canvas { context, size in
                // Draw each node as a small rectangle
                for node in nodes {
                    let x = (node.position.x - bounds.minX) * scale + padding
                    let y = (node.position.y - bounds.minY) * scale + padding
                    let nodeRect = CGRect(x: x - 4, y: y - 3, width: 8, height: 6)
                    context.fill(
                        Path(roundedRect: nodeRect, cornerRadius: 1),
                        with: .color(palette.accent.opacity(0.7))
                    )
                }

                // Draw viewport indicator
                let vpWidth = viewSize.width / zoom
                let vpHeight = viewSize.height / zoom
                let vpCenterX = (-offset.width / zoom)
                let vpCenterY = (-offset.height / zoom)

                let vpRect = CGRect(
                    x: (vpCenterX - bounds.minX) * scale + padding,
                    y: (vpCenterY - bounds.minY) * scale + padding,
                    width: vpWidth * scale,
                    height: vpHeight * scale
                )
                context.stroke(
                    Path(roundedRect: vpRect, cornerRadius: 2),
                    with: .color(palette.accent),
                    lineWidth: 1.5
                )
            }
            .frame(width: mapWidth, height: mapHeight)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(palette.nodeBorder.opacity(0.3), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }

    private func nodeBounds() -> CGRect {
        guard !nodes.isEmpty else { return .zero }
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude

        for node in nodes {
            minX = min(minX, node.position.x)
            minY = min(minY, node.position.y)
            maxX = max(maxX, node.position.x)
            maxY = max(maxY, node.position.y)
        }

        let inset: CGFloat = 50
        return CGRect(
            x: minX - inset,
            y: minY - inset,
            width: maxX - minX + inset * 2,
            height: maxY - minY + inset * 2
        )
    }
}
