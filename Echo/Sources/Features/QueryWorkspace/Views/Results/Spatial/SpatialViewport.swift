import SwiftUI

/// Transforms data coordinates to screen coordinates for the spatial canvas.
struct SpatialViewport {
    let canvasSize: CGSize
    let dataBounds: SpatialBounds
    let zoom: CGFloat
    let offset: CGSize
    let axisMargin: CGFloat

    var dataWidth: Double { dataBounds.width }
    var dataHeight: Double { dataBounds.height }

    private var drawableWidth: CGFloat { canvasSize.width - axisMargin }
    private var drawableHeight: CGFloat { canvasSize.height - axisMargin }

    /// Convert a data X value to screen X.
    func toScreenX(_ dataX: Double) -> CGFloat {
        let normalized = (dataX - dataBounds.minX) / dataBounds.width
        return axisMargin + CGFloat(normalized) * drawableWidth * zoom + offset.width
    }

    /// Convert a data Y value to screen Y.
    /// Y is flipped: data Y increases upward, screen Y increases downward.
    func toScreenY(_ dataY: Double) -> CGFloat {
        let normalized = (dataY - dataBounds.minY) / dataBounds.height
        return canvasSize.height - CGFloat(normalized) * drawableHeight * zoom - offset.height
    }

    func toScreen(_ coord: SpatialCoordinate) -> CGPoint {
        CGPoint(x: toScreenX(coord.x), y: toScreenY(coord.y))
    }
}

// MARK: - Color Palette

/// Cycling color palette for distinguishing spatial result rows.
struct SpatialRowPalette {
    private let colors: [Color] = [
        .blue, .red, .green, .orange, .purple,
        .cyan, .pink, .mint, .teal, .indigo,
        .brown, .yellow
    ]

    func color(for rowIndex: Int) -> Color {
        colors[rowIndex % colors.count]
    }
}

/// Shared palette instance used by the spatial canvas and legend.
let spatialPalette = SpatialRowPalette()
