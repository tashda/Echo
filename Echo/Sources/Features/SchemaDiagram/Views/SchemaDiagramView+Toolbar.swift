import SwiftUI

extension SchemaDiagramView {

    /// The diagram's filter on the tool's header line (round 37.2); the view controls float on
    /// the drawing (37.4, CA0).
    var headerControls: some View {
        ToolTabSearchField(prompt: "Filter tables", text: $diagramSearchText)
    }

    /// Export ▾ in the window toolbar (round 37.5).
    var toolbarGroups: [[TabToolbarItem]] {
        func export(_ id: String, _ title: String, _ format: DiagramExportFormat) -> TabToolbarItem {
            TabToolbarItem(id: id, title: title, symbol: "square.and.arrow.up") { exportDiagram(as: format) }
        }
        let divider = TabToolbarItem(id: "—", title: "—", symbol: "")
        return [[TabToolbarItem(id: "export", title: "Export Diagram", symbol: "square.and.arrow.up", menu: [
            export("png", "Export as PNG", .png), export("pdf", "Export as PDF", .pdf), divider,
            export("json", "Export Diagram Model as JSON", .jsonModel), export("sql", "Export Forward Engineering SQL", .sql),
            TabToolbarItem(id: "—2", title: "—", symbol: ""),
            export("html", "Export Documentation as HTML", .htmlDocumentation), export("md", "Export Documentation as Markdown", .markdownDocumentation),
            export("txt", "Export Documentation as Text", .textDocumentation),
            TabToolbarItem(id: "—3", title: "—", symbol: ""),
            TabToolbarItem(id: "print", title: "Print", symbol: "printer") { printDiagram() },
        ])]]
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
