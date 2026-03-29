import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit

extension SchemaDiagramView {

    func exportDiagram(as format: DiagramExportFormat) {
        guard !viewModel.nodes.isEmpty else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = format.contentTypes
        panel.nameFieldStringValue = "\(viewModel.title).\(format.fileExtension)"
        panel.canCreateDirectories = true

        panel.beginSheetModal(for: NSApp.keyWindow ?? NSApp.mainWindow!) { response in
            guard response == .OK, let url = panel.url else { return }
            renderAndSave(to: url, format: format)
        }
    }

    func printDiagram() {
        guard !viewModel.nodes.isEmpty else { return }
        guard let pdfData = renderDiagramToPDF() else { return }
        guard let pdfDocument = PDFDocument(data: pdfData) else { return }
        guard let pdfPage = pdfDocument.page(at: 0) else { return }

        let printInfo = NSPrintInfo.shared.copy() as! NSPrintInfo
        printInfo.isHorizontallyCentered = true
        printInfo.isVerticallyCentered = true

        let printView = PDFPrintView(page: pdfPage, printInfo: printInfo)
        let printOperation = NSPrintOperation(view: printView, printInfo: printInfo)
        printOperation.showsPrintPanel = true
        printOperation.showsProgressPanel = true
        printOperation.run()
    }

    private func renderAndSave(to url: URL, format: DiagramExportFormat) {
        switch format {
        case .png:
            guard let image = renderDiagramToImage() else { return }
            guard let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let pngData = bitmap.representation(using: .png, properties: [:])
            else { return }
            try? pngData.write(to: url)

        case .pdf:
            guard let pdfData = renderDiagramToPDF() else { return }
            try? pdfData.write(to: url)
        case .jsonModel:
            let content = SchemaDiagramModelExporter.export(
                title: viewModel.title,
                nodes: viewModel.nodes,
                edges: viewModel.edges,
                layout: viewModel.layoutSnapshot()
            )
            try? content.write(to: url, atomically: true, encoding: .utf8)
        case .htmlDocumentation, .markdownDocumentation, .textDocumentation, .sql:
            let content = SchemaDiagramDocumentationExporter.export(title: viewModel.title, nodes: viewModel.nodes, edges: viewModel.edges, format: format)
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func renderDiagramToImage() -> NSImage? {
        let bounds = diagramBounds()
        guard bounds.width > 0, bounds.height > 0 else { return nil }

        let padding: CGFloat = 40
        let imageWidth = bounds.width + padding * 2
        let imageHeight = bounds.height + padding * 2

        let image = NSImage(size: NSSize(width: imageWidth, height: imageHeight))
        image.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return nil
        }

        // White background
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))

        // Translate so nodes start at padding offset
        context.translateBy(x: padding - bounds.minX, y: padding - bounds.minY)

        drawNodes(in: context)
        drawEdgesOffscreen(in: context)

        image.unlockFocus()
        return image
    }

    private func renderDiagramToPDF() -> Data? {
        let bounds = diagramBounds()
        guard bounds.width > 0, bounds.height > 0 else { return nil }

        let padding: CGFloat = 40
        let pageWidth = bounds.width + padding * 2
        let pageHeight = bounds.height + padding * 2
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let pdfContext = CGContext(consumer: consumer, mediaBox: nil, nil)
        else { return nil }

        let mediaBox = pageRect
        pdfContext.beginPDFPage([kCGPDFContextMediaBox as String: NSValue(rect: mediaBox)] as CFDictionary)

        // White background
        pdfContext.setFillColor(NSColor.white.cgColor)
        pdfContext.fill(pageRect)

        // Translate so nodes start at padding offset
        pdfContext.translateBy(x: padding - bounds.minX, y: padding - bounds.minY)

        drawNodes(in: pdfContext)
        drawEdgesOffscreen(in: pdfContext)

        pdfContext.endPDFPage()
        pdfContext.closePDF()

        return data as Data
    }

    private func diagramBounds() -> CGRect {
        let nodeWidth: CGFloat = 220
        let baseHeight: CGFloat = 60

        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude

        for node in viewModel.nodes {
            let halfW = nodeWidth / 2
            let halfH = (baseHeight + CGFloat(node.columns.count) * 20) / 2
            minX = min(minX, node.position.x - halfW)
            minY = min(minY, node.position.y - halfH)
            maxX = max(maxX, node.position.x + halfW)
            maxY = max(maxY, node.position.y + halfH)
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func drawNodes(in context: CGContext) {
        let nodeWidth: CGFloat = 220

        for node in viewModel.nodes {
            let rowHeight: CGFloat = 20
            let headerHeight: CGFloat = 44
            let totalHeight = headerHeight + CGFloat(node.columns.count) * rowHeight + 16
            let origin = CGPoint(
                x: node.position.x - nodeWidth / 2,
                y: node.position.y - totalHeight / 2
            )

            // Node background
            let nodeRect = CGRect(origin: origin, size: CGSize(width: nodeWidth, height: totalHeight))
            let nodePath = CGPath(roundedRect: nodeRect, cornerWidth: 12, cornerHeight: 12, transform: nil)
            context.setFillColor(NSColor.windowBackgroundColor.cgColor)
            context.addPath(nodePath)
            context.fillPath()
            context.setStrokeColor(NSColor.separatorColor.cgColor)
            context.setLineWidth(1)
            context.addPath(nodePath)
            context.strokePath()

            // Header
            let headerRect = CGRect(x: origin.x, y: origin.y, width: nodeWidth, height: headerHeight)
            context.setFillColor(NSColor.controlBackgroundColor.cgColor)
            let headerPath = CGPath(roundedRect: headerRect, cornerWidth: 12, cornerHeight: 12, transform: nil)
            context.addPath(headerPath)
            context.fillPath()

            // Table name
            let nameStr = node.name as NSString
            let nameAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: NSColor.labelColor
            ]
            nameStr.draw(at: CGPoint(x: origin.x + 12, y: origin.y + 6), withAttributes: nameAttrs)

            // Schema name
            let schemaStr = node.schema as NSString
            let schemaAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10, weight: .medium),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            schemaStr.draw(at: CGPoint(x: origin.x + 12, y: origin.y + 24), withAttributes: schemaAttrs)

            // Columns
            for (index, column) in node.columns.enumerated() {
                let colY = origin.y + headerHeight + CGFloat(index) * rowHeight + 8
                let colAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 10, weight: column.isPrimaryKey ? .semibold : .regular),
                    .foregroundColor: NSColor.labelColor
                ]
                (column.name as NSString).draw(at: CGPoint(x: origin.x + 28, y: colY), withAttributes: colAttrs)

                let typeAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 9),
                    .foregroundColor: NSColor.tertiaryLabelColor
                ]
                let typeStr = column.dataType as NSString
                let typeWidth = typeStr.size(withAttributes: typeAttrs).width
                typeStr.draw(at: CGPoint(x: origin.x + nodeWidth - typeWidth - 12, y: colY), withAttributes: typeAttrs)
            }
        }
    }

    private func drawEdgesOffscreen(in context: CGContext) {
        for edge in viewModel.edges {
            guard let fromNode = viewModel.node(for: edge.fromNodeID),
                  let toNode = viewModel.node(for: edge.toNodeID)
            else { continue }

            let start = fromNode.position
            let end = toNode.position

            // Line
            context.setStrokeColor(NSColor.systemBlue.withAlphaComponent(0.6).cgColor)
            context.setLineWidth(2)
            context.move(to: start)
            context.addLine(to: end)
            context.strokePath()

            // Arrow at end
            let angle = atan2(end.y - start.y, end.x - start.x)
            let arrowLength: CGFloat = 10
            let arrowAngle: CGFloat = .pi / 7
            let p1 = CGPoint(x: end.x - arrowLength * cos(angle - arrowAngle), y: end.y - arrowLength * sin(angle - arrowAngle))
            let p2 = CGPoint(x: end.x - arrowLength * cos(angle + arrowAngle), y: end.y - arrowLength * sin(angle + arrowAngle))
            context.setFillColor(NSColor.systemBlue.withAlphaComponent(0.6).cgColor)
            context.move(to: end)
            context.addLine(to: p1)
            context.addLine(to: p2)
            context.closePath()
            context.fillPath()
        }
    }
}

import PDFKit

private final class PDFPrintView: NSView {
    private let page: PDFPage
    private let printPageInfo: NSPrintInfo

    init(page: PDFPage, printInfo: NSPrintInfo) {
        self.page = page
        self.printPageInfo = printInfo
        let pageBounds = page.bounds(for: .mediaBox)
        super.init(frame: pageBounds)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        page.draw(with: .mediaBox, to: context)
    }

    override var isFlipped: Bool { false }

    override func knowsPageRange(_ range: NSRangePointer) -> Bool {
        range.pointee = NSRange(location: 1, length: 1)
        return true
    }

    override func rectForPage(_ page: Int) -> NSRect {
        bounds
    }
}

enum DiagramExportFormat {
    case png
    case pdf
    case jsonModel
    case sql
    case htmlDocumentation
    case markdownDocumentation
    case textDocumentation

    var fileExtension: String {
        switch self {
        case .png: "png"
        case .pdf: "pdf"
        case .jsonModel: "json"
        case .sql: "sql"
        case .htmlDocumentation: "html"
        case .markdownDocumentation: "md"
        case .textDocumentation: "txt"
        }
    }

    var contentTypes: [UTType] {
        switch self {
        case .png: [.png]
        case .pdf: [.pdf]
        case .jsonModel: [.json]
        case .sql: [.plainText]
        case .htmlDocumentation: [.html]
        case .markdownDocumentation: [.plainText]
        case .textDocumentation: [.plainText]
        }
    }
}
#endif
