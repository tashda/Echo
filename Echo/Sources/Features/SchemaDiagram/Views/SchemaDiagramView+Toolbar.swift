import SwiftUI

extension SchemaDiagramView {

    /// The diagram's filter and Export on the tool's header line (round 37.2, 37.3); the view
    /// controls float on the drawing (37.4, CA0).
    @ViewBuilder
    var headerControls: some View {
        ToolTabSearchField(prompt: "Filter tables", text: $diagramSearchText)
        ToolTabActionGroup {
            ToolTabActionMenu(title: "Export Diagram", systemImage: "square.and.arrow.up") {
                Button("Export as PNG") { exportDiagram(as: .png) }
                Button("Export as PDF") { exportDiagram(as: .pdf) }
                Divider()
                Button("Export Diagram Model as JSON") { exportDiagram(as: .jsonModel) }
                Button("Export Forward Engineering SQL") { exportDiagram(as: .sql) }
                Divider()
                Button("Export Documentation as HTML") { exportDiagram(as: .htmlDocumentation) }
                Button("Export Documentation as Markdown") { exportDiagram(as: .markdownDocumentation) }
                Button("Export Documentation as Text") { exportDiagram(as: .textDocumentation) }
                Divider()
                Button("Print") { printDiagram() }
            }
        }
    }

    /// Where the diagram came from, after the server in the header: "Live · 2 min ago".
    var loadSourceDetail: String {
        loadSourceDescriptor(for: viewModel.loadSource).text
    }

    func loadSourceDescriptor(for source: DiagramLoadSource) -> (text: String, icon: String, foreground: Color, background: Color) {
        switch source {
        case .live(let date):
            return (
                "Live \u{00b7} " + relativeTimeString(since: date),
                "bolt.fill",
                ColorTokens.Status.success.opacity(0.9),
                ColorTokens.Status.success.opacity(0.15)
            )
        case .cache(let date):
            return (
                "Cached \u{00b7} " + relativeTimeString(since: date),
                "clock.fill",
                ColorTokens.Text.secondary,
                ColorTokens.Text.primary.opacity(0.08)
            )
        }
    }

    func relativeTimeString(since date: Date) -> String {
        EchoFormatters.relativeDate(date)
    }
}
