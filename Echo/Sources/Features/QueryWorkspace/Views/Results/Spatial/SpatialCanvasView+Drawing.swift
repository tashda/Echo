import SwiftUI

extension SpatialCanvasView {

    // MARK: - Grid

    func drawGrid(
        context: inout GraphicsContext,
        size: CGSize,
        viewport: SpatialViewport
    ) {
        let gridColor = ColorTokens.Separator.secondary.opacity(0.3)
        let step = niceGridStep(
            range: max(viewport.dataWidth, viewport.dataHeight) / Double(zoom)
        )
        var path = Path()

        let startX = (viewport.dataBounds.minX / step).rounded(.down) * step
        let endX = (viewport.dataBounds.maxX / step).rounded(.up) * step
        var x = startX
        while x <= endX {
            let screenX = viewport.toScreenX(x)
            if screenX >= axisMargin && screenX <= size.width {
                path.move(to: CGPoint(x: screenX, y: axisMargin))
                path.addLine(to: CGPoint(x: screenX, y: size.height))
            }
            x += step
        }

        let startY = (viewport.dataBounds.minY / step).rounded(.down) * step
        let endY = (viewport.dataBounds.maxY / step).rounded(.up) * step
        var y = startY
        while y <= endY {
            let screenY = viewport.toScreenY(y)
            if screenY >= axisMargin && screenY <= size.height {
                path.move(to: CGPoint(x: axisMargin, y: screenY))
                path.addLine(to: CGPoint(x: size.width, y: screenY))
            }
            y += step
        }

        context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
    }

    // MARK: - Axes

    func drawAxes(
        context: inout GraphicsContext,
        size: CGSize,
        viewport: SpatialViewport,
        bounds: SpatialBounds
    ) {
        let axisColor = ColorTokens.Text.tertiary
        let labelFont = Font.system(size: 9, design: .monospaced)
        let step = niceGridStep(
            range: max(viewport.dataWidth, viewport.dataHeight) / Double(zoom)
        )

        // X axis labels
        var x = (bounds.minX / step).rounded(.down) * step
        while x <= (bounds.maxX / step).rounded(.up) * step {
            let screenX = viewport.toScreenX(x)
            if screenX >= axisMargin && screenX <= size.width {
                context.draw(
                    Text(formatAxisValue(x)).font(labelFont).foregroundStyle(axisColor),
                    at: CGPoint(x: screenX, y: axisMargin / 2),
                    anchor: .center
                )
            }
            x += step
        }

        // Y axis labels
        var y = (bounds.minY / step).rounded(.down) * step
        while y <= (bounds.maxY / step).rounded(.up) * step {
            let screenY = viewport.toScreenY(y)
            if screenY >= axisMargin && screenY <= size.height {
                context.draw(
                    Text(formatAxisValue(y)).font(labelFont).foregroundStyle(axisColor),
                    at: CGPoint(x: axisMargin / 2, y: screenY),
                    anchor: .center
                )
            }
            y += step
        }

        // Axis lines
        var axisPath = Path()
        axisPath.move(to: CGPoint(x: axisMargin, y: axisMargin))
        axisPath.addLine(to: CGPoint(x: axisMargin, y: size.height))
        axisPath.move(to: CGPoint(x: axisMargin, y: size.height))
        axisPath.addLine(to: CGPoint(x: size.width, y: size.height))
        context.stroke(axisPath, with: .color(axisColor), lineWidth: 1)
    }

    // MARK: - Geometry Rendering

    func drawGeometries(
        context: inout GraphicsContext,
        viewport: SpatialViewport
    ) {
        for geom in geometries {
            let color = spatialPalette.color(for: geom.rowIndex)
            drawShape(context: &context, shape: geom.shape, color: color, viewport: viewport)
        }
    }

    private func drawShape(
        context: inout GraphicsContext,
        shape: SpatialShape,
        color: Color,
        viewport: SpatialViewport
    ) {
        switch shape {
        case .point(let coord):
            drawPoint(context: &context, coord: coord, color: color, viewport: viewport)
        case .multiPoint(let coords):
            for coord in coords {
                drawPoint(context: &context, coord: coord, color: color, viewport: viewport)
            }
        case .lineString(let coords):
            drawLineString(context: &context, coords: coords, color: color, viewport: viewport)
        case .multiLineString(let lines):
            for line in lines {
                drawLineString(context: &context, coords: line, color: color, viewport: viewport)
            }
        case .polygon(let rings):
            drawPolygon(context: &context, rings: rings, color: color, viewport: viewport)
        case .multiPolygon(let polygons):
            for rings in polygons {
                drawPolygon(context: &context, rings: rings, color: color, viewport: viewport)
            }
        case .geometryCollection(let shapes):
            for subShape in shapes {
                drawShape(context: &context, shape: subShape, color: color, viewport: viewport)
            }
        }
    }

    private func drawPoint(
        context: inout GraphicsContext,
        coord: SpatialCoordinate,
        color: Color,
        viewport: SpatialViewport
    ) {
        let screen = viewport.toScreen(coord)
        let radius: CGFloat = 4
        let circle = Path(ellipseIn: CGRect(
            x: screen.x - radius, y: screen.y - radius,
            width: radius * 2, height: radius * 2
        ))
        context.fill(circle, with: .color(color))
        context.stroke(circle, with: .color(color.opacity(0.8)), lineWidth: 1.5)
    }

    private func drawLineString(
        context: inout GraphicsContext,
        coords: [SpatialCoordinate],
        color: Color,
        viewport: SpatialViewport
    ) {
        guard coords.count >= 2 else { return }
        var path = Path()
        path.move(to: viewport.toScreen(coords[0]))
        for i in 1..<coords.count {
            path.addLine(to: viewport.toScreen(coords[i]))
        }
        context.stroke(
            path, with: .color(color),
            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
        )
    }

    private func drawPolygon(
        context: inout GraphicsContext,
        rings: [SpatialRing],
        color: Color,
        viewport: SpatialViewport
    ) {
        guard let exterior = rings.first, exterior.coordinates.count >= 3 else { return }
        var path = Path()
        path.move(to: viewport.toScreen(exterior.coordinates[0]))
        for i in 1..<exterior.coordinates.count {
            path.addLine(to: viewport.toScreen(exterior.coordinates[i]))
        }
        path.closeSubpath()

        for holeIndex in 1..<rings.count {
            let hole = rings[holeIndex]
            guard hole.coordinates.count >= 3 else { continue }
            path.move(to: viewport.toScreen(hole.coordinates[0]))
            for i in 1..<hole.coordinates.count {
                path.addLine(to: viewport.toScreen(hole.coordinates[i]))
            }
            path.closeSubpath()
        }

        context.fill(path, with: .color(color.opacity(0.25)))
        context.stroke(
            path, with: .color(color),
            style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
        )
    }

    // MARK: - Axis Formatting

    func niceGridStep(range: Double) -> Double {
        guard range > 0 else { return 1 }
        let rawStep = range / 6
        let magnitude = pow(10, floor(log10(rawStep)))
        let normalized = rawStep / magnitude
        let niceNormalized: Double
        if normalized <= 1 { niceNormalized = 1 }
        else if normalized <= 2 { niceNormalized = 2 }
        else if normalized <= 5 { niceNormalized = 5 }
        else { niceNormalized = 10 }
        return niceNormalized * magnitude
    }

    func formatAxisValue(_ value: Double) -> String {
        if abs(value) >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        } else if abs(value) >= 1_000 {
            return String(format: "%.1fK", value / 1_000)
        } else if abs(value) < 0.01 && value != 0 {
            return String(format: "%.4f", value)
        } else if value == value.rounded() {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }
}
