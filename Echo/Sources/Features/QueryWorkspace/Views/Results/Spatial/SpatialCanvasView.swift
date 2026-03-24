import SwiftUI

/// Renders spatial geometries on a zoomable, pannable canvas with coordinate axes.
struct SpatialCanvasView: View {
    let geometries: [SpatialGeometry]

    @State private(set) var zoom: CGFloat = 1.0
    @State private(set) var contentOffset: CGSize = .zero
    @State private(set) var lastDragOffset: CGSize = .zero
    @State private var hasFitContent = false

    let minZoom: CGFloat = 0.1
    let maxZoom: CGFloat = 20.0
    let axisMargin: CGFloat = 48

    var body: some View {
        GeometryReader { geometry in
            let canvasSize = geometry.size
            let bounds = computeBounds()

            ZStack {
                ColorTokens.Background.primary

                Canvas { context, size in
                    let viewport = SpatialViewport(
                        canvasSize: size,
                        dataBounds: bounds,
                        zoom: zoom,
                        offset: contentOffset,
                        axisMargin: axisMargin
                    )
                    drawGrid(context: &context, size: size, viewport: viewport)
                    drawAxes(context: &context, size: size, viewport: viewport, bounds: bounds)
                    drawGeometries(context: &context, viewport: viewport)
                }
                .gesture(panGesture)
                .gesture(magnificationGesture)
                .overlay(CommandScrollZoomCapture { delta in
                    applyScrollZoom(delta)
                })

                SpatialCanvasLegend(geometries: geometries, palette: spatialPalette)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(SpacingTokens.sm)

                SpatialCanvasZoomControls(
                    zoom: $zoom,
                    minZoom: minZoom,
                    maxZoom: maxZoom,
                    onFitContent: { fitContent(in: canvasSize, bounds: bounds) }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(SpacingTokens.lg)
            }
            .onAppear {
                if !hasFitContent {
                    fitContent(in: canvasSize, bounds: bounds)
                    hasFitContent = true
                }
            }
            .onChange(of: geometries.count) { _, _ in
                fitContent(in: canvasSize, bounds: computeBounds())
            }
        }
    }

    // MARK: - Bounds

    func computeBounds() -> SpatialBounds {
        guard !geometries.isEmpty else {
            return SpatialBounds(minX: -1, minY: -1, maxX: 1, maxY: 1)
        }
        var bounds = SpatialBounds(
            minX: .greatestFiniteMagnitude,
            minY: .greatestFiniteMagnitude,
            maxX: -.greatestFiniteMagnitude,
            maxY: -.greatestFiniteMagnitude
        )
        for geom in geometries {
            geom.shape.extendBounds(&bounds)
        }
        if bounds.width < 1e-9 {
            bounds.minX -= 1; bounds.maxX += 1
        }
        if bounds.height < 1e-9 {
            bounds.minY -= 1; bounds.maxY += 1
        }
        return bounds
    }

    // MARK: - Gestures

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .local)
            .onChanged { value in
                contentOffset = CGSize(
                    width: lastDragOffset.width + value.translation.width,
                    height: lastDragOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastDragOffset = contentOffset
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                zoom = max(minZoom, min(maxZoom, zoom * scale))
            }
            .onEnded { scale in
                zoom = max(minZoom, min(maxZoom, zoom * scale))
            }
    }

    private func applyScrollZoom(_ delta: CGFloat) {
        let sensitivity: CGFloat = 0.01
        let adjustment = 1 + (-delta * sensitivity)
        zoom = max(minZoom, min(maxZoom, zoom * adjustment))
    }

    // MARK: - Fit Content

    func fitContent(in size: CGSize, bounds: SpatialBounds) {
        let drawableWidth = max(size.width - axisMargin - SpacingTokens.lg, 1)
        let drawableHeight = max(size.height - axisMargin - SpacingTokens.lg, 1)
        let scaleX = drawableWidth / CGFloat(bounds.width)
        let scaleY = drawableHeight / CGFloat(bounds.height)
        let fitScale = min(scaleX, scaleY) * 0.85
        zoom = max(minZoom, min(maxZoom, fitScale))
        contentOffset = .zero
        lastDragOffset = .zero
    }
}
