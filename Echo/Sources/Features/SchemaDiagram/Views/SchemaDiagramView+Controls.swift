import SwiftUI
import EchoSense

extension SchemaDiagramView {
    var zoomControls: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                HStack(spacing: SpacingTokens.sm) {
                    Button {
                        updateZoom(to: max(minZoom, zoom - 0.1))
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    .buttonStyle(.bordered)
                    .help("Zoom Out")
                    .accessibilityLabel("Zoom Out")

                    Slider(value: Binding(
                        get: { zoom },
                        set: { updateZoom(to: $0) }
                    ), in: minZoom...maxZoom)
                    .frame(width: 160)

                    Button {
                        updateZoom(to: min(maxZoom, zoom + 0.1))
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .buttonStyle(.bordered)
                    .help("Zoom In")
                    .accessibilityLabel("Zoom In")

                    Divider()
                        .frame(height: 16)

                    Button {
                        zoomToFit(in: viewSize)
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                    }
                    .buttonStyle(.bordered)
                    .help("Zoom to Fit All")
                    .accessibilityLabel("Zoom to Fit All")
                }
                .padding(SpacingTokens.xs2)
                .background(.regularMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
                .padding(.bottom, SpacingTokens.lg)
                .padding(.trailing, SpacingTokens.lg)
            }
        }
    }

    var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                updateZoom(to: max(minZoom, min(maxZoom, zoom * scale)))
            }
            .onEnded { scale in
                updateZoom(to: max(minZoom, min(maxZoom, zoom * scale)))
            }
    }

    var panGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .local)
            .onChanged { value in
                guard !isDraggingNode else { return }
                contentOffset = CGSize(
                    width: lastDragOffset.width + value.translation.width,
                    height: lastDragOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                guard !isDraggingNode else { return }
                lastDragOffset = contentOffset
            }
    }

    func updateZoom(to newValue: CGFloat) {
        let clamped = max(minZoom, min(maxZoom, newValue))
        let basePosition = viewModel.node(for: viewModel.baseNodeID)?.position ?? .zero
        let currentCenter = CGPoint(x: basePosition.x * zoom, y: basePosition.y * zoom)
        let newCenter = CGPoint(x: basePosition.x * clamped, y: basePosition.y * clamped)
        let deltaOffset = CGSize(
            width: currentCenter.x - newCenter.x,
            height: currentCenter.y - newCenter.y
        )
        zoom = clamped
        let adjustedOffset = CGSize(
            width: contentOffset.width + deltaOffset.width,
            height: contentOffset.height + deltaOffset.height
        )
        contentOffset = adjustedOffset
        lastDragOffset = adjustedOffset
    }

    func applyZoom(from delta: CGFloat) {
        let sensitivity: CGFloat = 0.01
        let adjustment = 1 + (-delta * sensitivity)
        updateZoom(to: zoom * adjustment)
    }

    func centerDiagram(in size: CGSize, force: Bool = false) {
        if force {
            hasCenteredDiagram = false
        }
        guard !hasCenteredDiagram else { return }
        guard size.width.isFinite, size.height.isFinite else { return }
        let basePosition = viewModel.node(for: viewModel.baseNodeID)?.position ?? .zero
        let centerPoint = CGPoint(x: size.width / 2, y: size.height / 2)
        let scaledBase = CGPoint(x: basePosition.x * zoom, y: basePosition.y * zoom)
        let targetOffset = CGSize(
            width: centerPoint.x - scaledBase.x,
            height: centerPoint.y - scaledBase.y
        )
        contentOffset = targetOffset
        lastDragOffset = targetOffset
        hasCenteredDiagram = true
    }

    func zoomToFit(in size: CGSize) {
        guard !viewModel.nodes.isEmpty else { return }
        let nodeWidth: CGFloat = 220
        let nodeHeight: CGFloat = 60

        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude

        for node in viewModel.nodes {
            let halfW = nodeWidth / 2
            let halfH = (nodeHeight + CGFloat(node.columns.count) * 20) / 2
            minX = min(minX, node.position.x - halfW)
            minY = min(minY, node.position.y - halfH)
            maxX = max(maxX, node.position.x + halfW)
            maxY = max(maxY, node.position.y + halfH)
        }

        let contentWidth = maxX - minX
        let contentHeight = maxY - minY
        guard contentWidth > 0, contentHeight > 0 else { return }

        let padding: CGFloat = 80
        let availableWidth = size.width - padding * 2
        let availableHeight = size.height - padding * 2
        guard availableWidth > 0, availableHeight > 0 else { return }

        let fitZoom = min(availableWidth / contentWidth, availableHeight / contentHeight)
        let clampedZoom = max(minZoom, min(maxZoom, fitZoom))

        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2
        let viewCenter = CGPoint(x: size.width / 2, y: size.height / 2)

        zoom = clampedZoom
        let targetOffset = CGSize(
            width: viewCenter.x - centerX * clampedZoom,
            height: viewCenter.y - centerY * clampedZoom
        )
        contentOffset = targetOffset
        lastDragOffset = targetOffset
    }

    func backgroundGrid(in size: CGSize) -> some View {
        let gridColor = palette.gridLine
        let spacing: CGFloat = 64
        return Canvas { context, canvasSize in
            let step = spacing * zoom
            guard step > 8 else { return }
            var path = Path()

            let xRemainder = contentOffset.width.truncatingRemainder(dividingBy: step)
            let yRemainder = contentOffset.height.truncatingRemainder(dividingBy: step)

            var x: CGFloat = -step * 2 - xRemainder
            while x <= canvasSize.width + step * 2 {
                path.move(to: CGPoint(x: x, y: -step * 2))
                path.addLine(to: CGPoint(x: x, y: canvasSize.height + step * 2))
                x += step
            }

            var y: CGFloat = -step * 2 - yRemainder
            while y <= canvasSize.height + step * 2 {
                path.move(to: CGPoint(x: -step * 2, y: y))
                path.addLine(to: CGPoint(x: canvasSize.width + step * 2, y: y))
                y += step
            }

            context.stroke(path, with: .color(gridColor), lineWidth: 1)
        }
    }

    @ViewBuilder
    var statusOverlay: some View {
        if let error = viewModel.errorMessage {
            DiagramBlockingStatusCard(
                icon: "exclamationmark.triangle.fill",
                tint: palette.accent,
                title: "Unable to Load Diagram",
                message: error,
                palette: palette
            )
        } else if viewModel.isLoading && viewModel.nodes.isEmpty {
            DiagramBlockingStatusCard(
                icon: nil,
                tint: palette.accent,
                title: "Loading Diagram\u{2026}",
                message: viewModel.statusMessage ?? "Fetching structure and relationships",
                palette: palette
            )
        } else if let message = viewModel.statusMessage, !message.isEmpty {
            DiagramBannerStatus(message: message, showsProgress: viewModel.isLoading, palette: palette)
        }
    }
}
