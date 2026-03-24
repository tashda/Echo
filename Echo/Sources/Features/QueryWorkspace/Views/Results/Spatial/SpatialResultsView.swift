import SwiftUI

/// Container view that extracts spatial data from query results and displays the canvas.
struct SpatialResultsView: View {
    let query: QueryEditorState

    @State private var geometries: [SpatialGeometry] = []
    @State private var extractionToken: Int = 0

    var body: some View {
        Group {
            if geometries.isEmpty {
                emptyState
            } else {
                SpatialCanvasView(geometries: geometries)
            }
        }
        .task(id: query.resultChangeToken) {
            extractGeometries()
        }
        .onAppear {
            if geometries.isEmpty {
                extractGeometries()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: SpacingTokens.sm) {
            Image(systemName: "map")
                .font(TypographyTokens.hero)
                .foregroundStyle(ColorTokens.Text.secondary)
            Text("No Spatial Data")
                .font(TypographyTokens.headline)
            Text("Execute a query that returns geometry or geography columns to visualise spatial results.")
                .font(TypographyTokens.subheadline)
                .foregroundStyle(ColorTokens.Text.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(SpacingTokens.xl2)
    }

    private func extractGeometries() {
        let columns = query.displayedColumns
        let rowCount = query.displayedRowCount
        guard rowCount > 0 else {
            geometries = []
            return
        }

        geometries = SpatialExtractor.extract(
            columns: columns,
            rowCount: rowCount,
            rowAccessor: { row, col in
                query.valueForDisplay(row: row, column: col)
            }
        )
    }
}
