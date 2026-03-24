import SwiftUI

/// Zoom controls for the spatial canvas, matching the SchemaDiagramView pattern.
struct SpatialCanvasZoomControls: View {
    @Binding var zoom: CGFloat
    let minZoom: CGFloat
    let maxZoom: CGFloat
    let onFitContent: () -> Void

    var body: some View {
        HStack(spacing: SpacingTokens.sm) {
            Button {
                zoom = max(minZoom, zoom - zoomStep)
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .buttonStyle(.bordered)
            .help("Zoom Out")

            Text("\(Int(zoom * 100))%")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
                .frame(width: 40, alignment: .center)
                .monospacedDigit()

            Button {
                zoom = min(maxZoom, zoom + zoomStep)
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .buttonStyle(.bordered)
            .help("Zoom In")

            Divider()
                .frame(height: 16)

            Button {
                onFitContent()
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .buttonStyle(.bordered)
            .help("Fit All")
        }
        .padding(SpacingTokens.xs2)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
    }

    private var zoomStep: CGFloat {
        if zoom < 1 { return 0.1 }
        else if zoom < 5 { return 0.5 }
        else { return 1.0 }
    }
}

/// Legend showing the color assigned to each row in the spatial results.
struct SpatialCanvasLegend: View {
    let geometries: [SpatialGeometry]
    let palette: SpatialRowPalette

    var body: some View {
        let entries = uniqueEntries
        if entries.count > 1 {
            VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                ForEach(entries, id: \.rowIndex) { entry in
                    HStack(spacing: SpacingTokens.xxs2) {
                        Circle()
                            .fill(palette.color(for: entry.rowIndex))
                            .frame(width: 8, height: 8)
                        Text(entry.label)
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                }
            }
            .padding(SpacingTokens.xs)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
        }
    }

    private var uniqueEntries: [LegendEntry] {
        var seen = Set<Int>()
        var entries: [LegendEntry] = []
        for geom in geometries {
            guard !seen.contains(geom.rowIndex) else { continue }
            seen.insert(geom.rowIndex)
            let label = "Row \(geom.rowIndex + 1): \(geom.columnName)"
            entries.append(LegendEntry(rowIndex: geom.rowIndex, label: label))
            if entries.count >= 12 { break }
        }
        return entries
    }

    private struct LegendEntry {
        let rowIndex: Int
        let label: String
    }
}
